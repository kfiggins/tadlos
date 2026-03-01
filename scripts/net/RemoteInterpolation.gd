class_name RemoteInterpolation

## Interpolates remote player state between received snapshots.
## Renders with a configurable delay behind real-time for smooth movement.

const MAX_BUFFER_SIZE: int = 20

var _snapshot_buffer: Array = []


## Add a snapshot with an explicit timestamp (caller manages time).
func add_snapshot(state: Dictionary, timestamp: float) -> void:
	_snapshot_buffer.append({"state": state, "time": timestamp})
	while _snapshot_buffer.size() > MAX_BUFFER_SIZE:
		_snapshot_buffer.pop_front()


## Returns interpolated state at current_time minus interpolation delay.
## Returns empty Dictionary if no snapshots available.
func get_interpolated_state(current_time: float) -> Dictionary:
	var render_time := current_time - NetConstants.INTERPOLATION_DELAY

	if _snapshot_buffer.is_empty():
		return {}

	if _snapshot_buffer.size() == 1:
		return _snapshot_buffer[0].state.duplicate()

	# Find two snapshots bracketing render_time
	var from_idx := -1
	for i in range(_snapshot_buffer.size() - 1):
		if _snapshot_buffer[i].time <= render_time and _snapshot_buffer[i + 1].time >= render_time:
			from_idx = i
			break

	if from_idx == -1:
		if render_time < _snapshot_buffer[0].time:
			return _snapshot_buffer[0].state.duplicate()
		return _snapshot_buffer[-1].state.duplicate()

	var from_snap: Dictionary = _snapshot_buffer[from_idx]
	var to_snap: Dictionary = _snapshot_buffer[from_idx + 1]
	var duration: float = to_snap.time - from_snap.time
	var t := 0.0
	if duration > 0.0:
		t = (render_time - from_snap.time) / duration
	t = clampf(t, 0.0, 1.0)

	var from_state: Dictionary = from_snap.state
	var to_state: Dictionary = to_snap.state

	return {
		"position": from_state.position.lerp(to_state.position, t),
		"velocity": from_state.velocity.lerp(to_state.velocity, t),
		"fuel": lerpf(from_state.fuel, to_state.fuel, t),
		"aim_angle": lerp_angle(from_state.aim_angle, to_state.aim_angle, t),
		"grounded": to_state.grounded if t > 0.5 else from_state.grounded,
	}


func get_buffer_size() -> int:
	return _snapshot_buffer.size()


func clear() -> void:
	_snapshot_buffer.clear()
