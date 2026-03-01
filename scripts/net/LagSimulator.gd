class_name LagSimulator
extends RefCounted

## Artificial lag simulator for testing under bad network conditions.
## Query should_drop_packet() and get_delay_ms() before sending RPCs
## to simulate poor network conditions.

var latency_ms: float = 0.0
var jitter_ms: float = 0.0
var packet_loss: float = 0.0  # 0.0 to 1.0


func is_active() -> bool:
	return latency_ms > 0.0 or jitter_ms > 0.0 or packet_loss > 0.0


func should_drop_packet() -> bool:
	if packet_loss <= 0.0:
		return false
	return randf() < packet_loss


func get_delay_ms() -> float:
	if latency_ms <= 0.0 and jitter_ms <= 0.0:
		return 0.0
	var jitter := randf_range(-jitter_ms, jitter_ms) if jitter_ms > 0.0 else 0.0
	return maxf(0.0, latency_ms + jitter)


func get_delayed_send_time() -> float:
	return get_delay_ms() / 1000.0
