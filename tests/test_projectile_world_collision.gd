extends Node2D

## Tests that projectile bullets despawn on world geometry contact.
## Requires physics scene with a StaticBody2D wall.

var _bullets_node: Node = null
var _world_hit_received := false
var _world_hit_position := Vector2.ZERO


func run_tests() -> void:
	_setup_scene()
	await _wait_frames(5)
	await _test_bullet_despawns_on_wall()
	await _test_bullet_does_not_pass_through_wall()
	await _test_bullet_despawns_on_lifetime()
	_cleanup()


func _setup_scene() -> void:
	_bullets_node = Node.new()
	_bullets_node.name = "Bullets"
	add_child(_bullets_node)

	# Create a wall (StaticBody2D)
	var wall := StaticBody2D.new()
	wall.name = "Wall"
	wall.position = Vector2(500, 300)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 400)
	col.shape = shape
	wall.add_child(col)
	add_child(wall)


func _spawn_test_bullet(from: Vector2, direction: Vector2) -> Node2D:
	var bullet_scene := preload("res://scenes/Bullet.tscn")
	var bullet := bullet_scene.instantiate()
	bullet.position = from
	bullet.speed_vec = direction.normalized() * 1200.0
	bullet.owner_peer_id = 1
	bullet.damage = 25
	bullet.gravity = 0.0
	bullet.hit_world.connect(func(pos: Vector2) -> void:
		_world_hit_received = true
		_world_hit_position = pos
	)
	_bullets_node.add_child(bullet)
	return bullet


func _test_bullet_despawns_on_wall() -> void:
	_world_hit_received = false
	var bullet := _spawn_test_bullet(
		Vector2(100, 300),  # left of wall
		Vector2(1, 0),      # moving right toward wall
	)

	for i in 60:
		await get_tree().process_frame
		if _world_hit_received:
			break

	Assert.assert_true(_world_hit_received, "Bullet hit world geometry")
	await _wait_frames(2)
	Assert.assert_eq(_bullets_node.get_child_count(), 0, "Bullet despawned on wall contact")


func _test_bullet_does_not_pass_through_wall() -> void:
	_world_hit_received = false
	_world_hit_position = Vector2.ZERO
	var bullet := _spawn_test_bullet(
		Vector2(100, 300),
		Vector2(1, 0),
	)

	for i in 60:
		await get_tree().process_frame
		if _world_hit_received:
			break

	Assert.assert_true(_world_hit_received, "Bullet hit before passing through")
	# Wall is at x=500, width 32 → left edge at x=484
	# Hit position should be at or before the wall's left edge
	Assert.assert_lt(_world_hit_position.x, 520.0, "Hit position is at the wall, not past it")


func _test_bullet_despawns_on_lifetime() -> void:
	# Spawn bullet going away from everything with short lifetime
	var bullet_scene := preload("res://scenes/Bullet.tscn")
	var bullet := bullet_scene.instantiate()
	bullet.position = Vector2(100, 100)
	bullet.speed_vec = Vector2(0, -100)  # Going up, away from wall
	bullet.owner_peer_id = 1
	bullet.damage = 25
	bullet.gravity = 0.0
	bullet.max_lifetime = 0.1  # Very short lifetime
	_bullets_node.add_child(bullet)

	# Wait for lifetime to expire (0.1s = ~3 ticks at 30Hz + buffer)
	await _wait_frames(15)

	Assert.assert_eq(_bullets_node.get_child_count(), 0, "Bullet despawned after lifetime expired")


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _cleanup() -> void:
	for child in _bullets_node.get_children():
		child.queue_free()
	await _wait_frames(2)
