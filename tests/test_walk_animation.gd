extends Node

## Tests for WalkAnimation pure-logic class.

const DELTA := 1.0 / 60.0


func run_tests() -> void:
	_test_generate_frames_returns_3()
	_test_idle_when_stationary()
	_test_walk_when_moving_grounded()
	_test_idle_when_airborne()
	_test_frame_cycling()
	_test_stopping_resets_to_idle()
	_test_below_threshold_stays_idle()


func _test_generate_frames_returns_3() -> void:
	var frames := WalkAnimation.generate_frames()
	Assert.assert_eq(frames.size(), 3, "generate_frames returns 3 textures")
	for i in 3:
		Assert.assert_true(frames[i] is ImageTexture, "Frame %d is ImageTexture" % i)


func _test_idle_when_stationary() -> void:
	var anim := WalkAnimation.new()
	anim.set_frames(WalkAnimation.generate_frames())
	# Stationary on ground — should stay idle
	var tex := anim.update(0.0, true, DELTA)
	# First update with no movement returns null (already idle)
	Assert.assert_eq(anim.get_current_frame(), WalkAnimation.FRAME_IDLE, "Stationary stays idle")


func _test_walk_when_moving_grounded() -> void:
	var anim := WalkAnimation.new()
	anim.set_frames(WalkAnimation.generate_frames())
	# Moving fast enough on ground — should start walking
	var tex := anim.update(100.0, true, DELTA)
	Assert.assert_true(tex != null, "Moving on ground triggers frame change")
	var frame := anim.get_current_frame()
	Assert.assert_true(
		frame == WalkAnimation.FRAME_WALK_A or frame == WalkAnimation.FRAME_WALK_B,
		"Moving on ground shows walk frame"
	)


func _test_idle_when_airborne() -> void:
	var anim := WalkAnimation.new()
	anim.set_frames(WalkAnimation.generate_frames())
	# Moving but airborne — should stay idle
	var tex := anim.update(100.0, false, DELTA)
	Assert.assert_eq(anim.get_current_frame(), WalkAnimation.FRAME_IDLE, "Airborne stays idle")


func _test_frame_cycling() -> void:
	var anim := WalkAnimation.new()
	anim.set_frames(WalkAnimation.generate_frames())
	# First update starts walk
	anim.update(100.0, true, DELTA)
	var first_frame := anim.get_current_frame()
	# Advance past frame duration
	anim.update(100.0, true, WalkAnimation.FRAME_DURATION + 0.01)
	var second_frame := anim.get_current_frame()
	Assert.assert_true(first_frame != second_frame, "Frame cycles after FRAME_DURATION")
	Assert.assert_true(
		second_frame == WalkAnimation.FRAME_WALK_A or second_frame == WalkAnimation.FRAME_WALK_B,
		"Cycled frame is a walk frame"
	)


func _test_stopping_resets_to_idle() -> void:
	var anim := WalkAnimation.new()
	anim.set_frames(WalkAnimation.generate_frames())
	# Start walking
	anim.update(100.0, true, DELTA)
	Assert.assert_true(anim.get_current_frame() != WalkAnimation.FRAME_IDLE, "Walking before stop")
	# Stop moving
	var tex := anim.update(0.0, true, DELTA)
	Assert.assert_eq(anim.get_current_frame(), WalkAnimation.FRAME_IDLE, "Stopping resets to idle")
	Assert.assert_true(tex != null, "Stopping returns idle texture")


func _test_below_threshold_stays_idle() -> void:
	var anim := WalkAnimation.new()
	anim.set_frames(WalkAnimation.generate_frames())
	# Moving below threshold
	var tex := anim.update(WalkAnimation.WALK_SPEED_THRESHOLD - 1.0, true, DELTA)
	Assert.assert_eq(anim.get_current_frame(), WalkAnimation.FRAME_IDLE, "Below threshold stays idle")
