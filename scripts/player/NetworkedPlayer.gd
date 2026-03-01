extends CharacterBody2D

## Networked player controller. Wraps PlayerController.calculate_velocity()
## for multiplayer play with server-authoritative movement.
##
## Roles:
##   Server + authority (host's player): sample input locally, simulate, broadcast
##   Server + not authority (client's player): receive input via RPC, simulate, broadcast
##   Client + authority (own player): sample input, send to server, apply received state
##   Client + not authority (remote puppet): apply received state

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
var _snapshot_accumulator: float = 0.0
var _input_send_accumulator: float = 0.0


func _ready() -> void:
	if is_multiplayer_authority():
		# Local player gets a camera
		var camera := Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
		camera.make_current()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_process(delta)
	elif is_multiplayer_authority():
		_client_local_process(delta)
	# Remote puppets: state applied via _receive_state RPC


func _server_process(delta: float) -> void:
	# Host's own player: sample input directly
	if is_multiplayer_authority():
		_last_input = _sample_input()

	# Simulate movement using the shared pure function
	var state := {
		"velocity": velocity,
		"grounded": is_on_floor(),
		"fuel": fuel,
	}
	var result := PlayerController.calculate_velocity(state, _last_input, delta)
	velocity = result.velocity
	fuel = result.fuel
	move_and_slide()

	_update_facing(_last_input.get("aim_angle", 0.0))

	_server_tick += 1

	# Push debug data for host's own player
	if is_multiplayer_authority():
		Debug.set_overlay_data({
			"velocity": velocity,
			"grounded": is_on_floor(),
			"fuel": fuel,
		})

	# Broadcast state at SNAPSHOT_RATE
	_snapshot_accumulator += delta
	var snapshot_interval := 1.0 / NetConstants.SNAPSHOT_RATE
	if _snapshot_accumulator >= snapshot_interval:
		_snapshot_accumulator -= snapshot_interval
		_broadcast_state()


func _client_local_process(delta: float) -> void:
	var input := _sample_input()

	# Send input to server at MAX_INPUT_RATE
	_input_send_accumulator += delta
	var input_interval := 1.0 / NetConstants.MAX_INPUT_RATE
	if _input_send_accumulator >= input_interval:
		_input_send_accumulator -= input_interval
		_input_seq += 1
		var payload := input.duplicate()
		payload["seq"] = _input_seq
		_send_input.rpc_id(1, payload)


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

	position = Vector2(state.get("position_x", position.x), state.get("position_y", position.y))
	velocity = Vector2(state.get("velocity_x", velocity.x), state.get("velocity_y", velocity.y))
	fuel = state.get("fuel", fuel)
	aim_angle = state.get("aim_angle", aim_angle)
	_update_facing(aim_angle)

	# Debug overlay for local player
	if is_multiplayer_authority():
		Debug.set_overlay_data({
			"velocity": velocity,
			"grounded": state.get("grounded", false),
			"fuel": fuel,
		})


func _update_facing(angle: float) -> void:
	var should_face_right := cos(angle) < 0.0
	if should_face_right != _facing_right:
		_facing_right = should_face_right
		$Sprite2D.flip_h = not _facing_right
