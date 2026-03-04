extends Node

## Tests BotAI logic: target selection, state transitions, aim, boundary avoidance.
## Pure logic tests — no scene or physics dependencies.

func run_tests() -> void:
	_test_evaluate_state_no_target()
	_test_evaluate_state_idle_far()
	_test_evaluate_state_pursue()
	_test_evaluate_state_engage()
	_test_evaluate_state_retreat_low_hp()
	_test_evaluate_state_no_retreat_high_hp()
	_test_compute_aim_direction()
	_test_compute_aim_inaccuracy_range()
	_test_bot_constants()


func _test_evaluate_state_no_target() -> void:
	var state := BotAI.evaluate_state(BotAI.State.PURSUE, 100, INF, false)
	Assert.assert_eq(state, BotAI.State.IDLE, "No target -> IDLE")


func _test_evaluate_state_idle_far() -> void:
	var state := BotAI.evaluate_state(BotAI.State.IDLE, 100, 2000.0, true)
	Assert.assert_eq(state, BotAI.State.IDLE, "Target beyond pursuit range -> IDLE")


func _test_evaluate_state_pursue() -> void:
	var state := BotAI.evaluate_state(BotAI.State.IDLE, 100, 900.0, true)
	Assert.assert_eq(state, BotAI.State.PURSUE, "Target in pursuit range -> PURSUE")


func _test_evaluate_state_engage() -> void:
	var state := BotAI.evaluate_state(BotAI.State.IDLE, 100, 400.0, true)
	Assert.assert_eq(state, BotAI.State.ENGAGE, "Target in engage range -> ENGAGE")


func _test_evaluate_state_retreat_low_hp() -> void:
	var state := BotAI.evaluate_state(BotAI.State.ENGAGE, 20, 300.0, true)
	Assert.assert_eq(state, BotAI.State.RETREAT, "Low HP + close target -> RETREAT")


func _test_evaluate_state_no_retreat_high_hp() -> void:
	var state := BotAI.evaluate_state(BotAI.State.ENGAGE, 80, 300.0, true)
	Assert.assert_eq(state, BotAI.State.ENGAGE, "High HP + close target -> ENGAGE (not retreat)")


func _test_compute_aim_direction() -> void:
	# Aim from origin to a point to the right
	var from := Vector2(0, 0)
	var to := Vector2(100, 0)
	var angle := BotAI.compute_aim(from, to)
	# Should be approximately 0 (right), within inaccuracy
	Assert.assert_true(
		absf(angle) < BotAI.AIM_INACCURACY + 0.01,
		"Aim at target to the right is ~0 radians (got %.3f)" % angle
	)

	# Aim at target above
	var to_up := Vector2(0, -100)
	var angle_up := BotAI.compute_aim(from, to_up)
	Assert.assert_true(
		absf(angle_up - (-PI / 2.0)) < BotAI.AIM_INACCURACY + 0.01,
		"Aim at target above is ~-PI/2 (got %.3f)" % angle_up
	)


func _test_compute_aim_inaccuracy_range() -> void:
	var from := Vector2(0, 0)
	var to := Vector2(100, 0)
	var min_angle := INF
	var max_angle := -INF
	for i in 100:
		var angle := BotAI.compute_aim(from, to)
		min_angle = minf(min_angle, angle)
		max_angle = maxf(max_angle, angle)
	var spread := max_angle - min_angle
	Assert.assert_true(
		spread <= BotAI.AIM_INACCURACY * 2.0 + 0.01,
		"Aim spread within inaccuracy bounds (spread=%.3f)" % spread
	)
	Assert.assert_true(
		spread > 0.01,
		"Aim has some randomness (spread=%.3f)" % spread
	)


func _test_bot_constants() -> void:
	Assert.assert_eq(BotConstants.BOT_PEER_ID_START, 100, "Bot peer IDs start at 100")
	Assert.assert_eq(BotConstants.MAX_BOTS, 7, "Max bots is 7")
