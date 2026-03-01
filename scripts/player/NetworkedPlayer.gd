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
var _last_broadcast_snapshot: Dictionary = {}
var _ticks_since_last_broadcast: int = 0
const HEARTBEAT_INTERVAL: int = 15  # Force broadcast every 0.5s even if unchanged

# Buffer edge-triggered inputs so they survive between tick boundaries
var _jump_buffered: bool = false
var _dive_buffered: bool = false

# Client-side prediction (local player on client only)
var _prediction: ClientPrediction = null

# Remote interpolation (remote players on client only)
var _interpolation: RemoteInterpolation = null
var _remote_time: float = 0.0

# Health (server-authoritative, replicated to clients)
var health: Health = null
var _display_hp: int = 100
var _is_dead: bool = false
var _killer_peer_id: int = 0

# Weapon (server has authoritative instance, client has prediction instance)
var _weapon: WeaponRifle = null
var _bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

# HUD (local player only)
var _hud: CanvasLayer = null
var _hud_scene: PackedScene = preload("res://scenes/HUD.tscn")

# Bot support (for soak testing)
var is_bot: bool = false
var _bot_input: Dictionary = {}
var _bot_wants_fire: bool = false

# Anti-cheat: max distance from server position for fire origin validation
const FIRE_ORIGIN_TOLERANCE := 60.0


func _ready() -> void:
	_create_placeholder_sprite()

	health = Health.new()
	_weapon = WeaponRifle.new()

	if multiplayer.is_server():
		health.died.connect(_on_player_died)
		health.health_changed.connect(_on_health_changed)

	if is_multiplayer_authority():
		var camera := Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
		camera.make_current()
		# Create HUD for local player
		_hud = _hud_scene.instantiate()
		add_child(_hud)

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


func set_bot_input(input: Dictionary) -> void:
	_bot_input = input


func _server_process(delta: float) -> void:
	# Scoreboard toggle (host player, works even when dead)
	if is_multiplayer_authority() and not is_bot:
		if Input.is_action_just_pressed("scoreboard") and _hud != null:
			var game_mode := get_node_or_null("../../GameModeDeathmatch")
			if game_mode:
				_hud.toggle_scoreboard(game_mode.scores)
		if Input.is_action_just_released("scoreboard") and _hud != null:
			_hud.hide_scoreboard()

	# Dead players: only broadcast state, skip sim and input
	if _is_dead:
		var tick_delta := 1.0 / NetConstants.TICK_RATE
		_tick_accumulator += delta
		while _tick_accumulator >= tick_delta:
			_tick_accumulator -= tick_delta
			_server_tick += 1
			_broadcast_state()
		return

	_weapon.process_cooldown(delta)

	# Bot input
	if is_bot:
		_last_input = _bot_input
		aim_angle = _bot_input.get("aim_angle", 0.0)
	# Host's own player: buffer edge-triggered inputs + sample
	elif is_multiplayer_authority():
		if Input.is_action_just_pressed("jump"):
			_jump_buffered = true
		if Input.is_action_just_pressed("dive"):
			_dive_buffered = true
		_last_input = _sample_input()
		if _jump_buffered:
			_last_input.jump = true
		if _dive_buffered:
			_last_input.dive = true

	# Fixed tick simulation
	var tick_delta := 1.0 / NetConstants.TICK_RATE
	_tick_accumulator += delta
	while _tick_accumulator >= tick_delta:
		_tick_accumulator -= tick_delta
		_simulate_tick(tick_delta)
		_server_tick += 1
		_broadcast_state()
		# Clear buffers after the first tick consumes them
		if is_multiplayer_authority() and not is_bot:
			_jump_buffered = false
			_dive_buffered = false

	# Fire handling (host player or bot)
	var should_fire := false
	if is_bot:
		should_fire = _bot_wants_fire
		_bot_wants_fire = false
	elif is_multiplayer_authority():
		should_fire = Input.is_action_pressed("fire")
	if should_fire and health.is_alive() and _weapon.can_fire():
		_weapon.fire()
		var origin := global_position + WeaponRifle.get_muzzle_offset(aim_angle)
		_spawn_bullet(origin, WeaponRifle.get_aim_direction(aim_angle))

	# Push debug data and HUD for host's own player (not bots)
	if is_multiplayer_authority() and not is_bot:
		Debug.set_overlay_data({
			"velocity": velocity,
			"grounded": is_on_floor(),
			"fuel": fuel,
			"hp": health.current_hp,
		})
		if _hud != null:
			_hud.update_ammo(_weapon.current_ammo, _weapon.config.max_ammo, _weapon.reloading)


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
	# Scoreboard toggle (works even when dead)
	if Input.is_action_just_pressed("scoreboard") and _hud != null:
		var game_mode := get_node_or_null("../../GameModeDeathmatch")
		if game_mode:
			_hud.toggle_scoreboard(game_mode.scores)
	if Input.is_action_just_released("scoreboard") and _hud != null:
		_hud.hide_scoreboard()

	# Dead: skip input/movement, just show death screen
	if _is_dead:
		return

	_weapon.process_cooldown(delta)

	# Buffer edge-triggered inputs before the tick loop
	if Input.is_action_just_pressed("jump"):
		_jump_buffered = true
	if Input.is_action_just_pressed("dive"):
		_dive_buffered = true

	# Fixed tick prediction matching server tick rate
	var tick_delta := 1.0 / NetConstants.TICK_RATE
	_tick_accumulator += delta
	while _tick_accumulator >= tick_delta:
		_tick_accumulator -= tick_delta

		var input := _sample_input()
		if _jump_buffered:
			input.jump = true
		if _dive_buffered:
			input.dive = true
		_jump_buffered = false
		_dive_buffered = false
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
		Debug.record_rpc_sent()

	# Client fire handling (predicted — server validates)
	if _display_hp > 0:
		if Input.is_action_pressed("fire") and _weapon.can_fire():
			_weapon.fire()
			var origin := global_position + WeaponRifle.get_muzzle_offset(aim_angle)
			var direction := WeaponRifle.get_aim_direction(aim_angle)
			_fire_request.rpc_id(1, {
				"seq": _input_seq,
				"origin_x": origin.x,
				"origin_y": origin.y,
				"dir_x": direction.x,
				"dir_y": direction.y,
			})
			# Spawn cosmetic bullet locally for instant visual feedback
			_spawn_cosmetic_bullet(origin, direction)

	# Debug overlay + HUD ammo
	Debug.set_overlay_data({
		"velocity": velocity,
		"grounded": is_on_floor(),
		"fuel": fuel,
		"hp": _display_hp,
	})
	if _hud != null:
		_hud.update_ammo(_weapon.current_ammo, _weapon.config.max_ammo, _weapon.reloading)


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


# --- Fire Request RPC ---

## Client → Server: request to fire weapon.
@rpc("any_peer", "reliable")
func _fire_request(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority():
		Debug.log("net", "Rejected fire from peer %d for player %d" % [sender, get_multiplayer_authority()])
		return

	if not health.is_alive():
		return

	# Server-side cooldown check
	if not _weapon.can_fire():
		Debug.log("net", "Fire rejected: cooldown not elapsed for peer %d" % sender)
		return

	# Validate fire origin is near server-known position
	var origin := Vector2(data.get("origin_x", 0.0), data.get("origin_y", 0.0))
	if origin.distance_to(global_position) > FIRE_ORIGIN_TOLERANCE:
		Debug.log("net", "Fire rejected: origin too far from server pos for peer %d" % sender)
		return

	_weapon.fire()
	var direction := Vector2(data.get("dir_x", 0.0), data.get("dir_y", 0.0))
	if direction.length_squared() < 0.01:
		Debug.log("net", "Fire rejected: invalid direction for peer %d" % sender)
		return
	_spawn_bullet(origin, direction)


# --- Bullet Spawning (server only) ---

func _spawn_bullet(origin: Vector2, direction: Vector2) -> void:
	var bullets_node := get_node_or_null("../../Bullets")
	if bullets_node == null:
		return

	var peer_id := int(str(name))

	# Enforce total bullet cap
	while bullets_node.get_child_count() >= NetConstants.MAX_BULLETS_TOTAL:
		var oldest := bullets_node.get_child(0)
		if oldest:
			oldest.queue_free()
			bullets_node.remove_child(oldest)
		else:
			break

	# Enforce per-player bullet cap
	while _get_player_bullet_count(bullets_node, peer_id) >= NetConstants.MAX_BULLETS_PER_PLAYER:
		if not _remove_oldest_player_bullet(bullets_node, peer_id):
			break

	var bullet := _bullet_scene.instantiate()
	bullet.position = origin
	bullet.spawn_position = origin
	bullet.speed_vec = direction.normalized() * _weapon.config.bullet_speed
	bullet.owner_peer_id = peer_id
	bullet.damage = _weapon.config.damage
	bullet.gravity = _weapon.config.bullet_gravity
	bullet.hit_player.connect(_on_bullet_hit_player)
	bullet.hit_world.connect(_on_bullet_hit_world)
	bullets_node.add_child(bullet)
	# Avoid bullet colliding with the shooter
	bullet.add_collision_exception_with(self)

	# Broadcast fire event to all clients (for cosmetic effects)
	_on_fire_event.rpc({
		"origin_x": origin.x,
		"origin_y": origin.y,
		"dir_x": direction.x,
		"dir_y": direction.y,
	})


func _get_player_bullet_count(bullets_node: Node, peer_id: int) -> int:
	var count := 0
	for bullet in bullets_node.get_children():
		if bullet is CharacterBody2D and bullet.owner_peer_id == peer_id:
			count += 1
	return count


func _remove_oldest_player_bullet(bullets_node: Node, peer_id: int) -> bool:
	for bullet in bullets_node.get_children():
		if bullet is CharacterBody2D and bullet.owner_peer_id == peer_id:
			bullet.queue_free()
			bullets_node.remove_child(bullet)
			return true
	return false


## Spawn a visual-only bullet on the client. No hit signals connected.
func _spawn_cosmetic_bullet(origin: Vector2, direction: Vector2) -> void:
	var bullets_node := get_node_or_null("../../Bullets")
	if bullets_node == null:
		return
	var bullet := _bullet_scene.instantiate()
	bullet.position = origin
	bullet.speed_vec = direction.normalized() * _weapon.config.bullet_speed
	bullet.owner_peer_id = int(str(name))
	bullet.gravity = _weapon.config.bullet_gravity
	bullets_node.add_child(bullet)
	bullet.add_collision_exception_with(self)


func _on_bullet_hit_player(victim_node: CharacterBody2D, hit_position: Vector2) -> void:
	if not multiplayer.is_server():
		return
	# Apply damage to victim
	if victim_node.has_method("apply_damage"):
		var shooter_id := int(str(name))
		victim_node.apply_damage(_weapon.config.damage, shooter_id)
		# Broadcast hit event
		_on_hit_event.rpc({
			"victim_id": int(str(victim_node.name)),
			"shooter_id": shooter_id,
			"position_x": hit_position.x,
			"position_y": hit_position.y,
			"damage": _weapon.config.damage,
		})


func _on_bullet_hit_world(hit_position: Vector2) -> void:
	# Could broadcast impact effect to clients
	pass


## Apply damage to this player (server-only).
func apply_damage(amount: int, source_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if amount <= 0:
		return
	health.take_damage(amount, source_peer_id)


# --- Health Callbacks (server) ---

func _on_health_changed(new_hp: int, max_hp: int) -> void:
	_receive_health_update.rpc(new_hp)
	# Update host's own HUD
	if is_multiplayer_authority() and _hud != null:
		_hud.update_hp(new_hp, max_hp)


func _on_player_died(killer_peer_id: int) -> void:
	Debug.log("net", "Player %s killed by peer %d" % [name, killer_peer_id])
	var game_mode := get_node_or_null("../../GameModeDeathmatch")
	if game_mode:
		game_mode.on_player_killed(killer_peer_id, int(str(name)))


## Server-side: mark player as dead or alive. Called by GameModeDeathmatch.
func set_dead(dead: bool, killer_id: int = 0) -> void:
	_is_dead = dead
	_killer_peer_id = killer_id
	if dead:
		$CollisionShape2D.set_deferred("disabled", true)
		$Sprite2D.visible = false
		velocity = Vector2.ZERO
		# Notify all clients of death
		_receive_death.rpc(killer_id)
		# Update host HUD if this is the host's player
		if is_multiplayer_authority() and _hud != null:
			_hud.show_death_screen(killer_id, GameModeDeathmatch.RESPAWN_DELAY)
	else:
		$CollisionShape2D.set_deferred("disabled", false)
		$Sprite2D.visible = true


func is_player_dead() -> bool:
	return _is_dead


## Server-side: respawn player at position. Called by GameModeDeathmatch.
func respawn(spawn_pos: Vector2) -> void:
	_is_dead = false
	_killer_peer_id = 0
	position = spawn_pos
	velocity = Vector2.ZERO
	fuel = MovementTuning.JETPACK_MAX_FUEL
	health.reset()
	_weapon.reset()
	$CollisionShape2D.set_deferred("disabled", false)
	$Sprite2D.visible = true
	# Host HUD update
	if is_multiplayer_authority() and _hud != null:
		_hud.hide_death_screen()
		_hud.update_ammo(_weapon.current_ammo, _weapon.config.max_ammo, _weapon.reloading)


## Client-side: handle respawn from server broadcast.
func on_client_respawn(spawn_pos: Vector2) -> void:
	_is_dead = false
	_killer_peer_id = 0
	_display_hp = 100
	position = spawn_pos
	velocity = Vector2.ZERO
	$Sprite2D.visible = true
	if is_multiplayer_authority():
		fuel = MovementTuning.JETPACK_MAX_FUEL
		_weapon.reset()
		if _hud != null:
			_hud.hide_death_screen()
			_hud.update_hp(100, 100)
			_hud.update_ammo(_weapon.current_ammo, _weapon.config.max_ammo, _weapon.reloading)


# --- Client RPCs ---

## Server → Clients: fire event for cosmetic effects.
@rpc("any_peer", "unreliable")
func _on_fire_event(data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	# Local player already spawned their own cosmetic bullet instantly
	if is_multiplayer_authority():
		return
	var origin := Vector2(data.get("origin_x", 0.0), data.get("origin_y", 0.0))
	var direction := Vector2(data.get("dir_x", 0.0), data.get("dir_y", 0.0))
	_spawn_cosmetic_bullet(origin, direction)


## Server → Clients: hit event for cosmetic effects.
@rpc("any_peer", "reliable")
func _on_hit_event(_data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	# Cosmetic: could spawn blood puff here
	pass


## Server → Clients: player death notification.
@rpc("any_peer", "reliable")
func _receive_death(killer_id: int) -> void:
	if multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1:
		return
	_is_dead = true
	_killer_peer_id = killer_id
	_display_hp = 0
	$Sprite2D.visible = false
	if is_multiplayer_authority() and _hud != null:
		_hud.show_death_screen(killer_id, GameModeDeathmatch.RESPAWN_DELAY)


## Server → Clients: health update.
@rpc("any_peer", "reliable")
func _receive_health_update(new_hp: int) -> void:
	if multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1:
		return
	_display_hp = new_hp
	if _hud != null:
		_hud.update_hp(new_hp, 100)


# --- Input & State RPCs (unchanged from Phase 3) ---

## Client → Server: send input for this player.
@rpc("any_peer", "reliable")
func _send_input(input_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	Debug.record_rpc_received()

	# Validate sender matches this player's authority
	var sender := multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority():
		Debug.log("net", "Rejected input from peer %d for player %d" % [sender, get_multiplayer_authority()])
		return

	if _is_dead:
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
		"hp": health.current_hp,
		"is_dead": _is_dead,
	}

	_ticks_since_last_broadcast += 1
	if _snapshot_unchanged(snapshot) and _ticks_since_last_broadcast < HEARTBEAT_INTERVAL:
		return

	_ticks_since_last_broadcast = 0
	_last_broadcast_snapshot = snapshot
	_receive_state.rpc(snapshot)
	Debug.record_rpc_sent()


func _snapshot_unchanged(snapshot: Dictionary) -> bool:
	if _last_broadcast_snapshot.is_empty():
		return false
	# Always send on state transitions
	if snapshot.get("is_dead") != _last_broadcast_snapshot.get("is_dead"):
		return false
	if snapshot.get("hp") != _last_broadcast_snapshot.get("hp"):
		return false
	if snapshot.get("grounded") != _last_broadcast_snapshot.get("grounded"):
		return false
	# Position/velocity epsilon check
	const EPSILON := 0.1
	if absf(snapshot.get("position_x", 0.0) - _last_broadcast_snapshot.get("position_x", 0.0)) > EPSILON:
		return false
	if absf(snapshot.get("position_y", 0.0) - _last_broadcast_snapshot.get("position_y", 0.0)) > EPSILON:
		return false
	if absf(snapshot.get("velocity_x", 0.0) - _last_broadcast_snapshot.get("velocity_x", 0.0)) > EPSILON:
		return false
	if absf(snapshot.get("velocity_y", 0.0) - _last_broadcast_snapshot.get("velocity_y", 0.0)) > EPSILON:
		return false
	return true


## Server → Clients: broadcast authoritative state.
@rpc("any_peer", "unreliable")
func _receive_state(state: Dictionary) -> void:
	if multiplayer.is_server():
		return
	Debug.record_rpc_received()

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

	_display_hp = state.get("hp", _display_hp)

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
		"hp": _display_hp,
	})


func _handle_remote_snapshot(state: Dictionary) -> void:
	if _interpolation == null:
		return

	_display_hp = state.get("hp", _display_hp)
	var dead: bool = state.get("is_dead", false)
	if dead != _is_dead:
		_is_dead = dead
		$Sprite2D.visible = not dead

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


func _create_placeholder_sprite() -> void:
	var img := Image.create(24, 48, false, Image.FORMAT_RGBA8)
	# Head (skin tone)
	for y in range(0, 12):
		for x in range(6, 18):
			img.set_pixel(x, y, Color(0.9, 0.75, 0.6))
	# Body (blue)
	for y in range(12, 32):
		for x in range(4, 20):
			img.set_pixel(x, y, Color(0.2, 0.4, 0.8))
	# Legs (dark blue)
	for y in range(32, 48):
		for x in range(5, 11):
			img.set_pixel(x, y, Color(0.15, 0.25, 0.5))
		for x in range(13, 19):
			img.set_pixel(x, y, Color(0.15, 0.25, 0.5))
	$Sprite2D.texture = ImageTexture.create_from_image(img)
