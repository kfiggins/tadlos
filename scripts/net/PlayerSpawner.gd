extends Node

## Handles spawning and despawning of networked player nodes.
## Lives as a child of GameWorld. Server-authoritative spawn decisions,
## with RPCs to replicate spawns/despawns to clients.

var _player_scene: PackedScene = preload("res://scenes/NetworkedPlayer.tscn")
var _bot_ais: Array[Node] = []
var _ffa_color_assignments: Dictionary = {}  # {peer_id: color_index}
var _next_ffa_color: int = 0

@onready var _players: Node = $"../Players"


func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	NetManager.player_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		# Defer server init so GameMode node exists (created in GameWorld._ready())
		call_deferred("_server_init")
	else:
		_server_client_ready.rpc_id(1, NetManager.requested_team)


func _server_init() -> void:
	var game_mode := get_node_or_null("../GameMode")
	if game_mode and game_mode.has_method("register_player"):
		# Host registers with their preferred team (TDM only)
		if game_mode is GameModeTeamDeathmatch:
			game_mode.register_player(1, NetManager.requested_team)
		else:
			game_mode.register_player(1)
	var pos := _get_spawn_position(1)
	_spawn_player(1, pos)
	_apply_player_color(1)
	_spawn_bots()


func _exit_tree() -> void:
	for bot_ai in _bot_ais:
		if is_instance_valid(bot_ai):
			bot_ai.queue_free()
	_bot_ais.clear()
	if NetManager.player_disconnected.is_connected(_on_peer_disconnected):
		NetManager.player_disconnected.disconnect(_on_peer_disconnected)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		# Clean up disconnected player's bullets
		var bullets_node := get_node_or_null("../Bullets")
		if bullets_node:
			for bullet in bullets_node.get_children():
				if bullet is CharacterBody2D and bullet.owner_peer_id == peer_id:
					bullet.queue_free()
		var game_mode := get_node_or_null("../GameMode")
		if game_mode:
			game_mode.unregister_player(peer_id)
		_ffa_color_assignments.erase(peer_id)
		_despawn_player(peer_id)
		_client_despawn_player.rpc(peer_id)
	elif peer_id == 1:
		# Server disconnected — clean up all players
		for child in _players.get_children():
			child.queue_free()


## Client → Server: client's GameWorld is loaded and ready.
@rpc("any_peer", "reliable")
func _server_client_ready(preferred_team: int = 0) -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	Debug.log("net", "Client %d ready, spawning player" % peer_id)

	# Send all existing players to the new client (with team/color info)
	for child in _players.get_children():
		var existing_id := int(str(child.name))
		var existing_team: int = child.get("team") if child.get("team") != null else 0
		var existing_color: int = _ffa_color_assignments.get(existing_id, -1)
		_client_spawn_player.rpc_id(peer_id, existing_id, child.position, existing_team, existing_color)

	# Register player in game mode (before spawning so team is assigned for spawn position)
	var game_mode := get_node_or_null("../GameMode")
	if game_mode:
		if game_mode is GameModeTeamDeathmatch:
			game_mode.register_player(peer_id, preferred_team)
		else:
			game_mode.register_player(peer_id)
		game_mode.send_scores_to_peer(peer_id)
		game_mode.send_game_state_to_peer(peer_id)
		if game_mode.has_method("send_teams_to_peer"):
			game_mode.send_teams_to_peer(peer_id)

	# Spawn the new player on the server
	_spawn_player(peer_id, _get_spawn_position(peer_id))
	_apply_player_color(peer_id)

	# Tell ALL clients (including the new one) about the new player
	var new_player := _players.get_node_or_null(str(peer_id))
	if new_player:
		var team: int = new_player.get("team") if new_player.get("team") != null else 0
		var color_idx: int = _ffa_color_assignments.get(peer_id, -1)
		_client_spawn_player.rpc(peer_id, new_player.position, team, color_idx)


## Server → Clients: spawn a player node.
@rpc("any_peer", "reliable")
func _client_spawn_player(peer_id: int, pos: Vector2, team: int = 0, color_index: int = -1) -> void:
	if multiplayer.is_server():
		return
	# Only accept from server
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1:
		return
	if not _players.has_node(str(peer_id)):
		_spawn_player(peer_id, pos)
		var player := _players.get_node_or_null(str(peer_id))
		if player:
			if team != 0:
				player.team = team
				if player.has_method("set_team_visual"):
					player.set_team_visual(team)
			elif color_index >= 0 and player.has_method("set_ffa_color"):
				player.set_ffa_color(color_index)


## Server → Clients: despawn a player node.
@rpc("any_peer", "reliable")
func _client_despawn_player(peer_id: int) -> void:
	if multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1:
		return
	_despawn_player(peer_id)


func _get_spawn_position(peer_id: int) -> Vector2:
	var game_mode := get_node_or_null("../GameMode")
	if game_mode:
		return game_mode.get_spawn_position(peer_id)
	return Vector2(3000, 960)


func _spawn_player(peer_id: int, pos: Vector2 = Vector2(3000, 960)) -> void:
	if _players == null:
		return
	if _players.has_node(str(peer_id)):
		return

	var player := _player_scene.instantiate() as CharacterBody2D
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.position = pos
	_players.add_child(player)
	Debug.log("net", "Spawned player %d at %s" % [peer_id, pos])


func _despawn_player(peer_id: int) -> void:
	var node := _players.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()
		Debug.log("net", "Despawned player %d" % peer_id)


func get_player_count() -> int:
	return _players.get_child_count()


func _spawn_bots() -> void:
	var bot_count: int = clampi(NetManager.requested_bot_count, 0, BotConstants.MAX_BOTS)
	for i in bot_count:
		var peer_id := BotConstants.BOT_PEER_ID_START + i
		var pos := _get_spawn_position(peer_id)
		_spawn_bot_player(peer_id, pos)


func _spawn_bot_player(peer_id: int, pos: Vector2) -> void:
	if _players.has_node(str(peer_id)):
		return

	var player := _player_scene.instantiate() as CharacterBody2D
	player.name = str(peer_id)
	player.is_bot = true  # Set before add_child so _ready() can check it
	player.set_multiplayer_authority(1)  # Server controls bots
	player.position = pos
	_players.add_child(player)

	var game_mode := get_node_or_null("../GameMode")
	if game_mode:
		game_mode.register_player(peer_id)  # Bots always auto-assign
	_apply_player_color(peer_id)

	var bot_ai := BotAI.new()
	bot_ai.name = "BotAI_%d" % peer_id
	add_child(bot_ai)
	bot_ai.setup(player)
	_bot_ais.append(bot_ai)

	Debug.log("net", "Spawned bot %d at %s" % [peer_id, pos])


## Apply player color based on game mode (team colors for TDM, unique colors for FFA).
func _apply_player_color(peer_id: int) -> void:
	var player := _players.get_node_or_null(str(peer_id))
	if player == null:
		return
	var game_mode := get_node_or_null("../GameMode")
	if game_mode and game_mode.has_method("get_team"):
		# TDM mode — use team colors
		var team: int = game_mode.get_team(peer_id)
		if team != TeamConstants.Team.NONE:
			player.team = team
			if player.has_method("set_team_visual"):
				player.set_team_visual(team)
	else:
		# FFA mode — assign unique color
		if not _ffa_color_assignments.has(peer_id):
			_ffa_color_assignments[peer_id] = _next_ffa_color
			_next_ffa_color += 1
		var idx: int = _ffa_color_assignments[peer_id]
		if player.has_method("set_ffa_color"):
			player.set_ffa_color(idx)
