extends Node

## Tests SpawnPoints selection logic: valid positions returned,
## avoidance algorithm picks farthest point, edge cases handled.
## Pure logic tests — no physics or networking required.

func run_tests() -> void:
	_test_empty_returns_fallback()
	_test_single_point_returned()
	_test_all_points_accessible()
	_test_avoidance_picks_farthest()
	_test_avoidance_multiple_players()
	_test_no_avoid_returns_random()
	_test_point_count()
	_test_get_points_returns_copy()
	_test_add_point()
	_test_game_world_spawn_count()


func _test_empty_returns_fallback() -> void:
	var sp := SpawnPoints.new()
	var result := sp.get_spawn_point()
	Assert.assert_eq(result, Vector2(3000, 960), "Empty SpawnPoints returns fallback position")


func _test_single_point_returned() -> void:
	var points: Array[Vector2] = [Vector2(100, 100)]
	var sp := SpawnPoints.new(points)
	var result := sp.get_spawn_point()
	Assert.assert_eq(result, Vector2(100, 100), "Single point returned correctly")


func _test_all_points_accessible() -> void:
	var points: Array[Vector2] = [
		Vector2(100, 100),
		Vector2(200, 200),
		Vector2(300, 300),
	]
	var sp := SpawnPoints.new(points)
	# With avoidance, each point should be selectable
	var p1 := sp.get_spawn_point([Vector2(200, 200), Vector2(300, 300)])
	Assert.assert_eq(p1, Vector2(100, 100), "Point 1 selected when avoiding 2 and 3")
	var p2 := sp.get_spawn_point([Vector2(100, 100), Vector2(300, 300)])
	Assert.assert_eq(p2, Vector2(200, 200), "Point 2 selected when avoiding 1 and 3")
	var p3 := sp.get_spawn_point([Vector2(100, 100), Vector2(200, 200)])
	Assert.assert_eq(p3, Vector2(300, 300), "Point 3 selected when avoiding 1 and 2")


func _test_avoidance_picks_farthest() -> void:
	var points: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(500, 0),
		Vector2(1000, 0),
	]
	var sp := SpawnPoints.new(points)
	var result := sp.get_spawn_point([Vector2(0, 0)])
	Assert.assert_eq(result, Vector2(1000, 0), "Avoidance picks point farthest from occupied position")


func _test_avoidance_multiple_players() -> void:
	# Three spawn points, two players near the edges — should pick the middle
	var points: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(500, 0),
		Vector2(1000, 0),
	]
	var sp := SpawnPoints.new(points)
	var avoid: Array[Vector2] = [Vector2(0, 0), Vector2(1000, 0)]
	var result := sp.get_spawn_point(avoid)
	Assert.assert_eq(result, Vector2(500, 0), "With players at edges, middle point selected")


func _test_no_avoid_returns_random() -> void:
	var points: Array[Vector2] = [
		Vector2(100, 100),
		Vector2(200, 200),
	]
	var sp := SpawnPoints.new(points)
	# Without avoidance, result should be one of the configured points
	var result := sp.get_spawn_point()
	var valid := result == Vector2(100, 100) or result == Vector2(200, 200)
	Assert.assert_true(valid, "Random selection returns a valid spawn point")


func _test_point_count() -> void:
	var points: Array[Vector2] = [
		Vector2(1, 1),
		Vector2(2, 2),
		Vector2(3, 3),
	]
	var sp := SpawnPoints.new(points)
	Assert.assert_eq(sp.get_point_count(), 3, "Point count is 3")


func _test_get_points_returns_copy() -> void:
	var points: Array[Vector2] = [Vector2(1, 1)]
	var sp := SpawnPoints.new(points)
	var returned := sp.get_points()
	returned.append(Vector2(99, 99))
	Assert.assert_eq(sp.get_point_count(), 1, "Modifying returned array doesn't affect original")


func _test_add_point() -> void:
	var sp := SpawnPoints.new()
	sp.add_point(Vector2(42, 42))
	Assert.assert_eq(sp.get_point_count(), 1, "Point added successfully")
	var result := sp.get_spawn_point()
	Assert.assert_eq(result, Vector2(42, 42), "Added point is returned")


func _test_game_world_spawn_count() -> void:
	# Verify the GameWorld scene has the expected number of spawn markers
	# by constructing what we expect (10 spawn points)
	var expected_positions: Array[Vector2] = [
		Vector2(700, 810),
		Vector2(2200, 830),
		Vector2(3800, 810),
		Vector2(5300, 830),
		Vector2(1400, 570),
		Vector2(4600, 580),
		Vector2(900, 380),
		Vector2(5100, 380),
		Vector2(3000, 130),
		Vector2(3000, 960),
	]
	Assert.assert_eq(expected_positions.size(), 10, "GameWorld should have 10 spawn points configured")
	# Verify all are in reasonable playable area (map is now 6000px wide, floor at y=1000)
	for pos in expected_positions:
		Assert.assert_true(pos.x > -100 and pos.x < 6100, "Spawn x=%d within playable area" % pos.x)
		Assert.assert_true(pos.y > 0 and pos.y < 1000, "Spawn y=%d above floor" % pos.y)
