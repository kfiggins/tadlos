class_name SoakTestBot
extends Node

## Simple bot AI for soak testing. Controls a NetworkedPlayer instance
## on the server by injecting synthetic inputs.

var _player: CharacterBody2D = null
var _move_timer: float = 0.0
var _current_move_dir: float = 0.0
var _shoot_timer: float = 0.0
var _aim_angle: float = 0.0


func setup(player_node: CharacterBody2D) -> void:
	_player = player_node
	_player.is_bot = true
	_pick_new_direction()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	_move_timer -= delta
	if _move_timer <= 0.0:
		_pick_new_direction()

	_shoot_timer -= delta
	_update_aim()

	var input := {
		"move_dir": _current_move_dir,
		"jump": randf() < 0.02,
		"jetpack": randf() < 0.01,
		"dive": false,
		"aim_angle": _aim_angle,
	}
	_player.set_bot_input(input)

	if _shoot_timer <= 0.0:
		_player._bot_wants_fire = true
		_shoot_timer = randf_range(0.3, 1.0)


func _pick_new_direction() -> void:
	_current_move_dir = [-1.0, 0.0, 1.0][randi() % 3]
	_move_timer = randf_range(1.0, 3.0)


func _update_aim() -> void:
	if _player == null:
		return
	var players_node := _player.get_node_or_null("../../Players")
	if players_node == null:
		return
	var nearest_dist := INF
	var nearest_pos := _player.global_position + Vector2(100, 0)
	for child in players_node.get_children():
		if child == _player:
			continue
		if child.has_method("is_player_dead") and child.is_player_dead():
			continue
		var d := _player.global_position.distance_to(child.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_pos = child.global_position
	_aim_angle = (_nearest_pos_to_angle(nearest_pos))


func _nearest_pos_to_angle(target: Vector2) -> float:
	var diff := target - _player.global_position
	return atan2(diff.y, diff.x)
