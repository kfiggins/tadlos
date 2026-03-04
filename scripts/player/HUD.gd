extends CanvasLayer

## HUD showing crosshair, HP, ammo, death screen, kill feed, and scoreboard.
## Created by the local player's NetworkedPlayer.

var _hp_label: Label = null
var _ammo_label: Label = null
var _crosshair: Control = null

# Boost ring
var _boost_ring: Control = null
var _boost_ratio: float = 1.0

# Death screen
var _death_overlay: ColorRect = null
var _death_label: Label = null
var _respawn_label: Label = null
var _respawn_countdown: float = 0.0
var _showing_death: bool = false

# Kill feed
var _kill_feed_container: VBoxContainer = null
var _kill_feed_entries: Array = []  # [{label: Label, time: float}]
const KILL_FEED_DURATION := 4.0
const KILL_FEED_MAX := 5

# Scoreboard
var _scoreboard_panel: ColorRect = null
var _scoreboard_labels: Array[Label] = []
var _scoreboard_visible: bool = false

# Team data (populated by set_team_data for TDM mode)
var _team_assignments: Dictionary = {}
var _team_scores: Dictionary = {}

# Countdown
var _countdown_label: Label = null
var _go_timer: float = 0.0


func _ready() -> void:
	layer = 10
	_create_crosshair()
	_create_hp_label()
	_create_ammo_label()
	_create_death_screen()
	_create_kill_feed()
	_create_scoreboard()
	_create_countdown_label()
	_create_boost_ring()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	if _crosshair != null:
		_crosshair.position = get_viewport().get_mouse_position() - Vector2(8, 8)

	# Death screen countdown
	if _showing_death and _respawn_label != null:
		_respawn_countdown -= delta
		if _respawn_countdown > 0.0:
			_respawn_label.text = "Respawning in %.1f..." % _respawn_countdown
		else:
			_respawn_label.text = "Respawning..."

	# "GO!" fade timer
	if _go_timer > 0.0:
		_go_timer -= delta
		if _go_timer <= 0.0 and _countdown_label != null:
			_countdown_label.visible = false

	# Kill feed fade
	var to_remove: Array = []
	for entry in _kill_feed_entries:
		entry.time -= delta
		if entry.time <= 0.0:
			entry.label.queue_free()
			to_remove.append(entry)
		elif entry.time < 1.0:
			entry.label.modulate.a = entry.time
	for entry in to_remove:
		_kill_feed_entries.erase(entry)


func update_hp(current_hp: int, max_hp: int) -> void:
	if _hp_label != null:
		_hp_label.text = "HP: %d / %d" % [current_hp, max_hp]
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


func update_fuel(current_fuel: float, max_fuel: float) -> void:
	_boost_ratio = clampf(current_fuel / max_fuel, 0.0, 1.0)
	if _boost_ring != null:
		_boost_ring.queue_redraw()


# --- Death Screen ---

func show_death_screen(killer_id: int, respawn_delay: float) -> void:
	_showing_death = true
	_respawn_countdown = respawn_delay
	if _death_overlay != null:
		_death_overlay.visible = true
	if _death_label != null:
		_death_label.text = "Killed by Player %d" % killer_id
	if _crosshair != null:
		_crosshair.visible = false


func hide_death_screen() -> void:
	_showing_death = false
	if _death_overlay != null:
		_death_overlay.visible = false
	if _crosshair != null:
		_crosshair.visible = true


# --- Countdown ---

func show_countdown(seconds: int) -> void:
	if _countdown_label == null:
		return
	_go_timer = 0.0
	if seconds > 0:
		_countdown_label.text = str(seconds)
		_countdown_label.add_theme_color_override("font_color", Color.WHITE)
		_countdown_label.visible = true
	else:
		_countdown_label.text = "GO!"
		_countdown_label.add_theme_color_override("font_color", Color.GREEN)
		_countdown_label.visible = true
		_go_timer = 1.0


func hide_countdown() -> void:
	if _countdown_label == null:
		return
	if _go_timer <= 0.0:
		_countdown_label.visible = false


# --- Kill Feed ---

func add_kill_feed(killer_id: int, victim_id: int) -> void:
	if _kill_feed_container == null:
		return
	# Trim old entries
	while _kill_feed_entries.size() >= KILL_FEED_MAX:
		var oldest = _kill_feed_entries.pop_front()
		oldest.label.queue_free()

	var label := Label.new()
	label.text = "Player %d killed Player %d" % [killer_id, victim_id]
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kill_feed_container.add_child(label)
	_kill_feed_entries.append({"label": label, "time": KILL_FEED_DURATION})


# --- Scoreboard ---

func set_team_data(assignments: Dictionary, t_scores: Dictionary) -> void:
	_team_assignments = assignments
	_team_scores = t_scores


func toggle_scoreboard(scores: Dictionary) -> void:
	_scoreboard_visible = true
	_update_scoreboard(scores)
	if _scoreboard_panel != null:
		_scoreboard_panel.visible = true


func hide_scoreboard() -> void:
	_scoreboard_visible = false
	if _scoreboard_panel != null:
		_scoreboard_panel.visible = false


func _update_scoreboard(scores: Dictionary) -> void:
	# Clear old labels
	for label in _scoreboard_labels:
		label.queue_free()
	_scoreboard_labels.clear()

	if _scoreboard_panel == null:
		return

	if not _team_assignments.is_empty():
		_update_team_scoreboard(scores)
	else:
		_update_ffa_scoreboard(scores)


func _update_ffa_scoreboard(scores: Dictionary) -> void:
	# Header
	var header := Label.new()
	header.text = "  Player          Kills    Deaths"
	header.position = Vector2(20, 15)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color.YELLOW)
	_scoreboard_panel.add_child(header)
	_scoreboard_labels.append(header)

	# Sort by kills descending
	var sorted_ids: Array = scores.keys()
	sorted_ids.sort_custom(func(a, b): return scores[a]["kills"] > scores[b]["kills"])

	var y_offset := 45
	for peer_id in sorted_ids:
		var entry: Dictionary = scores[peer_id]
		var label := Label.new()
		label.text = "  Player %-8s %4d     %4d" % [str(peer_id), entry.get("kills", 0), entry.get("deaths", 0)]
		label.position = Vector2(20, y_offset)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color.WHITE)
		_scoreboard_panel.add_child(label)
		_scoreboard_labels.append(label)
		y_offset += 25


func _update_team_scoreboard(scores: Dictionary) -> void:
	var y_offset := 15

	# Group players by team
	var red_players: Array = []
	var blue_players: Array = []
	for peer_id in scores:
		var t: int = _team_assignments.get(peer_id, 0)
		if t == TeamConstants.Team.RED:
			red_players.append(peer_id)
		else:
			blue_players.append(peer_id)

	# Sort each team by kills descending
	red_players.sort_custom(func(a, b): return scores[a]["kills"] > scores[b]["kills"])
	blue_players.sort_custom(func(a, b): return scores[a]["kills"] > scores[b]["kills"])

	# Red team header
	var red_score: int = _team_scores.get(TeamConstants.Team.RED, 0)
	y_offset = _add_team_section(scores, red_players, "RED TEAM", red_score, Color(1.0, 0.4, 0.4), y_offset)

	y_offset += 10  # Spacing between teams

	# Blue team header
	var blue_score: int = _team_scores.get(TeamConstants.Team.BLUE, 0)
	y_offset = _add_team_section(scores, blue_players, "BLUE TEAM", blue_score, Color(0.4, 0.6, 1.0), y_offset)

	# Resize panel to fit content
	_scoreboard_panel.custom_minimum_size.y = maxf(300.0, y_offset + 20.0)
	_scoreboard_panel.size.y = _scoreboard_panel.custom_minimum_size.y


func _add_team_section(scores: Dictionary, player_ids: Array, team_name: String, team_score: int, color: Color, y_start: int) -> int:
	var y_offset := y_start

	# Team header
	var header := Label.new()
	header.text = "  %s  -  Score: %d" % [team_name, team_score]
	header.position = Vector2(20, y_offset)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", color)
	_scoreboard_panel.add_child(header)
	_scoreboard_labels.append(header)
	y_offset += 28

	# Column header
	var col_header := Label.new()
	col_header.text = "  Player          Kills    Deaths"
	col_header.position = Vector2(20, y_offset)
	col_header.add_theme_font_size_override("font_size", 14)
	col_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_scoreboard_panel.add_child(col_header)
	_scoreboard_labels.append(col_header)
	y_offset += 22

	# Player entries
	for peer_id in player_ids:
		var entry: Dictionary = scores[peer_id]
		var label := Label.new()
		label.text = "  Player %-8s %4d     %4d" % [str(peer_id), entry.get("kills", 0), entry.get("deaths", 0)]
		label.position = Vector2(20, y_offset)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.4))
		_scoreboard_panel.add_child(label)
		_scoreboard_labels.append(label)
		y_offset += 25

	return y_offset


# --- UI Creation ---

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
	_crosshair.draw_line(Vector2(center.x - size, center.y), Vector2(center.x - gap, center.y), color, 1.5)
	_crosshair.draw_line(Vector2(center.x + gap, center.y), Vector2(center.x + size, center.y), color, 1.5)
	_crosshair.draw_line(Vector2(center.x, center.y - size), Vector2(center.x, center.y - gap), color, 1.5)
	_crosshair.draw_line(Vector2(center.x, center.y + gap), Vector2(center.x, center.y + size), color, 1.5)
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


func _create_death_screen() -> void:
	_death_overlay = ColorRect.new()
	_death_overlay.color = Color(0, 0, 0, 0.6)
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_overlay.visible = false
	add_child(_death_overlay)

	_death_label = Label.new()
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.position = Vector2(-100, -40)
	_death_label.custom_minimum_size = Vector2(200, 30)
	_death_label.add_theme_font_size_override("font_size", 28)
	_death_label.add_theme_color_override("font_color", Color.RED)
	_death_overlay.add_child(_death_label)

	_respawn_label = Label.new()
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_respawn_label.set_anchors_preset(Control.PRESET_CENTER)
	_respawn_label.position = Vector2(-100, 10)
	_respawn_label.custom_minimum_size = Vector2(200, 30)
	_respawn_label.add_theme_font_size_override("font_size", 20)
	_respawn_label.add_theme_color_override("font_color", Color.WHITE)
	_death_overlay.add_child(_respawn_label)


func _create_kill_feed() -> void:
	_kill_feed_container = VBoxContainer.new()
	_kill_feed_container.position = Vector2(340, 10)
	_kill_feed_container.custom_minimum_size = Vector2(600, 0)
	_kill_feed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kill_feed_container)


func _create_countdown_label() -> void:
	_countdown_label = Label.new()
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.position = Vector2(-60, -120)
	_countdown_label.custom_minimum_size = Vector2(120, 80)
	_countdown_label.add_theme_font_size_override("font_size", 72)
	_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	_countdown_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_countdown_label.add_theme_constant_override("shadow_offset_x", 3)
	_countdown_label.add_theme_constant_override("shadow_offset_y", 3)
	_countdown_label.visible = false
	add_child(_countdown_label)


func _create_boost_ring() -> void:
	_boost_ring = Control.new()
	_boost_ring.custom_minimum_size = Vector2(60, 60)
	_boost_ring.size = Vector2(60, 60)
	# Bottom-right corner, offset inward
	_boost_ring.position = Vector2(900, 640)
	_boost_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_ring.draw.connect(_draw_boost_ring)
	add_child(_boost_ring)


func _draw_boost_ring() -> void:
	var center := Vector2(30, 30)
	var outer_radius := 26.0
	var inner_radius := 18.0
	var bg_color := Color(0.3, 0.3, 0.3, 0.5)

	# Background ring (full doughnut, dark)
	_draw_arc_fill(_boost_ring, center, inner_radius, outer_radius, 0.0, TAU, bg_color)

	# Filled portion (clockwise from top, based on fuel ratio)
	if _boost_ratio > 0.0:
		var fill_color: Color
		if _boost_ratio > 0.5:
			fill_color = Color(0.2, 0.8, 1.0, 0.9)  # Cyan-blue
		elif _boost_ratio > 0.25:
			fill_color = Color(1.0, 0.8, 0.2, 0.9)  # Yellow warning
		else:
			fill_color = Color(1.0, 0.3, 0.2, 0.9)  # Red low
		var fill_angle := _boost_ratio * TAU
		# Start from top (-PI/2), go clockwise
		_draw_arc_fill(_boost_ring, center, inner_radius, outer_radius, -PI / 2.0, -PI / 2.0 + fill_angle, fill_color)

	# "BOOST" label below the ring
	_boost_ring.draw_string(
		ThemeDB.fallback_font, Vector2(5, 72),
		"BOOST", HORIZONTAL_ALIGNMENT_CENTER, 50,
		10, Color(0.8, 0.8, 0.8, 0.7)
	)


func _draw_arc_fill(control: Control, center: Vector2, r_inner: float, r_outer: float, angle_from: float, angle_to: float, color: Color) -> void:
	# Draw a filled arc (doughnut segment) using a polygon
	var segments := 32
	var points: PackedVector2Array = PackedVector2Array()
	# Outer arc
	for i in range(segments + 1):
		var angle := angle_from + (angle_to - angle_from) * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * r_outer)
	# Inner arc (reversed)
	for i in range(segments, -1, -1):
		var angle := angle_from + (angle_to - angle_from) * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * r_inner)
	control.draw_polygon(points, PackedColorArray([color]))


func _create_scoreboard() -> void:
	_scoreboard_panel = ColorRect.new()
	_scoreboard_panel.color = Color(0, 0, 0, 0.75)
	_scoreboard_panel.position = Vector2(290, 150)
	_scoreboard_panel.custom_minimum_size = Vector2(400, 300)
	_scoreboard_panel.size = Vector2(400, 300)
	_scoreboard_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scoreboard_panel.visible = false
	add_child(_scoreboard_panel)
