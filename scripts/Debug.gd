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


func _ready() -> void:
	_create_overlay()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_overlay_visible = not _overlay_visible
		_overlay_label.visible = _overlay_visible


func _process(_delta: float) -> void:
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

	_overlay_label.text = "Vel: (%.1f, %.1f)\nGrounded: %s\nFuel: %.1f" % [
		vel.x, vel.y, str(grounded), fuel
	]


func set_overlay_data(data: Dictionary) -> void:
	_overlay_data = data


func enable_category(category: String) -> void:
	_enabled_categories[category] = true


func disable_category(category: String) -> void:
	_enabled_categories[category] = false


func is_category_enabled(category: String) -> bool:
	return _enabled_categories.get(category, false)


func log(category: String, message: String) -> void:
	if _enabled_categories.get(category, false):
		print("[%s] %s" % [category, message])
