extends Node

## Handles spawning and despawning of networked player nodes.
## Lives as a child of GameWorld. Server-authoritative spawn decisions,
## with RPCs to replicate spawns/despawns to clients.

var _player_scene: PackedScene = preload("res://scenes/NetworkedPlayer.tscn")

@onready var _players: Node = $"../Players"


func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	NetManager.player_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		var pos := _get_spawn_position(1)
		_spawn_player(1, pos)
		var game_mode := get_node_or_null("../GameModeDeathmatch")
		if game_mode:
			game_mode.register_player(1)
	else:
		_server_client_ready.rpc_id(1)


func _exit_tree() -> void:
	if NetManager.player_disconnected.is_connected(_on_peer_disconnected):
		NetManager.player_disconnected.disconnect(_on_peer_disconnected)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		var game_mode := get_node_or_null("../GameModeDeathmatch")
		if game_mode:
			game_mode.unregister_player(peer_id)
		_despawn_player(peer_id)
		_client_despawn_player.rpc(peer_id)
	elif peer_id == 1:
		# Server disconnected — clean up all players
		for child in _players.get_children():
			child.queue_free()


## Client → Server: client's GameWorld is loaded and ready.
@rpc("any_peer", "reliable")
func _server_client_ready() -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	Debug.log("net", "Client %d ready, spawning player" % peer_id)

	# Send all existing players to the new client
	for child in _players.get_children():
		var existing_id := int(str(child.name))
		_client_spawn_player.rpc_id(peer_id, existing_id, child.position)

	# Spawn the new player on the server
	_spawn_player(peer_id, _get_spawn_position(peer_id))

	# Register player in game mode
	var game_mode := get_node_or_null("../GameModeDeathmatch")
	if game_mode:
		game_mode.register_player(peer_id)
		game_mode.send_scores_to_peer(peer_id)

	# Tell ALL clients (including the new one) about the new player
	var new_player := _players.get_node_or_null(str(peer_id))
	if new_player:
		_client_spawn_player.rpc(peer_id, new_player.position)


## Server → Clients: spawn a player node.
@rpc("any_peer", "reliable")
func _client_spawn_player(peer_id: int, pos: Vector2) -> void:
	if multiplayer.is_server():
		return
	# Only accept from server
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1:
		return
	if not _players.has_node(str(peer_id)):
		_spawn_player(peer_id, pos)


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
	var game_mode := get_node_or_null("../GameModeDeathmatch")
	if game_mode:
		return game_mode.get_spawn_position(peer_id)
	return Vector2(400, 280)


func _spawn_player(peer_id: int, pos: Vector2 = Vector2(400, 280)) -> void:
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
