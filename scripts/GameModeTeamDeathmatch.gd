class_name GameModeTeamDeathmatch
extends Node

## Server-authoritative team deathmatch game mode.
## Manages team assignments, per-player and team scores, respawn timers,
## kill tracking, and team-aware spawn point selection.
## Same duck-type interface as GameModeDeathmatch for interchangeability.

signal kill_occurred(killer_id: int, victim_id: int)

var scores: Dictionary = {}  # {peer_id: {"kills": int, "deaths": int}}
var team_assignments: Dictionary = {}  # {peer_id: TeamConstants.Team}
var team_scores: Dictionary = {
	TeamConstants.Team.RED: 0,
	TeamConstants.Team.BLUE: 0,
}
var spawn_points: SpawnPoints = null

var _respawn_timers: Dictionary = {}  # {peer_id: float}
var _players_node: Node = null

const RESPAWN_DELAY := TeamConstants.RESPAWN_DELAY
const COUNTDOWN_DURATION := 5.0

var game_started: bool = false
var _countdown_timer: float = COUNTDOWN_DURATION
var _last_broadcast_second: int = -1


func _ready() -> void:
	_players_node = get_node_or_null("../Players")
	_collect_spawn_points()


func _process(delta: float) -> void:
	if not _is_server():
		return

	# Pre-game countdown
	if not game_started:
		_countdown_timer -= delta
		if _countdown_timer <= 0.0:
			game_started = true
			_countdown_timer = 0.0
			_broadcast_game_started.rpc()
		else:
			var current_second := ceili(_countdown_timer)
			if current_second != _last_broadcast_second:
				_last_broadcast_second = current_second
				_broadcast_countdown.rpc(current_second)
		return

	_process_respawn_timers(delta)


func _collect_spawn_points() -> void:
	var points: Array[Vector2] = []
	var spawn_markers := get_node_or_null("../SpawnMarkers")
	if spawn_markers:
		for child in spawn_markers.get_children():
			if child is Marker2D:
				points.append(child.position)
	if points.is_empty():
		points.append(Vector2(3000, 960))
	spawn_points = SpawnPoints.new(points)


## Register a player and assign to a team.
func register_player(peer_id: int, preferred_team: int = TeamConstants.Team.NONE) -> void:
	if not scores.has(peer_id):
		scores[peer_id] = {"kills": 0, "deaths": 0}
	if not team_assignments.has(peer_id):
		if preferred_team == TeamConstants.Team.RED or preferred_team == TeamConstants.Team.BLUE:
			team_assignments[peer_id] = preferred_team
		else:
			team_assignments[peer_id] = _auto_assign_team()
	if _is_server():
		_broadcast_teams.rpc(team_assignments)


func unregister_player(peer_id: int) -> void:
	scores.erase(peer_id)
	team_assignments.erase(peer_id)
	_respawn_timers.erase(peer_id)
	if _is_server():
		_broadcast_teams.rpc(team_assignments)


## Called by NetworkedPlayer._on_player_died() on the server.
func on_player_killed(killer_id: int, victim_id: int) -> void:
	if not _is_server():
		return

	register_player(killer_id)
	register_player(victim_id)

	# Don't award kill for suicide
	if killer_id != victim_id:
		scores[killer_id]["kills"] += 1
		# Award team score for cross-team kills only
		if not is_friendly(killer_id, victim_id):
			var killer_team: int = team_assignments.get(killer_id, TeamConstants.Team.NONE)
			if team_scores.has(killer_team):
				team_scores[killer_team] += 1
	scores[victim_id]["deaths"] += 1

	# Mark player dead on server
	var victim_node := _get_player_node(victim_id)
	if victim_node and victim_node.has_method("set_dead"):
		victim_node.set_dead(true, killer_id)

	# Start respawn timer
	_respawn_timers[victim_id] = RESPAWN_DELAY

	# Broadcast to all clients
	_broadcast_kill.rpc(killer_id, victim_id)
	_broadcast_scores.rpc(scores)
	_broadcast_team_scores.rpc(team_scores)

	kill_occurred.emit(killer_id, victim_id)


## Check if two players are on the same team.
func is_friendly(peer_a: int, peer_b: int) -> bool:
	var team_a: int = team_assignments.get(peer_a, TeamConstants.Team.NONE)
	var team_b: int = team_assignments.get(peer_b, TeamConstants.Team.NONE)
	if team_a == TeamConstants.Team.NONE or team_b == TeamConstants.Team.NONE:
		return false
	return team_a == team_b


## Get team for a player.
func get_team(peer_id: int) -> int:
	return team_assignments.get(peer_id, TeamConstants.Team.NONE)


## Get a team-aware spawn position, avoiding enemy positions.
func get_spawn_position(peer_id: int = 0) -> Vector2:
	var my_team: int = team_assignments.get(peer_id, TeamConstants.Team.NONE)
	var team_side := TeamConstants.get_team_side(my_team)

	# Only avoid enemy positions (teammates are safe to spawn near)
	var enemy_positions: Array[Vector2] = []
	if _players_node:
		for child in _players_node.get_children():
			if str(child.name) != str(peer_id):
				if not child.has_method("is_player_dead") or not child.is_player_dead():
					var child_team: int = team_assignments.get(int(str(child.name)), TeamConstants.Team.NONE)
					if child_team != my_team or my_team == TeamConstants.Team.NONE:
						enemy_positions.append(child.position)

	if spawn_points == null:
		return Vector2(3000, 960)
	return spawn_points.get_team_spawn_point(team_side, enemy_positions, TeamConstants.MAP_MIDPOINT_X)


## Change a player's team. Server-only.
func change_team(peer_id: int, new_team: int) -> void:
	if not multiplayer.is_server():
		return
	if new_team != TeamConstants.Team.RED and new_team != TeamConstants.Team.BLUE:
		return
	team_assignments[peer_id] = new_team
	_broadcast_teams.rpc(team_assignments)
	# Update the player's visual
	var player := _get_player_node(peer_id)
	if player and player.has_method("set_team_visual"):
		player.set_team_visual(new_team)


## Send current scores and teams to a newly connected peer.
func send_scores_to_peer(peer_id: int) -> void:
	if multiplayer.is_server():
		_broadcast_scores.rpc_id(peer_id, scores)
		_broadcast_team_scores.rpc_id(peer_id, team_scores)


## Send team assignments to a newly connected peer.
func send_teams_to_peer(peer_id: int) -> void:
	if multiplayer.is_server():
		_broadcast_teams.rpc_id(peer_id, team_assignments)


## Send countdown/game state to a newly connected peer.
func send_game_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if game_started:
		_broadcast_game_started.rpc_id(peer_id)
	else:
		_broadcast_countdown.rpc_id(peer_id, ceili(_countdown_timer))


## Skip countdown immediately (for tests).
func skip_countdown() -> void:
	game_started = true
	_countdown_timer = 0.0


func get_respawn_time_remaining(peer_id: int) -> float:
	return _respawn_timers.get(peer_id, 0.0)


# --- Private ---

## Safe server check that works even outside the scene tree (for tests).
func _is_server() -> bool:
	return multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _auto_assign_team() -> int:
	var red_count := 0
	var blue_count := 0
	for pid in team_assignments:
		if team_assignments[pid] == TeamConstants.Team.RED:
			red_count += 1
		elif team_assignments[pid] == TeamConstants.Team.BLUE:
			blue_count += 1
	if red_count <= blue_count:
		return TeamConstants.Team.RED
	return TeamConstants.Team.BLUE


func _process_respawn_timers(delta: float) -> void:
	var to_respawn: Array[int] = []
	for peer_id in _respawn_timers:
		_respawn_timers[peer_id] -= delta
		if _respawn_timers[peer_id] <= 0.0:
			to_respawn.append(peer_id)
	for peer_id in to_respawn:
		_respawn_timers.erase(peer_id)
		_respawn_player(peer_id)


func _respawn_player(peer_id: int) -> void:
	var player := _get_player_node(peer_id)
	if player == null:
		return

	var spawn_pos := get_spawn_position(peer_id)

	if player.has_method("respawn"):
		player.respawn(spawn_pos)

	_broadcast_respawn.rpc(peer_id, spawn_pos.x, spawn_pos.y)


func _get_player_node(peer_id: int) -> Node:
	if _players_node == null:
		return null
	return _players_node.get_node_or_null(str(peer_id))


# --- RPCs (server -> clients) ---

@rpc("authority", "reliable")
func _broadcast_kill(killer_id: int, victim_id: int) -> void:
	if multiplayer.is_server():
		return
	kill_occurred.emit(killer_id, victim_id)


@rpc("authority", "reliable")
func _broadcast_scores(new_scores: Dictionary) -> void:
	if multiplayer.is_server():
		return
	scores = new_scores


@rpc("authority", "reliable")
func _broadcast_teams(assignments: Dictionary) -> void:
	if multiplayer.is_server():
		return
	team_assignments = assignments
	_apply_team_colors()


@rpc("authority", "reliable")
func _broadcast_team_scores(t_scores: Dictionary) -> void:
	if multiplayer.is_server():
		return
	team_scores = t_scores


@rpc("authority", "reliable")
func _broadcast_respawn(peer_id: int, pos_x: float, pos_y: float) -> void:
	if multiplayer.is_server():
		return
	var player := _get_player_node(peer_id)
	if player and player.has_method("on_client_respawn"):
		player.on_client_respawn(Vector2(pos_x, pos_y))


@rpc("authority", "reliable")
func _broadcast_countdown(seconds_remaining: int) -> void:
	if multiplayer.is_server():
		return
	_countdown_timer = float(seconds_remaining)
	game_started = false


@rpc("authority", "reliable")
func _broadcast_game_started() -> void:
	if multiplayer.is_server():
		return
	game_started = true
	_countdown_timer = 0.0


## Client -> Server: request to change team.
@rpc("any_peer", "reliable")
func request_team_change(new_team: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	change_team(peer_id, new_team)


## Apply team colors to all players on the client.
func _apply_team_colors() -> void:
	if _players_node == null:
		return
	for child in _players_node.get_children():
		var pid := int(str(child.name))
		if team_assignments.has(pid) and child.has_method("set_team_visual"):
			child.set_team_visual(team_assignments[pid])
