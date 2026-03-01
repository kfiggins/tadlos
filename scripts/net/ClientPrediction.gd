class_name ClientPrediction

## Manages client-side prediction input buffer and server reconciliation.
## Stores inputs with predicted states keyed by sequence number.
## On server state receipt, detects mismatches and provides pending inputs for replay.

var _input_buffer: Array = []


func record_input(seq: int, input: Dictionary, predicted_state: Dictionary) -> void:
	_input_buffer.append({
		"seq": seq,
		"input": input,
		"predicted_state": predicted_state,
	})


## Process server state and determine if reconciliation is needed.
## Returns {needs_reconciliation: bool, pending_inputs: Array}.
## pending_inputs contains {seq: int, input: Dictionary} for replay.
func on_server_state(server_position: Vector2, last_seq: int) -> Dictionary:
	# Find predicted state at last_seq
	var predicted_pos := Vector2.ZERO
	var found := false
	for entry in _input_buffer:
		if entry.seq == last_seq:
			predicted_pos = entry.predicted_state.position
			found = true
			break

	# Prune inputs with seq <= last_seq
	var new_buffer: Array = []
	for entry in _input_buffer:
		if entry.seq > last_seq:
			new_buffer.append(entry)
	_input_buffer = new_buffer

	if not found:
		return {
			"needs_reconciliation": true,
			"pending_inputs": _extract_pending_inputs(),
		}

	var diff := server_position.distance_to(predicted_pos)
	if diff > NetConstants.RECONCILIATION_EPSILON:
		return {
			"needs_reconciliation": true,
			"pending_inputs": _extract_pending_inputs(),
		}

	return {
		"needs_reconciliation": false,
		"pending_inputs": [],
	}


## Update predicted states after reconciliation replay.
## corrected_states[i] corresponds to _input_buffer[i].
func update_predicted_states(corrected_states: Array) -> void:
	for i in range(mini(corrected_states.size(), _input_buffer.size())):
		_input_buffer[i].predicted_state = corrected_states[i]


func _extract_pending_inputs() -> Array:
	var inputs: Array = []
	for entry in _input_buffer:
		inputs.append({"seq": entry.seq, "input": entry.input})
	return inputs


func get_pending_count() -> int:
	return _input_buffer.size()


func clear() -> void:
	_input_buffer.clear()
