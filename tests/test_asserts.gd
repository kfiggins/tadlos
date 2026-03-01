extends Node

## Tests for the Assert utility itself.


func run_tests() -> void:
	_test_assert_true()
	_test_assert_false()
	_test_assert_eq()
	_test_assert_neq()
	_test_assert_gt()
	_test_assert_lt()
	_test_assert_null()
	_test_assert_not_null()


## Call an Assert function that we expect to fail, without polluting the counters.
## Returns the result of the call.
func _expect_fail(callable: Callable) -> bool:
	var saved_pass := Assert.pass_count
	var saved_fail := Assert.fail_count
	var result: bool = callable.call()
	# Restore counters — the failure was intentional
	Assert.pass_count = saved_pass
	Assert.fail_count = saved_fail
	return result


func _test_assert_true() -> void:
	Assert.assert_true(true, "assert_true(true) should pass")
	var result := _expect_fail(func() -> bool: return Assert.assert_true(false, "(expected fail) assert_true(false)"))
	Assert.assert_true(result == false, "assert_true(false) returns false")


func _test_assert_false() -> void:
	Assert.assert_false(false, "assert_false(false) should pass")
	var result := _expect_fail(func() -> bool: return Assert.assert_false(true, "(expected fail) assert_false(true)"))
	Assert.assert_true(result == false, "assert_false(true) returns false")


func _test_assert_eq() -> void:
	Assert.assert_eq(1, 1, "assert_eq(1, 1) should pass")
	Assert.assert_eq("hello", "hello", "assert_eq strings should pass")
	var result := _expect_fail(func() -> bool: return Assert.assert_eq(1, 2, "(expected fail) assert_eq(1, 2)"))
	Assert.assert_true(result == false, "assert_eq(1, 2) returns false")


func _test_assert_neq() -> void:
	Assert.assert_neq(1, 2, "assert_neq(1, 2) should pass")
	var result := _expect_fail(func() -> bool: return Assert.assert_neq(1, 1, "(expected fail) assert_neq(1, 1)"))
	Assert.assert_true(result == false, "assert_neq(1, 1) returns false")


func _test_assert_gt() -> void:
	Assert.assert_gt(5, 3, "assert_gt(5, 3) should pass")
	var result := _expect_fail(func() -> bool: return Assert.assert_gt(3, 5, "(expected fail) assert_gt(3, 5)"))
	Assert.assert_true(result == false, "assert_gt(3, 5) returns false")


func _test_assert_lt() -> void:
	Assert.assert_lt(3, 5, "assert_lt(3, 5) should pass")
	var result := _expect_fail(func() -> bool: return Assert.assert_lt(5, 3, "(expected fail) assert_lt(5, 3)"))
	Assert.assert_true(result == false, "assert_lt(5, 3) returns false")


func _test_assert_null() -> void:
	Assert.assert_null(null, "assert_null(null) should pass")
	var result := _expect_fail(func() -> bool: return Assert.assert_null(1, "(expected fail) assert_null(1)"))
	Assert.assert_true(result == false, "assert_null(1) returns false")


func _test_assert_not_null() -> void:
	Assert.assert_not_null(1, "assert_not_null(1) should pass")
	var result := _expect_fail(func() -> bool: return Assert.assert_not_null(null, "(expected fail) assert_not_null(null)"))
	Assert.assert_true(result == false, "assert_not_null(null) returns false")
