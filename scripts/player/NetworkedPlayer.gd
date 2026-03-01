extends CharacterBody2D

## Networked player controller. Wraps PlayerController.calculate_velocity()
## for multiplayer play with server-authoritative movement.
##
## Roles:
##   Server + authority (host's player): sample input locally, simulate, broadcast
##   Server + not authority (client's player): receive input via RPC, simulate, broadcast
##   Client + authority (own player): predict locally, send input, reconcile on server state
##   Client + not authority (remote puppet): interpolate from server snapshots

var fuel: float = MovementTuning.JETPACK_MAX_FUEL
var aim_angle: float = 0.0
var _facing_right: bool = true

# Network state
var _input_seq: int = 0
var _last_input: Dictionary = {
	"move_dir": 0.0,
	"jump": false,
	"jetpack": false,
	"dive": false,
	"aim_angle": 0.0,
}
var _server_tick: int = 0
var _last_processed_seq: int = 0
var _tick_accumulator: float = 0.0

# Client-side prediction (local player on client only)
var _prediction: ClientPrediction = null

# Remote interpolation (remote players on client only)
var _interpolation: RemoteInterpolation = null
var _remote_time: float = 0.0


func _ready() -> void:
	if is_multiplayer_authority():
		var camera := Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
		camera.make_current()

	# Initialize prediction for local player on client
	if not multiplayer.is_server() and is_multiplayer_authority():
		_prediction = ClientPrediction.new()

	# Initialize interpolation for remote players on client
	if not multiplayer.is_server() and not is_multiplayer_authority():
		_interpolation = RemoteInterpolation.new()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_process(delta)
	elif is_multiplayer_authority():
		_client_local_process(delta)
	else:
		_client_remote_process(delta)


func _server_process(delta: float) -> void:
	# Host's own player: sample input directly
	if is_multiplayer_authority():
		_last_input = _sample_input()

	# Fixed tick simulation
	var tick_delta := 1.0 / NetConstants.TICK_RATE
	_tick_accumulator += delta
	while _tick_accumulator >= tick_delta:
		_tick_accumulator -= tick_delta
		_simulate_tick(tick_delta)
		_server_tick += 1
		_broadcast_state()

	# Push debug data for host's own player
	if is_multiplayer_authority():
		Debug.set_overlay_data({
			"velocity": velocity,
			"grounded": is_on_floor(),
			"fuel": fuel,
		})


func _simulate_tick(tick_delta: float) -> void:
	var state := {
		"velocity": velocity,
		"grounded": is_on_floor(),
		"fuel": fuel,
	}
	var result := PlayerController.calculate_velocity(state, _last_input, tick_delta)
	velocity = result.velocity
	fuel = result.fuel
	move_and_slide()
	_update_facing(_last_input.get("aim_angle", 0.0))


func _client_local_process(delta: float) -> void:
	# Fixed tick prediction matching server tick rate
	var tick_delta := 1.0 / NetConstants.TICK_RATE
	_tick_accumulator += delta
	while _tick_accumulator >= tick_delta:
		_tick_accumulator -= tick_delta

		var input := _sample_input()
		_input_seq += 1

		# Predict locally using shared movement function
		var state := {
			"velocity": velocity,
			"grounded": is_on_floor(),
			"fuel": fuel,
		}
		var result := PlayerController.calculate_velocity(state, input, tick_delta)
		velocity = result.velocity
		fuel = result.fuel
		move_and_slide()
		_update_facing(input.aim_angle)

		# Record prediction
		var predicted_state := {
			"position": position,
			"velocity": velocity,
			"fuel": fuel,
			"grounded": is_on_floor(),
		}
		_prediction.record_input(_input_seq, input, predicted_state)

		# Send input to server
		var payload := input.duplicate()
		payload["seq"] = _input_seq
		_send_input.rpc_id(1, payload)

	# Debug overlay
	Debug.set_overlay_data({
		"velocity": velocity,
		"grounded": is_on_floor(),
		"fuel": fuel,
	})


func _client_remote_process(delta: float) -> void:
	if _interpolation == null:
		return

	_remote_time += delta
	var interp_state := _interpolation.get_interpolated_state(_remote_time)
	if interp_state.is_empty():
		return

	position = interp_state.position
	velocity = interp_state.velocity
	fuel = interp_state.fuel
	aim_angle = interp_state.aim_angle
	_update_facing(aim_angle)


func _sample_input() -> Dictionary:
	var input := PlayerController.sample_input_at(global_position, get_global_mouse_position())
	aim_angle = input.aim_angle
	return input


## Client → Server: send input for this player.
@rpc("any_peer", "reliable")
func _send_input(input_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	# Validate sender matches this player's authority
	var sender := multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority():
		Debug.log("net", "Rejected input from peer %d for player %d" % [sender, get_multiplayer_authority()])
		return

	if not _validate_input(input_data):
		Debug.log("net", "Invalid input from peer %d" % sender)
		return

	_last_processed_seq = input_data.get("seq", 0)
	_last_input = input_data


func _validate_input(input: Dictionary) -> bool:
	if not input.has_all(["move_dir", "jump", "jetpack", "dive", "aim_angle"]):
		return false
	var move_dir: float = input.get("move_dir", 0.0)
	if move_dir < -1.0 or move_dir > 1.0:
		return false
	return true


func _broadcast_state() -> void:
	var snapshot := {
		"position_x": position.x,
		"position_y": position.y,
		"velocity_x": velocity.x,
		"velocity_y": velocity.y,
		"fuel": fuel,
		"grounded": is_on_floor(),
		"aim_angle": _last_input.get("aim_angle", 0.0),
		"tick": _server_tick,
		"last_input_seq": _last_processed_seq,
	}
	_receive_state.rpc(snapshot)


## Server → Clients: broadcast authoritative state.
@rpc("any_peer", "unreliable")
func _receive_state(state: Dictionary) -> void:
	if multiplayer.is_server():
		return

	# Only accept state from server (peer 1)
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1:
		return

	if is_multiplayer_authority():
		_handle_server_reconciliation(state)
	else:
		_handle_remote_snapshot(state)


func _handle_server_reconciliation(state: Dictionary) -> void:
	if _prediction == null:
		return

	var server_pos := Vector2(
		state.get("position_x", position.x),
		state.get("position_y", position.y)
	)
	var last_seq: int = state.get("last_input_seq", 0)

	var result := _prediction.on_server_state(server_pos, last_seq)

	if result.needs_reconciliation:
		# Snap to server state
		position = server_pos
		velocity = Vector2(
			state.get("velocity_x", velocity.x),
			state.get("velocity_y", velocity.y)
		)
		fuel = state.get("fuel", fuel)

		# Replay pending inputs and collect corrected states
		var tick_delta := 1.0 / NetConstants.TICK_RATE
		var corrected_states: Array = []
		for pending in result.pending_inputs:
			var sim_state := {
				"velocity": velocity,
				"grounded": is_on_floor(),
				"fuel": fuel,
			}
			var sim_result := PlayerController.calculate_velocity(
				sim_state, pending.input, tick_delta
			)
			velocity = sim_result.velocity
			fuel = sim_result.fuel
			move_and_slide()
			corrected_states.append({
				"position": position,
				"velocity": velocity,
				"fuel": fuel,
				"grounded": is_on_floor(),
			})

		_prediction.update_predicted_states(corrected_states)

	# Debug overlay
	Debug.set_overlay_data({
		"velocity": velocity,
		"grounded": is_on_floor(),
		"fuel": fuel,
	})


func _handle_remote_snapshot(state: Dictionary) -> void:
	if _interpolation == null:
		return

	var interp_state := {
		"position": Vector2(state.get("position_x", 0.0), state.get("position_y", 0.0)),
		"velocity": Vector2(state.get("velocity_x", 0.0), state.get("velocity_y", 0.0)),
		"fuel": state.get("fuel", 0.0),
		"aim_angle": state.get("aim_angle", 0.0),
		"grounded": state.get("grounded", false),
	}
	_interpolation.add_snapshot(interp_state, _remote_time)


func _update_facing(angle: float) -> void:
	var should_face_right := cos(angle) < 0.0
	if should_face_right != _facing_right:
		_facing_right = should_face_right
		$Sprite2D.flip_h = not _facing_right
