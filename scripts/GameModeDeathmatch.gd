class_name GameModeDeathmatch
extends Node

## Server-authoritative deathmatch game mode.
## Manages scores, respawn timers, kill tracking, and spawn point selection.
## Lives as a child of GameWorld. Exists on both server and clients —
## server does all logic, clients store replicated scores for UI.

signal kill_occurred(killer_id: int, victim_id: int)

var scores: Dictionary = {}  # {peer_id: {"kills": int, "deaths": int}}
var spawn_points: SpawnPoints = null

var _respawn_timers: Dictionary = {}  # {peer_id: float}
var _players_node: Node = null

const RESPAWN_DELAY := 3.0


func _ready() -> void:
	_players_node = get_node_or_null("../Players")
	_collect_spawn_points()


func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
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
		points.append(Vector2(400, 280))
	spawn_points = SpawnPoints.new(points)


func register_player(peer_id: int) -> void:
	if not scores.has(peer_id):
		scores[peer_id] = {"kills": 0, "deaths": 0}


func unregister_player(peer_id: int) -> void:
	scores.erase(peer_id)
	_respawn_timers.erase(peer_id)


## Called by NetworkedPlayer._on_player_died() on the server.
func on_player_killed(killer_id: int, victim_id: int) -> void:
	if not multiplayer.is_server():
		return

	register_player(killer_id)
	register_player(victim_id)

	# Don't award kill for suicide
	if killer_id != victim_id:
		scores[killer_id]["kills"] += 1
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

	kill_occurred.emit(killer_id, victim_id)


## Get a spawn position avoiding other living players.
func get_spawn_position(peer_id: int = 0) -> Vector2:
	var other_positions: Array[Vector2] = []
	if _players_node:
		for child in _players_node.get_children():
			if str(child.name) != str(peer_id):
				if not child.has_method("is_player_dead") or not child.is_player_dead():
					other_positions.append(child.position)
	if spawn_points == null:
		return Vector2(400, 280)
	return spawn_points.get_spawn_point(other_positions)


## Send current scores to a newly connected peer.
func send_scores_to_peer(peer_id: int) -> void:
	if multiplayer.is_server():
		_broadcast_scores.rpc_id(peer_id, scores)


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


func get_respawn_time_remaining(peer_id: int) -> float:
	return _respawn_timers.get(peer_id, 0.0)


func _get_player_node(peer_id: int) -> Node:
	if _players_node == null:
		return null
	return _players_node.get_node_or_null(str(peer_id))


# --- RPCs (server → clients) ---

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
func _broadcast_respawn(peer_id: int, pos_x: float, pos_y: float) -> void:
	if multiplayer.is_server():
		return
	var player := _get_player_node(peer_id)
	if player and player.has_method("on_client_respawn"):
		player.on_client_respawn(Vector2(pos_x, pos_y))
