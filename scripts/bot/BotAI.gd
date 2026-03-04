class_name BotAI
extends Node

## Smart bot AI controller. Drives a NetworkedPlayer via set_bot_input()
## using a state machine for purposeful movement, aiming, and combat.
## Runs server-side only.

enum State { IDLE, PURSUE, ENGAGE, RETREAT }

# Tuning
const ENGAGE_RANGE := 600.0
const PURSUIT_RANGE := 1200.0
const RETREAT_HP_THRESHOLD := 30
const AIM_INACCURACY := 0.08        # Radians of spread
const DECISION_INTERVAL := 0.2      # Re-evaluate state every 200ms
const WALL_DETECT_DIST := 50.0
const EDGE_DETECT_DIST := 80.0
const STUCK_CHECK_INTERVAL := 0.5
const STUCK_THRESHOLD := 10.0       # Pixels moved to not be "stuck"
const STUCK_COUNT_LIMIT := 3        # Checks before unstuck triggers

# Map boundaries (from GameWorld.tscn geometry)
const MAP_LEFT := -384.0
const MAP_RIGHT := 1584.0
const MAP_FLOOR_Y := 304.0

var _player: CharacterBody2D = null
var _state: int = State.IDLE
var _target: CharacterBody2D = null

# Timers
var _decision_timer: float = 0.0
var _fire_cooldown: float = 0.0
var _strafe_timer: float = 0.0
var _strafe_dir: float = 1.0

# Patrol
var _patrol_dir: float = 1.0

# Stuck detection
var _stuck_check_timer: float = 0.0
var _stuck_count: int = 0
var _last_position: Vector2 = Vector2.ZERO


func setup(player_node: CharacterBody2D) -> void:
	_player = player_node
	_player.is_bot = true
	_last_position = _player.global_position
	_patrol_dir = [-1.0, 1.0][randi() % 2]


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.is_player_dead():
		_state = State.IDLE
		_target = null
		return

	_fire_cooldown -= delta
	_update_stuck_detection(delta)

	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = DECISION_INTERVAL
		_pick_target()
		_state = evaluate_state(_state, _get_player_hp(), _get_target_distance(), _target != null)

	var input := _generate_input(delta)
	input = _apply_boundary_avoidance(input)
	_player.set_bot_input(input)

	if _should_fire():
		_player._bot_wants_fire = true
		_fire_cooldown = randf_range(0.1, 0.25)


# --- Target Selection ---

func _pick_target() -> void:
	var players_node := _player.get_node_or_null("../../Players")
	if players_node == null:
		_target = null
		return

	var my_team: int = _player.team
	var best: CharacterBody2D = null
	var best_dist := INF

	for child in players_node.get_children():
		if child == _player:
			continue
		if child.has_method("is_player_dead") and child.is_player_dead():
			continue
		# Skip teammates in team modes
		var child_team: int = child.get("team") if child.get("team") != null else 0
		if my_team != 0 and child_team == my_team:
			continue
		var d := _player.global_position.distance_to(child.global_position)
		if d < best_dist:
			best_dist = d
			best = child

	_target = best


## Pure state evaluation, usable in tests.
static func evaluate_state(current: int, hp: int, target_dist: float, has_target: bool) -> int:
	if not has_target:
		return State.IDLE

	if hp <= RETREAT_HP_THRESHOLD and target_dist < ENGAGE_RANGE:
		return State.RETREAT

	if target_dist <= ENGAGE_RANGE:
		return State.ENGAGE

	if target_dist <= PURSUIT_RANGE:
		return State.PURSUE

	return State.IDLE


# --- Input Generation ---

func _generate_input(delta: float) -> Dictionary:
	var input := {
		"move_dir": 0.0,
		"jump": false,
		"jetpack": false,
		"dive": false,
		"aim_angle": _player.aim_angle,
	}

	match _state:
		State.IDLE:
			input = _idle_input(input)
		State.PURSUE:
			input = _pursue_input(input)
		State.ENGAGE:
			input = _engage_input(input, delta)
		State.RETREAT:
			input = _retreat_input(input)

	return input


func _idle_input(input: Dictionary) -> Dictionary:
	input.move_dir = _patrol_dir

	# Reverse at map edges
	if _player.global_position.x < MAP_LEFT + EDGE_DETECT_DIST:
		_patrol_dir = 1.0
	elif _player.global_position.x > MAP_RIGHT - EDGE_DETECT_DIST:
		_patrol_dir = -1.0

	# Random direction change
	if randf() < 0.01:
		_patrol_dir *= -1.0

	# Occasional jump on ground
	if randf() < 0.02 and _player.is_on_floor():
		input.jump = true

	# Aim forward
	input.aim_angle = 0.0 if _patrol_dir > 0 else PI
	return input


func _pursue_input(input: Dictionary) -> Dictionary:
	if _target == null or not is_instance_valid(_target):
		return input

	var diff := _target.global_position - _player.global_position

	# Move toward target
	if absf(diff.x) > 30.0:
		input.move_dir = signf(diff.x)

	# Jump if target is above and on floor
	if diff.y < -80.0 and _player.is_on_floor():
		input.jump = true

	# Jetpack if target is well above and we have fuel
	if diff.y < -150.0 and _player.fuel > 30.0:
		input.jetpack = true

	input.aim_angle = compute_aim(_player.global_position, _target.global_position)
	return input


func _engage_input(input: Dictionary, delta: float) -> Dictionary:
	if _target == null or not is_instance_valid(_target):
		return input

	var diff := _target.global_position - _player.global_position

	# Strafe to be harder to hit
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_dir *= -1.0
		_strafe_timer = randf_range(0.4, 1.2)
	input.move_dir = _strafe_dir

	# Evasion jumps
	if randf() < 0.03 and _player.is_on_floor():
		input.jump = true

	# Occasional dive dodge
	if randf() < 0.015:
		input.dive = true

	# Jetpack if target is above
	if diff.y < -100.0 and _player.fuel > 20.0:
		input.jetpack = true

	input.aim_angle = compute_aim(_player.global_position, _target.global_position)
	return input


func _retreat_input(input: Dictionary) -> Dictionary:
	if _target == null or not is_instance_valid(_target):
		return input

	var diff := _target.global_position - _player.global_position

	# Move away from target
	if absf(diff.x) > 10.0:
		input.move_dir = -signf(diff.x)
	else:
		input.move_dir = 1.0 if randf() > 0.5 else -1.0

	# Jump to escape
	if _player.is_on_floor():
		input.jump = true

	# Jetpack to high ground if fuel available
	if _player.fuel > 40.0 and _player.global_position.y > 250.0:
		input.jetpack = true

	# Dive for burst of speed
	if randf() < 0.04:
		input.dive = true

	input.aim_angle = compute_aim(_player.global_position, _target.global_position)
	return input


# --- Aim ---

## Compute aim angle from source to target with slight inaccuracy.
static func compute_aim(from: Vector2, to: Vector2) -> float:
	var diff := to - from
	var base_angle := atan2(diff.y, diff.x)
	return base_angle + randf_range(-AIM_INACCURACY, AIM_INACCURACY)


# --- Boundary Avoidance ---

func _apply_boundary_avoidance(input: Dictionary) -> Dictionary:
	var pos := _player.global_position
	if pos.x < MAP_LEFT + WALL_DETECT_DIST and input.move_dir < 0:
		input.move_dir = 1.0
	elif pos.x > MAP_RIGHT - WALL_DETECT_DIST and input.move_dir > 0:
		input.move_dir = -1.0
	return input


# --- Stuck Detection ---

func _update_stuck_detection(delta: float) -> void:
	_stuck_check_timer -= delta
	if _stuck_check_timer > 0.0:
		return
	_stuck_check_timer = STUCK_CHECK_INTERVAL

	if _player.global_position.distance_to(_last_position) < STUCK_THRESHOLD:
		_stuck_count += 1
		if _stuck_count >= STUCK_COUNT_LIMIT:
			_try_unstuck()
			_stuck_count = 0
	else:
		_stuck_count = 0
	_last_position = _player.global_position


func _try_unstuck() -> void:
	_patrol_dir *= -1.0
	_strafe_dir *= -1.0


# --- Firing Decision ---

func _should_fire() -> bool:
	if _fire_cooldown > 0.0:
		return false
	# Don't fire during pre-game countdown
	var game_mode := _player.get_node_or_null("../../GameMode")
	if game_mode and not game_mode.game_started:
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	if _target.has_method("is_player_dead") and _target.is_player_dead():
		return false
	# Double-check: never fire at a teammate
	var my_team: int = _player.team
	if my_team != 0:
		var target_team: int = _target.get("team") if _target.get("team") != null else 0
		if target_team == my_team:
			_target = null
			return false

	var dist := _player.global_position.distance_to(_target.global_position)

	match _state:
		State.ENGAGE:
			return dist < ENGAGE_RANGE
		State.RETREAT:
			return dist < 200.0
		State.PURSUE:
			return dist < ENGAGE_RANGE * 0.8
		_:
			return false


# --- Helpers ---

func _get_player_hp() -> int:
	if _player.health:
		return _player.health.current_hp
	return 100


func _get_target_distance() -> float:
	if _target == null or not is_instance_valid(_target):
		return INF
	return _player.global_position.distance_to(_target.global_position)
