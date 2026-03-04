extends Node

## Tests for jetpack fuel consumption and recharging.

const DELTA := 1.0 / 60.0


func run_tests() -> void:
	_test_initial_fuel_is_max()
	_test_jetpack_consumes_fuel()
	_test_jetpack_provides_upward_thrust()
	_test_jetpack_stops_at_zero_fuel()
	_test_fuel_recharges_on_ground()
	_test_fuel_recharges_in_air_when_not_jetting()
	_test_fuel_capped_at_max()


func _make_state(vel := Vector2.ZERO, grounded := true, cur_fuel := MovementTuning.JETPACK_MAX_FUEL) -> Dictionary:
	return {"velocity": vel, "grounded": grounded, "fuel": cur_fuel}


func _make_input(move_dir := 0.0, jump := false, jetpack := false, dive := false, aim := 0.0) -> Dictionary:
	return {"move_dir": move_dir, "jump": jump, "jetpack": jetpack, "dive": dive, "aim_angle": aim}


func _test_initial_fuel_is_max() -> void:
	var state := _make_state()
	Assert.assert_eq(state.fuel, MovementTuning.JETPACK_MAX_FUEL, "Initial fuel is max")


func _test_jetpack_consumes_fuel() -> void:
	var state := _make_state(Vector2.ZERO, false)
	var input := _make_input(0.0, false, true)
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_lt(result.fuel, MovementTuning.JETPACK_MAX_FUEL, "Jetpack use decreases fuel")


func _test_jetpack_provides_upward_thrust() -> void:
	var state := _make_state(Vector2.ZERO, false)
	var input := _make_input(0.0, false, true)
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	# Gravity pulls down, jetpack pushes up — net should be negative if jetpack is strong enough
	var gravity_only_state := _make_state(Vector2.ZERO, false)
	var gravity_only_input := _make_input()
	var gravity_result := PlayerController.calculate_velocity(gravity_only_state, gravity_only_input, DELTA)
	Assert.assert_lt(result.velocity.y, gravity_result.velocity.y, "Jetpack thrust counters gravity")


func _test_jetpack_stops_at_zero_fuel() -> void:
	var state := _make_state(Vector2.ZERO, false, 0.0)
	var input := _make_input(0.0, false, true)
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	# With 0 fuel, jetpack should not fire — only gravity applies
	var no_jetpack_result := PlayerController.calculate_velocity(state, _make_input(), DELTA)
	Assert.assert_eq(result.velocity.y, no_jetpack_result.velocity.y, "No jetpack thrust at zero fuel")
	Assert.assert_eq(result.fuel, 0.0, "Fuel stays at zero")


func _test_fuel_recharges_on_ground() -> void:
	var low_fuel := 50.0
	var state := _make_state(Vector2.ZERO, true, low_fuel)
	var input := _make_input()  # no jetpack pressed
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_gt(result.fuel, low_fuel, "Fuel recharges on ground")


func _test_fuel_recharges_in_air_when_not_jetting() -> void:
	var low_fuel := 50.0
	var state := _make_state(Vector2.ZERO, false, low_fuel)
	var input := _make_input()  # no jetpack pressed, in air
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_gt(result.fuel, low_fuel, "Fuel recharges in air when not using jetpack")


func _test_fuel_capped_at_max() -> void:
	# Fuel at max, on ground, not using jetpack — should not exceed max
	var state := _make_state(Vector2.ZERO, true, MovementTuning.JETPACK_MAX_FUEL)
	var input := _make_input()
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_true(result.fuel <= MovementTuning.JETPACK_MAX_FUEL, "Fuel capped at max")
