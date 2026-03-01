extends CanvasLayer

## Simple HUD showing crosshair, HP, and ammo display.
## Created by the local player's NetworkedPlayer.

var _hp_label: Label = null
var _ammo_label: Label = null
var _crosshair: Control = null


func _ready() -> void:
	layer = 10
	_create_crosshair()
	_create_hp_label()
	_create_ammo_label()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	if _crosshair != null:
		_crosshair.position = get_viewport().get_mouse_position() - Vector2(8, 8)


func update_hp(current_hp: int, max_hp: int) -> void:
	if _hp_label != null:
		_hp_label.text = "HP: %d / %d" % [current_hp, max_hp]
		# Color based on HP percentage
		var ratio := float(current_hp) / float(max_hp)
		if ratio > 0.6:
			_hp_label.add_theme_color_override("font_color", Color.GREEN)
		elif ratio > 0.3:
			_hp_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			_hp_label.add_theme_color_override("font_color", Color.RED)


func update_ammo(current_ammo: int, max_ammo: int, is_reloading: bool) -> void:
	if _ammo_label != null:
		if is_reloading:
			_ammo_label.text = "RELOADING..."
			_ammo_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			_ammo_label.text = "Ammo: %d / %d" % [current_ammo, max_ammo]
			if current_ammo > 0:
				_ammo_label.add_theme_color_override("font_color", Color.WHITE)
			else:
				_ammo_label.add_theme_color_override("font_color", Color.RED)


func _create_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.custom_minimum_size = Vector2(16, 16)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	add_child(_crosshair)


func _draw_crosshair() -> void:
	var center := Vector2(8, 8)
	var size := 6.0
	var gap := 2.0
	var color := Color.WHITE
	# Horizontal lines
	_crosshair.draw_line(Vector2(center.x - size, center.y), Vector2(center.x - gap, center.y), color, 1.5)
	_crosshair.draw_line(Vector2(center.x + gap, center.y), Vector2(center.x + size, center.y), color, 1.5)
	# Vertical lines
	_crosshair.draw_line(Vector2(center.x, center.y - size), Vector2(center.x, center.y - gap), color, 1.5)
	_crosshair.draw_line(Vector2(center.x, center.y + gap), Vector2(center.x, center.y + size), color, 1.5)
	# Center dot
	_crosshair.draw_circle(center, 1.0, color)


func _create_hp_label() -> void:
	_hp_label = Label.new()
	_hp_label.position = Vector2(20, 660)
	_hp_label.add_theme_color_override("font_color", Color.GREEN)
	_hp_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	_hp_label.add_theme_font_size_override("font_size", 20)
	_hp_label.text = "HP: 100 / 100"
	add_child(_hp_label)


func _create_ammo_label() -> void:
	_ammo_label = Label.new()
	_ammo_label.position = Vector2(20, 630)
	_ammo_label.add_theme_color_override("font_color", Color.WHITE)
	_ammo_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_ammo_label.add_theme_constant_override("shadow_offset_x", 1)
	_ammo_label.add_theme_constant_override("shadow_offset_y", 1)
	_ammo_label.add_theme_font_size_override("font_size", 20)
	_ammo_label.text = "Ammo: 30 / 30"
	add_child(_ammo_label)
