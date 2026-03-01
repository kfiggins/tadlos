extends Node

## Debug logging helper with category-based toggles and F1 overlay.
## Registered as an autoload so any script can call Debug.log(...).

# Feature toggles
var draw_hitboxes: bool = false
var show_ping: bool = false
var show_velocity: bool = false

# Overlay state
var _overlay_visible: bool = false
var _overlay_label: Label = null

# Category enable/disable map
var _enabled_categories: Dictionary = {}

# Overlay data (set by PlayerController each frame)
var _overlay_data: Dictionary = {}

# Performance counters
var _bullets_alive: int = 0
var _tick_time_ms: float = 0.0
var _rpc_sent_count: int = 0
var _rpc_received_count: int = 0
var _rpc_sent_per_sec: int = 0
var _rpc_received_per_sec: int = 0
var _rpc_timer: float = 0.0
const RPC_COUNT_INTERVAL := 1.0


func _ready() -> void:
	_create_overlay()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_overlay_visible = not _overlay_visible
		_overlay_label.visible = _overlay_visible


func _process(delta: float) -> void:
	# RPC counter snapshot each second
	_rpc_timer += delta
	if _rpc_timer >= RPC_COUNT_INTERVAL:
		_rpc_sent_per_sec = _rpc_sent_count
		_rpc_received_per_sec = _rpc_received_count
		_rpc_sent_count = 0
		_rpc_received_count = 0
		_rpc_timer -= RPC_COUNT_INTERVAL

	if _overlay_visible and _overlay_label != null:
		_update_overlay_text()


func _create_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	_overlay_label = Label.new()
	_overlay_label.position = Vector2(10, 10)
	_overlay_label.visible = false
	_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	_overlay_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_overlay_label.add_theme_constant_override("shadow_offset_x", 1)
	_overlay_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(_overlay_label)


func _update_overlay_text() -> void:
	var vel: Vector2 = _overlay_data.get("velocity", Vector2.ZERO)
	var grounded: bool = _overlay_data.get("grounded", false)
	var fuel: float = _overlay_data.get("fuel", 0.0)

	var text := "Vel: (%.1f, %.1f)\nGrounded: %s\nFuel: %.1f" % [
		vel.x, vel.y, str(grounded), fuel
	]

	# Net info (Phase 2+)
	if multiplayer.has_multiplayer_peer():
		text += "\n---"
		text += "\nHost: %s" % str(NetManager.is_host)
		text += "\nPeer ID: %d" % NetManager.local_peer_id
		text += "\nPlayers: %d" % (NetManager.connected_peers.size() + 1)

	# Performance counters (Phase 6)
	text += "\n--- Perf ---"
	text += "\nBullets: %d" % _bullets_alive
	text += "\nRPC out/s: %d" % _rpc_sent_per_sec
	text += "\nRPC in/s: %d" % _rpc_received_per_sec
	text += "\nTick: %.1f ms" % _tick_time_ms
	text += "\nMem: %.1f MB" % (OS.get_static_memory_usage() / 1048576.0)

	# Lag simulator info
	if NetManager.lag_sim.is_active():
		text += "\n--- Lag Sim ---"
		text += "\nLatency: %.0f ms" % NetManager.lag_sim.latency_ms
		text += "\nJitter: %.0f ms" % NetManager.lag_sim.jitter_ms
		text += "\nPkt Loss: %.0f%%" % (NetManager.lag_sim.packet_loss * 100.0)

	_overlay_label.text = text


func set_overlay_data(data: Dictionary) -> void:
	_overlay_data = data


func record_rpc_sent() -> void:
	_rpc_sent_count += 1


func record_rpc_received() -> void:
	_rpc_received_count += 1


func set_bullets_alive(count: int) -> void:
	_bullets_alive = count


func set_tick_time_ms(ms: float) -> void:
	_tick_time_ms = ms


func enable_category(category: String) -> void:
	_enabled_categories[category] = true


func disable_category(category: String) -> void:
	_enabled_categories[category] = false


func is_category_enabled(category: String) -> bool:
	return _enabled_categories.get(category, false)


func log(category: String, message: String) -> void:
	if _enabled_categories.get(category, false):
		print("[%s] %s" % [category, message])
