extends Node2D

## Tests that projectile bullets hit players, reduce HP, and trigger death.
## Requires physics scene with a CharacterBody2D target.

var _target: CharacterBody2D = null
var _target_health: Health = null
var _bullets_node: Node = null

# Track signals
var _hit_received := false
var _hit_position := Vector2.ZERO
var _died_received := false


func run_tests() -> void:
	_setup_scene()
	# Wait for physics to register collision shapes
	await _wait_frames(5)
	await _test_bullet_hits_target()
	await _test_four_hits_kills()
	await _test_bullet_despawns_on_hit()
	_cleanup()


func _setup_scene() -> void:
	# Create a floor so the target has ground
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(400, 500)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(2000, 32)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	# Create bullets container
	_bullets_node = Node.new()
	_bullets_node.name = "Bullets"
	add_child(_bullets_node)

	# Create target player (CharacterBody2D with collision shape)
	_target = CharacterBody2D.new()
	_target.name = "99"  # Fake peer ID
	_target.position = Vector2(400, 300)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 48)
	col.shape = shape
	_target.add_child(col)
	add_child(_target)

	_target_health = Health.new()
	_target_health.died.connect(func(_id: int) -> void: _died_received = true)


func _spawn_test_bullet(from: Vector2, direction: Vector2, owner_id: int = 1) -> Node2D:
	var bullet_scene := preload("res://scenes/Bullet.tscn")
	var bullet := bullet_scene.instantiate()
	bullet.position = from
	bullet.speed_vec = direction.normalized() * 1200.0
	bullet.owner_peer_id = owner_id
	bullet.damage = 25
	bullet.gravity = 0.0  # No gravity for predictable test
	bullet.hit_player.connect(func(victim: CharacterBody2D, pos: Vector2) -> void:
		_hit_received = true
		_hit_position = pos
		_target_health.take_damage(bullet.damage, bullet.owner_peer_id)
	)
	_bullets_node.add_child(bullet)
	return bullet


func _test_bullet_hits_target() -> void:
	_hit_received = false
	# Spawn bullet to the left of target, aimed right at it
	var bullet := _spawn_test_bullet(
		Vector2(100, 300),  # left of target
		Vector2(1, 0),      # moving right
	)

	# Wait for bullet to travel and hit
	for i in 60:
		await get_tree().process_frame
		if _hit_received:
			break

	Assert.assert_true(_hit_received, "Bullet hit the target player")
	Assert.assert_eq(_target_health.current_hp, 75, "Target HP decreased to 75 after 25 damage")


func _test_four_hits_kills() -> void:
	# Reset health and signal
	_target_health.reset()
	_died_received = false

	# Fire 4 bullets sequentially
	for i in 4:
		_hit_received = false
		var bullet := _spawn_test_bullet(
			Vector2(100, 300),
			Vector2(1, 0),
		)
		for j in 60:
			await get_tree().process_frame
			if _hit_received:
				break
		# Small gap between shots
		await _wait_frames(2)

	Assert.assert_eq(_target_health.current_hp, 0, "Target HP is 0 after 4 hits of 25 damage")
	Assert.assert_true(_died_received, "died signal emitted after lethal damage")


func _test_bullet_despawns_on_hit() -> void:
	_target_health.reset()
	_hit_received = false
	var bullet := _spawn_test_bullet(
		Vector2(100, 300),
		Vector2(1, 0),
	)

	for i in 60:
		await get_tree().process_frame
		if _hit_received:
			break

	Assert.assert_true(_hit_received, "Bullet hit before despawn check")
	# Bullet should be freed after hit — wait a frame for queue_free
	await _wait_frames(2)
	Assert.assert_eq(_bullets_node.get_child_count(), 0, "Bullet despawned after hitting player")


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _cleanup() -> void:
	for child in _bullets_node.get_children():
		child.queue_free()
	await _wait_frames(2)
