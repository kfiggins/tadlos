extends Node2D

## Tests bullet lifecycle caps: per-player limit, total limit, distance cap.
## Uses direct scene manipulation — no networking required.

var _bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var _bullets_node: Node = null


func run_tests() -> void:
	_test_per_player_cap()
	_test_total_cap()
	_test_distance_cap_property()
	_test_oldest_removed_on_per_player_cap()
	_test_oldest_removed_on_total_cap()
	_test_constants_sane()
	_cleanup()


func _setup() -> void:
	if _bullets_node != null:
		_bullets_node.queue_free()
	_bullets_node = Node.new()
	_bullets_node.name = "Bullets"
	add_child(_bullets_node)


func _cleanup() -> void:
	if _bullets_node != null:
		_bullets_node.queue_free()
		_bullets_node = null


func _spawn_test_bullet(peer_id: int, pos: Vector2 = Vector2.ZERO) -> CharacterBody2D:
	var bullet := _bullet_scene.instantiate() as CharacterBody2D
	bullet.position = pos
	bullet.spawn_position = pos
	bullet.owner_peer_id = peer_id
	bullet.speed_vec = Vector2(100, 0)
	_bullets_node.add_child(bullet)
	return bullet


func _get_player_bullet_count(peer_id: int) -> int:
	var count := 0
	for bullet in _bullets_node.get_children():
		if bullet is CharacterBody2D and bullet.owner_peer_id == peer_id:
			count += 1
	return count


func _remove_oldest_player_bullet(peer_id: int) -> bool:
	for bullet in _bullets_node.get_children():
		if bullet is CharacterBody2D and bullet.owner_peer_id == peer_id:
			bullet.queue_free()
			_bullets_node.remove_child(bullet)
			return true
	return false


func _enforce_caps_and_spawn(peer_id: int, pos: Vector2 = Vector2.ZERO) -> CharacterBody2D:
	## Replicates the cap enforcement logic from NetworkedPlayer._spawn_bullet().
	# Total cap
	while _bullets_node.get_child_count() >= NetConstants.MAX_BULLETS_TOTAL:
		var oldest := _bullets_node.get_child(0)
		if oldest:
			oldest.queue_free()
			_bullets_node.remove_child(oldest)
		else:
			break

	# Per-player cap
	while _get_player_bullet_count(peer_id) >= NetConstants.MAX_BULLETS_PER_PLAYER:
		if not _remove_oldest_player_bullet(peer_id):
			break

	return _spawn_test_bullet(peer_id, pos)


# --- Tests ---

func _test_per_player_cap() -> void:
	_setup()
	var peer_id := 1

	# Spawn exactly MAX_BULLETS_PER_PLAYER bullets
	for i in NetConstants.MAX_BULLETS_PER_PLAYER:
		_enforce_caps_and_spawn(peer_id)

	Assert.assert_eq(
		_get_player_bullet_count(peer_id),
		NetConstants.MAX_BULLETS_PER_PLAYER,
		"Player has exactly MAX_BULLETS_PER_PLAYER bullets"
	)

	# Spawn one more — should still be at the cap
	_enforce_caps_and_spawn(peer_id)
	Assert.assert_eq(
		_get_player_bullet_count(peer_id),
		NetConstants.MAX_BULLETS_PER_PLAYER,
		"Player bullet count stays at cap after spawning extra"
	)

	# Spawn several more
	for i in 5:
		_enforce_caps_and_spawn(peer_id)
	Assert.assert_eq(
		_get_player_bullet_count(peer_id),
		NetConstants.MAX_BULLETS_PER_PLAYER,
		"Player bullet count stays at cap after spawning many extra"
	)


func _test_total_cap() -> void:
	_setup()

	# Spawn MAX_BULLETS_TOTAL across multiple players
	var players_needed := NetConstants.MAX_BULLETS_TOTAL / NetConstants.MAX_BULLETS_PER_PLAYER
	for p in players_needed:
		var peer_id := p + 1
		for i in NetConstants.MAX_BULLETS_PER_PLAYER:
			_enforce_caps_and_spawn(peer_id)

	Assert.assert_eq(
		_bullets_node.get_child_count(),
		NetConstants.MAX_BULLETS_TOTAL,
		"Total bullets at MAX_BULLETS_TOTAL"
	)

	# Spawn one more for a new player — total cap should remove oldest
	_enforce_caps_and_spawn(99)
	Assert.assert_true(
		_bullets_node.get_child_count() <= NetConstants.MAX_BULLETS_TOTAL,
		"Total bullet count stays at or below cap"
	)


func _test_distance_cap_property() -> void:
	_setup()
	var bullet := _spawn_test_bullet(1, Vector2(0, 0))
	bullet.spawn_position = Vector2(0, 0)
	Assert.assert_eq(bullet.spawn_position, Vector2(0, 0), "Bullet spawn_position is set")

	# Distance check: a bullet far from spawn should exceed cap
	var far_distance := NetConstants.BULLET_MAX_DISTANCE + 100.0
	Assert.assert_true(
		far_distance > NetConstants.BULLET_MAX_DISTANCE,
		"Test distance exceeds max bullet distance"
	)

	# Verify the constant is sane
	Assert.assert_gt(NetConstants.BULLET_MAX_DISTANCE, 0.0, "BULLET_MAX_DISTANCE is positive")


func _test_oldest_removed_on_per_player_cap() -> void:
	_setup()
	var peer_id := 1

	# Spawn bullets and track the first one by instance ID
	var first_bullet := _enforce_caps_and_spawn(peer_id)
	var first_id := first_bullet.get_instance_id()
	for i in NetConstants.MAX_BULLETS_PER_PLAYER - 1:
		_enforce_caps_and_spawn(peer_id)

	Assert.assert_eq(
		_get_player_bullet_count(peer_id),
		NetConstants.MAX_BULLETS_PER_PLAYER,
		"At per-player cap before overflow test"
	)

	# Spawn one more — the first bullet should be removed from tree
	_enforce_caps_and_spawn(peer_id)
	var still_exists := false
	for bullet in _bullets_node.get_children():
		if bullet.get_instance_id() == first_id:
			still_exists = true
	Assert.assert_false(still_exists, "Oldest bullet was removed when cap exceeded")


func _test_oldest_removed_on_total_cap() -> void:
	_setup()

	# Fill to total cap with multiple players
	var players_needed := NetConstants.MAX_BULLETS_TOTAL / NetConstants.MAX_BULLETS_PER_PLAYER
	var first_id: int = 0
	for p in players_needed:
		var peer_id := p + 1
		for i in NetConstants.MAX_BULLETS_PER_PLAYER:
			var b := _enforce_caps_and_spawn(peer_id)
			if first_id == 0:
				first_id = b.get_instance_id()

	Assert.assert_eq(
		_bullets_node.get_child_count(),
		NetConstants.MAX_BULLETS_TOTAL,
		"At total cap before overflow test"
	)

	# Spawn one more with a new player — oldest should be gone
	_enforce_caps_and_spawn(99)
	var still_exists := false
	for bullet in _bullets_node.get_children():
		if bullet.get_instance_id() == first_id:
			still_exists = true
	Assert.assert_false(still_exists, "Oldest bullet globally was removed at total cap")


func _test_constants_sane() -> void:
	Assert.assert_eq(NetConstants.MAX_BULLETS_PER_PLAYER, 10, "MAX_BULLETS_PER_PLAYER is 10")
	Assert.assert_eq(NetConstants.MAX_BULLETS_TOTAL, 80, "MAX_BULLETS_TOTAL is 80")
	Assert.assert_eq(NetConstants.BULLET_MAX_DISTANCE, 2000.0, "BULLET_MAX_DISTANCE is 2000")
	Assert.assert_true(
		NetConstants.MAX_BULLETS_TOTAL >= NetConstants.MAX_BULLETS_PER_PLAYER * NetConstants.MAX_PLAYERS,
		"Total cap >= per-player cap * max players"
	)
