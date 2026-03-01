extends CharacterBody2D

## Server-authoritative projectile bullet.
## Moves each tick via move_and_collide() for reliable collision detection.
## Only exists on the server — clients receive hit events via RPC.

var speed_vec: Vector2 = Vector2.ZERO
var owner_peer_id: int = 0
var damage: int = 25
var gravity: float = 50.0
var max_lifetime: float = 3.0
var spawn_position: Vector2 = Vector2.ZERO

var _time_alive: float = 0.0
var _tick_accumulator: float = 0.0
var _dead := false

const TRACER_LENGTH := 12.0
const TRACER_COLOR := Color(1.0, 0.9, 0.3)  # Yellow-white

## Emitted when the bullet hits a player.
signal hit_player(victim_node: CharacterBody2D, hit_position: Vector2)
## Emitted when the bullet hits world geometry.
signal hit_world(hit_position: Vector2)


func _draw() -> void:
	if speed_vec.length_squared() < 1.0:
		return
	var dir := speed_vec.normalized()
	draw_line(Vector2.ZERO, -dir * TRACER_LENGTH, TRACER_COLOR, 2.0)
	draw_circle(Vector2.ZERO, 2.0, TRACER_COLOR)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var tick_delta := 1.0 / NetConstants.TICK_RATE
	_tick_accumulator += delta
	while _tick_accumulator >= tick_delta:
		_tick_accumulator -= tick_delta
		_simulate_tick(tick_delta)
		if _dead:
			return


func _simulate_tick(tick_delta: float) -> void:
	_time_alive += tick_delta
	if _time_alive >= max_lifetime:
		_dead = true
		queue_free()
		return

	# Apply gravity
	speed_vec.y += gravity * tick_delta

	# Move and check collision
	var motion := speed_vec * tick_delta
	var collision := move_and_collide(motion)
	queue_redraw()

	# Distance cap
	if position.distance_to(spawn_position) > NetConstants.BULLET_MAX_DISTANCE:
		_dead = true
		queue_free()
		return

	if collision == null:
		return

	var collider := collision.get_collider()
	var hit_pos := collision.get_position()

	if collider is CharacterBody2D:
		# Check it's not the shooter
		if str(collider.name) != str(owner_peer_id):
			hit_player.emit(collider, hit_pos)
			_dead = true
			queue_free()
			return
		# Passed through own player — move remaining distance
		var remainder := collision.get_remainder()
		move_and_collide(remainder)
	else:
		# Hit world geometry (StaticBody2D)
		hit_world.emit(hit_pos)
		_dead = true
		queue_free()
