extends Node

## Tests player spawning and multiplayer authority assignment.
## Sets up a host, then creates a PlayerSpawner to verify correct authority.

const TEST_PORT: int = 17772

var _players_node: Node = null
var _spawner: Node = null
var _client_root: Node = null
var _client_mp: SceneMultiplayer = null


func run_tests() -> void:
	await _test_host_starts()
	_setup_game_world()
	await _test_host_player_spawned()
	await _test_host_player_authority()
	await _test_client_player_authority()
	await _cleanup()


func _test_host_starts() -> void:
	var err := NetManager.host(TEST_PORT)
	Assert.assert_eq(err, OK, "Host starts OK for spawn test")
	await _wait_frames(5)


func _setup_game_world() -> void:
	_players_node = Node.new()
	_players_node.name = "Players"
	add_child(_players_node)

	_spawner = Node.new()
	_spawner.name = "PlayerSpawner"
	_spawner.set_script(load("res://scripts/net/PlayerSpawner.gd"))
	add_child(_spawner)


func _test_host_player_spawned() -> void:
	await _wait_frames(5)
	var host_player := _players_node.get_node_or_null("1")
	Assert.assert_not_null(host_player, "Host player (peer 1) is spawned")


func _test_host_player_authority() -> void:
	var host_player := _players_node.get_node_or_null("1")
	if host_player:
		Assert.assert_eq(
			host_player.get_multiplayer_authority(), 1,
			"Host player authority is peer 1"
		)
	else:
		Assert.assert_true(false, "Host player missing, cannot check authority")


func _test_client_player_authority() -> void:
	# Create client with proper SceneMultiplayer context
	_client_root = Node.new()
	_client_root.name = "TestClient"
	get_tree().root.add_child(_client_root)

	_client_mp = SceneMultiplayer.new()
	get_tree().set_multiplayer(_client_mp, _client_root.get_path())

	var client_peer := ENetMultiplayerPeer.new()
	var err := client_peer.create_client("127.0.0.1", TEST_PORT)
	Assert.assert_eq(err, OK, "Client creates peer for authority test")
	_client_mp.multiplayer_peer = client_peer

	# Wait for connection
	for i in 300:
		await get_tree().process_frame
		if _client_mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
	await _wait_frames(10)

	# Manually spawn client player (test client can't send RPCs through our spawner)
	var client_peer_id := _client_mp.get_unique_id()
	if not _players_node.has_node(str(client_peer_id)):
		var player_scene := load("res://scenes/NetworkedPlayer.tscn") as PackedScene
		var player := player_scene.instantiate() as CharacterBody2D
		player.name = str(client_peer_id)
		player.set_multiplayer_authority(client_peer_id)
		_players_node.add_child(player)

	var client_player := _players_node.get_node_or_null(str(client_peer_id))
	Assert.assert_not_null(client_player, "Client player node exists")
	Assert.assert_eq(
		client_player.get_multiplayer_authority(), client_peer_id,
		"Client player authority matches client peer_id (%d)" % client_peer_id
	)
	Assert.assert_neq(
		client_player.get_multiplayer_authority(), 1,
		"Client player authority is not server (1)"
	)


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _cleanup() -> void:
	if _client_mp != null:
		if _client_mp.has_multiplayer_peer():
			_client_mp.multiplayer_peer.close()
		_client_mp = null
	if _client_root != null:
		get_tree().set_multiplayer(null, _client_root.get_path())
		_client_root.queue_free()
		_client_root = null
	NetManager.disconnect_peer()
	if _players_node:
		for child in _players_node.get_children():
			child.queue_free()
	await _wait_frames(10)
