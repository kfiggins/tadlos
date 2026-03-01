extends Node

## Tests for basic movement via the pure calculate_velocity() function.

const DELTA := 1.0 / 60.0


func run_tests() -> void:
	_test_right_movement_accelerates()
	_test_left_movement_accelerates()
	_test_velocity_clamped_to_max()
	_test_ground_friction_decelerates()
	_test_gravity_applied_in_air()
	_test_no_gravity_on_ground()
	_test_jump_sets_negative_y_velocity()
	_test_jump_only_when_grounded()
	_test_air_accel_less_than_ground()


func _make_state(vel := Vector2.ZERO, grounded := true, cur_fuel := MovementTuning.JETPACK_MAX_FUEL) -> Dictionary:
	return {"velocity": vel, "grounded": grounded, "fuel": cur_fuel}


func _make_input(move_dir := 0.0, jump := false, jetpack := false, dive := false, aim := 0.0) -> Dictionary:
	return {"move_dir": move_dir, "jump": jump, "jetpack": jetpack, "dive": dive, "aim_angle": aim}


func _test_right_movement_accelerates() -> void:
	var state := _make_state()
	var input := _make_input(1.0)
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_gt(result.velocity.x, 0.0, "Moving right produces positive x velocity")


func _test_left_movement_accelerates() -> void:
	var state := _make_state()
	var input := _make_input(-1.0)
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_lt(result.velocity.x, 0.0, "Moving left produces negative x velocity")


func _test_velocity_clamped_to_max() -> void:
	# Start at max speed and try to accelerate more
	var state := _make_state(Vector2(MovementTuning.MAX_SPEED, 0))
	var input := _make_input(1.0)
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_true(result.velocity.x <= MovementTuning.MAX_SPEED, "Velocity clamped to MAX_SPEED")


func _test_ground_friction_decelerates() -> void:
	var state := _make_state(Vector2(200.0, 0))
	var input := _make_input()  # no movement input
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_lt(result.velocity.x, 200.0, "Ground friction reduces velocity")
	Assert.assert_gt(result.velocity.x, 0.0, "Friction doesn't reverse direction")


func _test_gravity_applied_in_air() -> void:
	var state := _make_state(Vector2.ZERO, false)
	var input := _make_input()
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_gt(result.velocity.y, 0.0, "Gravity increases y velocity in air")


func _test_no_gravity_on_ground() -> void:
	var state := _make_state(Vector2.ZERO, true)
	var input := _make_input()
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_eq(result.velocity.y, 0.0, "No gravity applied on ground")


func _test_jump_sets_negative_y_velocity() -> void:
	var state := _make_state()
	var input := _make_input(0.0, true)
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	Assert.assert_lt(result.velocity.y, 0.0, "Jump produces negative y velocity (upward)")
	Assert.assert_eq(result.velocity.y, MovementTuning.JUMP_VELOCITY, "Jump velocity matches constant")


func _test_jump_only_when_grounded() -> void:
	var state := _make_state(Vector2.ZERO, false)
	var input := _make_input(0.0, true)
	var result := PlayerController.calculate_velocity(state, input, DELTA)
	# In air, gravity is applied but jump should not trigger
	Assert.assert_gt(result.velocity.y, 0.0, "Cannot jump in air — gravity pulls down")


func _test_air_accel_less_than_ground() -> void:
	var state_ground := _make_state(Vector2.ZERO, true)
	var state_air := _make_state(Vector2.ZERO, false)
	var input := _make_input(1.0)
	var result_ground := PlayerController.calculate_velocity(state_ground, input, DELTA)
	var result_air := PlayerController.calculate_velocity(state_air, input, DELTA)
	Assert.assert_gt(result_ground.velocity.x, result_air.velocity.x, "Ground accel > air accel")
