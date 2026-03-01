extends Node

## Tests that NetConstants values are correct and accessible.


func run_tests() -> void:
	_test_tick_rate()
	_test_snapshot_rate()
	_test_max_input_rate()
	_test_max_players()
	_test_default_port()
	_test_interpolation_delay()
	_test_reconciliation_epsilon()


func _test_tick_rate() -> void:
	Assert.assert_eq(NetConstants.TICK_RATE, 30, "TICK_RATE is 30")


func _test_snapshot_rate() -> void:
	Assert.assert_eq(NetConstants.SNAPSHOT_RATE, 30, "SNAPSHOT_RATE is 30")


func _test_max_input_rate() -> void:
	Assert.assert_eq(NetConstants.MAX_INPUT_RATE, 30, "MAX_INPUT_RATE is 30")


func _test_max_players() -> void:
	Assert.assert_eq(NetConstants.MAX_PLAYERS, 8, "MAX_PLAYERS is 8")


func _test_default_port() -> void:
	Assert.assert_eq(NetConstants.DEFAULT_PORT, 7777, "DEFAULT_PORT is 7777")


func _test_interpolation_delay() -> void:
	Assert.assert_eq(NetConstants.INTERPOLATION_DELAY, 0.1, "INTERPOLATION_DELAY is 0.1")


func _test_reconciliation_epsilon() -> void:
	Assert.assert_eq(NetConstants.RECONCILIATION_EPSILON, 2.0, "RECONCILIATION_EPSILON is 2.0")
