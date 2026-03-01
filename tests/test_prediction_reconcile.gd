extends Node

## Tests client-side prediction input buffering and server reconciliation.

func run_tests() -> void:
	_test_record_input_stores_entries()
	_test_matching_server_state_no_reconciliation()
	_test_mismatched_server_state_triggers_reconciliation()
	_test_old_inputs_pruned()
	_test_pending_inputs_returned_for_replay()
	_test_no_matching_seq_triggers_reconciliation()
	_test_within_epsilon_no_reconciliation()
	_test_update_predicted_states()
	_test_clear_empties_buffer()
	_test_multiple_server_states_converge()


func _make_input(move_dir := 0.0) -> Dictionary:
	return {
		"move_dir": move_dir,
		"jump": false,
		"jetpack": false,
		"dive": false,
		"aim_angle": 0.0,
	}


func _make_predicted_state(pos: Vector2) -> Dictionary:
	return {
		"position": pos,
		"velocity": Vector2.ZERO,
		"fuel": 100.0,
		"grounded": true,
	}


func _test_record_input_stores_entries() -> void:
	var pred := ClientPrediction.new()
	pred.record_input(1, _make_input(1.0), _make_predicted_state(Vector2(10, 0)))
	pred.record_input(2, _make_input(1.0), _make_predicted_state(Vector2(20, 0)))
	Assert.assert_eq(pred.get_pending_count(), 2, "Two inputs recorded")


func _test_matching_server_state_no_reconciliation() -> void:
	var pred := ClientPrediction.new()
	var pos := Vector2(100, 200)
	pred.record_input(1, _make_input(1.0), _make_predicted_state(pos))
	pred.record_input(2, _make_input(1.0), _make_predicted_state(Vector2(110, 200)))

	var result := pred.on_server_state(pos, 1)
	Assert.assert_false(result.needs_reconciliation, "Matching position: no reconciliation needed")
	Assert.assert_eq(pred.get_pending_count(), 1, "Seq 1 pruned, seq 2 remains")


func _test_mismatched_server_state_triggers_reconciliation() -> void:
	var pred := ClientPrediction.new()
	pred.record_input(1, _make_input(1.0), _make_predicted_state(Vector2(100, 200)))
	pred.record_input(2, _make_input(1.0), _make_predicted_state(Vector2(110, 200)))
	pred.record_input(3, _make_input(1.0), _make_predicted_state(Vector2(120, 200)))

	# Server says position at seq 1 is far from predicted
	var server_pos := Vector2(50, 200)
	var result := pred.on_server_state(server_pos, 1)
	Assert.assert_true(result.needs_reconciliation, "Mismatch triggers reconciliation")
	Assert.assert_eq(result.pending_inputs.size(), 2, "Inputs 2 and 3 pending for replay")


func _test_old_inputs_pruned() -> void:
	var pred := ClientPrediction.new()
	pred.record_input(1, _make_input(1.0), _make_predicted_state(Vector2(10, 0)))
	pred.record_input(2, _make_input(1.0), _make_predicted_state(Vector2(20, 0)))
	pred.record_input(3, _make_input(1.0), _make_predicted_state(Vector2(30, 0)))

	pred.on_server_state(Vector2(20, 0), 2)
	Assert.assert_eq(pred.get_pending_count(), 1, "Only seq 3 remains after pruning <= 2")


func _test_pending_inputs_returned_for_replay() -> void:
	var pred := ClientPrediction.new()
	var input_a := _make_input(1.0)
	var input_b := _make_input(-1.0)
	pred.record_input(1, _make_input(0.0), _make_predicted_state(Vector2.ZERO))
	pred.record_input(2, input_a, _make_predicted_state(Vector2(10, 0)))
	pred.record_input(3, input_b, _make_predicted_state(Vector2(5, 0)))

	# Force reconciliation with a large mismatch
	var result := pred.on_server_state(Vector2(999, 999), 1)
	Assert.assert_true(result.needs_reconciliation, "Reconciliation triggered")
	Assert.assert_eq(result.pending_inputs.size(), 2, "Two pending inputs for replay")
	Assert.assert_eq(result.pending_inputs[0].seq, 2, "First pending is seq 2")
	Assert.assert_eq(result.pending_inputs[1].seq, 3, "Second pending is seq 3")
	Assert.assert_eq(
		result.pending_inputs[0].input.move_dir, 1.0,
		"Pending input 0 has correct move_dir"
	)
	Assert.assert_eq(
		result.pending_inputs[1].input.move_dir, -1.0,
		"Pending input 1 has correct move_dir"
	)


func _test_no_matching_seq_triggers_reconciliation() -> void:
	var pred := ClientPrediction.new()
	pred.record_input(5, _make_input(1.0), _make_predicted_state(Vector2(50, 0)))

	# Server sends seq 3 which isn't in our buffer
	var result := pred.on_server_state(Vector2(30, 0), 3)
	Assert.assert_true(result.needs_reconciliation, "No matching seq triggers reconciliation")
	Assert.assert_eq(result.pending_inputs.size(), 1, "Seq 5 still pending (> 3)")


func _test_within_epsilon_no_reconciliation() -> void:
	var pred := ClientPrediction.new()
	var pos := Vector2(100, 200)
	# Server position within epsilon (2.0 px default)
	var server_pos := Vector2(100.5, 200.5)
	pred.record_input(1, _make_input(1.0), _make_predicted_state(pos))

	var result := pred.on_server_state(server_pos, 1)
	var diff := pos.distance_to(server_pos)
	Assert.assert_lt(
		diff, NetConstants.RECONCILIATION_EPSILON,
		"Diff %.2f < epsilon %.2f" % [diff, NetConstants.RECONCILIATION_EPSILON]
	)
	Assert.assert_false(result.needs_reconciliation, "Within epsilon: no reconciliation needed")


func _test_update_predicted_states() -> void:
	var pred := ClientPrediction.new()
	pred.record_input(1, _make_input(), _make_predicted_state(Vector2(10, 0)))
	pred.record_input(2, _make_input(), _make_predicted_state(Vector2(20, 0)))
	pred.record_input(3, _make_input(), _make_predicted_state(Vector2(30, 0)))

	# Simulate server state at seq 1 with mismatch → reconcile
	pred.on_server_state(Vector2(999, 999), 1)
	# Update predicted states after replay (seqs 2 and 3 remain)
	var corrected := [
		_make_predicted_state(Vector2(15, 0)),
		_make_predicted_state(Vector2(25, 0)),
	]
	pred.update_predicted_states(corrected)

	# Now server state at seq 2 should match corrected prediction
	var result := pred.on_server_state(Vector2(15, 0), 2)
	Assert.assert_false(
		result.needs_reconciliation,
		"Corrected prediction matches server after update"
	)


func _test_clear_empties_buffer() -> void:
	var pred := ClientPrediction.new()
	pred.record_input(1, _make_input(), _make_predicted_state(Vector2.ZERO))
	pred.clear()
	Assert.assert_eq(pred.get_pending_count(), 0, "Buffer empty after clear")


func _test_multiple_server_states_converge() -> void:
	var pred := ClientPrediction.new()
	# Simulate 10 ticks of input
	var pos := Vector2.ZERO
	for i in range(1, 11):
		pos.x += 10.0
		pred.record_input(i, _make_input(1.0), _make_predicted_state(pos))

	# Server processed up to seq 5, position matches
	var result1 := pred.on_server_state(Vector2(50, 0), 5)
	Assert.assert_false(result1.needs_reconciliation, "First check: positions match")
	Assert.assert_eq(pred.get_pending_count(), 5, "5 pending inputs after first check")

	# Server processed up to seq 8, position matches
	var result2 := pred.on_server_state(Vector2(80, 0), 8)
	Assert.assert_false(result2.needs_reconciliation, "Second check: positions match")
	Assert.assert_eq(pred.get_pending_count(), 2, "2 pending inputs after second check")
