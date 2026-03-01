extends Node

## Assertion utility for test scenes.
## Registered as an autoload so tests can call Assert.assert_true(...) etc.

var pass_count: int = 0
var fail_count: int = 0


func reset() -> void:
	pass_count = 0
	fail_count = 0


func get_total() -> int:
	return pass_count + fail_count


func _record_pass(message: String) -> void:
	pass_count += 1
	print("[PASS] %s" % message)


func _record_fail(message: String) -> void:
	fail_count += 1
	print("[FAIL] %s" % message)


func assert_true(condition: bool, message: String = "") -> bool:
	var msg := message if message != "" else "assert_true"
	if condition:
		_record_pass(msg)
		return true
	else:
		_record_fail(msg)
		return false


func assert_false(condition: bool, message: String = "") -> bool:
	var msg := message if message != "" else "assert_false"
	if not condition:
		_record_pass(msg)
		return true
	else:
		_record_fail(msg)
		return false


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	var msg := message if message != "" else "assert_eq(%s == %s)" % [actual, expected]
	if actual == expected:
		_record_pass(msg)
		return true
	else:
		_record_fail("%s — got %s, expected %s" % [msg, actual, expected])
		return false


func assert_neq(actual: Variant, expected: Variant, message: String = "") -> bool:
	var msg := message if message != "" else "assert_neq(%s != %s)" % [actual, expected]
	if actual != expected:
		_record_pass(msg)
		return true
	else:
		_record_fail("%s — values should differ but both are %s" % [msg, actual])
		return false


func assert_gt(actual: Variant, expected: Variant, message: String = "") -> bool:
	var msg := message if message != "" else "assert_gt(%s > %s)" % [actual, expected]
	if actual > expected:
		_record_pass(msg)
		return true
	else:
		_record_fail("%s — got %s, expected > %s" % [msg, actual, expected])
		return false


func assert_lt(actual: Variant, expected: Variant, message: String = "") -> bool:
	var msg := message if message != "" else "assert_lt(%s < %s)" % [actual, expected]
	if actual < expected:
		_record_pass(msg)
		return true
	else:
		_record_fail("%s — got %s, expected < %s" % [msg, actual, expected])
		return false


func assert_null(value: Variant, message: String = "") -> bool:
	var msg := message if message != "" else "assert_null"
	if value == null:
		_record_pass(msg)
		return true
	else:
		_record_fail("%s — expected null, got %s" % [msg, value])
		return false


func assert_not_null(value: Variant, message: String = "") -> bool:
	var msg := message if message != "" else "assert_not_null"
	if value != null:
		_record_pass(msg)
		return true
	else:
		_record_fail("%s — expected non-null value" % msg)
		return false
