extends Node

## Tests remote player interpolation between snapshots.

func run_tests() -> void:
	_test_empty_buffer_returns_empty()
	_test_single_snapshot_returns_it()
	_test_interpolation_between_two_snapshots()
	_test_interpolation_midpoint_values()
	_test_render_time_before_buffer()
	_test_render_time_after_buffer()
	_test_buffer_size_limited()
	_test_uneven_snapshot_intervals()
	_test_aim_angle_interpolation()
	_test_grounded_threshold()
	_test_clear_empties_buffer()


func _make_state(
	pos: Vector2,
	vel := Vector2.ZERO,
	fuel := 100.0,
	aim := 0.0,
	grounded := true,
) -> Dictionary:
	return {
		"position": pos,
		"velocity": vel,
		"fuel": fuel,
		"aim_angle": aim,
		"grounded": grounded,
	}


func _test_empty_buffer_returns_empty() -> void:
	var interp := RemoteInterpolation.new()
	var result := interp.get_interpolated_state(1.0)
	Assert.assert_true(result.is_empty(), "Empty buffer returns empty dict")


func _test_single_snapshot_returns_it() -> void:
	var interp := RemoteInterpolation.new()
	var state := _make_state(Vector2(100, 200))
	interp.add_snapshot(state, 0.0)
	var result := interp.get_interpolated_state(0.5)
	Assert.assert_eq(result.position, Vector2(100, 200), "Single snapshot returns its position")


func _test_interpolation_between_two_snapshots() -> void:
	var interp := RemoteInterpolation.new()
	interp.add_snapshot(_make_state(Vector2(0, 0)), 0.0)
	interp.add_snapshot(_make_state(Vector2(100, 0)), 0.2)

	# Query at time 0.2 with 0.1s delay -> render_time = 0.1
	# 0.1 is midway between 0.0 and 0.2 -> t = 0.5
	var result := interp.get_interpolated_state(0.2)
	var expected_x := 50.0
	Assert.assert_true(
		absf(result.position.x - expected_x) < 1.0,
		"Interpolated x=%.1f near expected=%.1f" % [result.position.x, expected_x]
	)


func _test_interpolation_midpoint_values() -> void:
	var interp := RemoteInterpolation.new()
	interp.add_snapshot(_make_state(Vector2(0, 0), Vector2.ZERO, 100.0), 0.0)
	interp.add_snapshot(_make_state(Vector2(200, 100), Vector2(50, 25), 80.0), 0.2)

	# render_time = 0.2 - 0.1 = 0.1, t = 0.1/0.2 = 0.5
	var result := interp.get_interpolated_state(0.2)
	Assert.assert_true(
		absf(result.position.x - 100.0) < 1.0,
		"Midpoint position.x=%.1f near 100" % result.position.x
	)
	Assert.assert_true(
		absf(result.position.y - 50.0) < 1.0,
		"Midpoint position.y=%.1f near 50" % result.position.y
	)
	Assert.assert_true(
		absf(result.fuel - 90.0) < 1.0,
		"Midpoint fuel=%.1f near 90" % result.fuel
	)
	Assert.assert_true(
		absf(result.velocity.x - 25.0) < 1.0,
		"Midpoint velocity.x=%.1f near 25" % result.velocity.x
	)


func _test_render_time_before_buffer() -> void:
	var interp := RemoteInterpolation.new()
	interp.add_snapshot(_make_state(Vector2(100, 200)), 1.0)
	interp.add_snapshot(_make_state(Vector2(200, 300)), 2.0)

	# Query at time 0.5 -> render_time = 0.4, before all snapshots
	var result := interp.get_interpolated_state(0.5)
	Assert.assert_eq(
		result.position, Vector2(100, 200),
		"Before buffer returns earliest snapshot"
	)


func _test_render_time_after_buffer() -> void:
	var interp := RemoteInterpolation.new()
	interp.add_snapshot(_make_state(Vector2(100, 200)), 0.0)
	interp.add_snapshot(_make_state(Vector2(200, 300)), 0.1)

	# Query at time 5.0 -> render_time = 4.9, past all snapshots
	var result := interp.get_interpolated_state(5.0)
	Assert.assert_eq(
		result.position, Vector2(200, 300),
		"Past buffer returns latest snapshot"
	)


func _test_buffer_size_limited() -> void:
	var interp := RemoteInterpolation.new()
	for i in range(30):
		interp.add_snapshot(_make_state(Vector2(i * 10.0, 0)), float(i) * 0.033)

	Assert.assert_true(
		interp.get_buffer_size() <= RemoteInterpolation.MAX_BUFFER_SIZE,
		"Buffer capped at %d (actual: %d)" % [
			RemoteInterpolation.MAX_BUFFER_SIZE, interp.get_buffer_size()
		]
	)


func _test_uneven_snapshot_intervals() -> void:
	var interp := RemoteInterpolation.new()
	# Simulate jitter: uneven arrival times
	interp.add_snapshot(_make_state(Vector2(0, 0)), 0.0)
	interp.add_snapshot(_make_state(Vector2(50, 0)), 0.05)    # 50ms gap
	interp.add_snapshot(_make_state(Vector2(100, 0)), 0.15)   # 100ms gap
	interp.add_snapshot(_make_state(Vector2(200, 0)), 0.20)   # 50ms gap

	# Query at current_time=0.2 -> render_time = 0.1
	# render_time 0.1 falls between snap[1] (0.05) and snap[2] (0.15)
	var result := interp.get_interpolated_state(0.2)
	Assert.assert_true(
		result.position.x > 50.0 and result.position.x < 100.0,
		"Interpolated x=%.1f between 50 and 100 in uneven gap" % result.position.x
	)


func _test_aim_angle_interpolation() -> void:
	var interp := RemoteInterpolation.new()
	interp.add_snapshot(_make_state(Vector2.ZERO, Vector2.ZERO, 100.0, 0.0), 0.0)
	interp.add_snapshot(_make_state(Vector2.ZERO, Vector2.ZERO, 100.0, PI / 2.0), 0.2)

	# render_time = 0.1, t = 0.5 -> lerp_angle(0, PI/2, 0.5) = PI/4
	var result := interp.get_interpolated_state(0.2)
	Assert.assert_true(
		absf(result.aim_angle - PI / 4.0) < 0.1,
		"Aim angle interpolated to ~PI/4 (got %.3f)" % result.aim_angle
	)


func _test_grounded_threshold() -> void:
	var interp := RemoteInterpolation.new()
	interp.add_snapshot(
		_make_state(Vector2.ZERO, Vector2.ZERO, 100.0, 0.0, true), 0.0
	)
	interp.add_snapshot(
		_make_state(Vector2.ZERO, Vector2.ZERO, 100.0, 0.0, false), 0.2
	)

	# At t < 0.5: render_time = 0.05 (current_time=0.15), t = 0.25
	var result_early := interp.get_interpolated_state(0.15)
	Assert.assert_true(
		result_early.grounded,
		"Early interpolation (t<0.5): grounded = true (from_state)"
	)

	# At t > 0.5: render_time = 0.15 (current_time=0.25), t = 0.75
	var result_late := interp.get_interpolated_state(0.25)
	Assert.assert_false(
		result_late.grounded,
		"Late interpolation (t>0.5): grounded = false (to_state)"
	)


func _test_clear_empties_buffer() -> void:
	var interp := RemoteInterpolation.new()
	interp.add_snapshot(_make_state(Vector2.ZERO), 0.0)
	interp.clear()
	Assert.assert_eq(interp.get_buffer_size(), 0, "Buffer empty after clear")
