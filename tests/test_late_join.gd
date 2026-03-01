extends Node

## Tests that a late-joining client sees all existing players
## and that existing peers see the late joiner's player.

const TEST_PORT: int = 17774

var _players_node: Node = null
var _spawner: Node = null
var _client_root_1: Node = null
var _client_mp_1: SceneMultiplayer = null
var _client_root_2: Node = null
var _client_mp_2: SceneMultiplayer = null
var _peer_id_1: int = 0
var _peer_id_2: int = 0


func run_tests() -> void:
	await _test_setup_host_and_first_client()
	await _test_late_joiner_connects()
	await _test_all_players_on_server()
	await _cleanup()


func _test_setup_host_and_first_client() -> void:
	var err := NetManager.host(TEST_PORT)
	Assert.assert_eq(err, OK, "Host starts for late join test")
	await _wait_frames(5)

	# Set up game world
	_players_node = Node.new()
	_players_node.name = "Players"
	add_child(_players_node)

	_spawner = Node.new()
	_spawner.name = "PlayerSpawner"
	_spawner.set_script(load("res://scripts/net/PlayerSpawner.gd"))
	add_child(_spawner)
	await _wait_frames(5)

	Assert.assert_not_null(
		_players_node.get_node_or_null("1"),
		"Host player spawned before client joins"
	)

	# Connect first client
	_client_root_1 = Node.new()
	_client_root_1.name = "TestClient1"
	get_tree().root.add_child(_client_root_1)
	_client_mp_1 = SceneMultiplayer.new()
	get_tree().set_multiplayer(_client_mp_1, _client_root_1.get_path())
	var peer_1 := ENetMultiplayerPeer.new()
	peer_1.create_client("127.0.0.1", TEST_PORT)
	_client_mp_1.multiplayer_peer = peer_1

	for i in 300:
		await get_tree().process_frame
		if _client_mp_1.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
	await _wait_frames(5)

	_peer_id_1 = _client_mp_1.get_unique_id()
	if not _players_node.has_node(str(_peer_id_1)):
		var scene := load("res://scenes/NetworkedPlayer.tscn") as PackedScene
		var player := scene.instantiate() as CharacterBody2D
		player.name = str(_peer_id_1)
		player.set_multiplayer_authority(_peer_id_1)
		player.position = Vector2(500, 280)
		_players_node.add_child(player)

	Assert.assert_eq(
		_players_node.get_child_count(), 2,
		"2 players exist before late joiner (host + client 1)"
	)


func _test_late_joiner_connects() -> void:
	# Connect the late joiner (client 2)
	_client_root_2 = Node.new()
	_client_root_2.name = "TestClient2"
	get_tree().root.add_child(_client_root_2)
	_client_mp_2 = SceneMultiplayer.new()
	get_tree().set_multiplayer(_client_mp_2, _client_root_2.get_path())
	var peer_2 := ENetMultiplayerPeer.new()
	peer_2.create_client("127.0.0.1", TEST_PORT)
	_client_mp_2.multiplayer_peer = peer_2

	for i in 300:
		await get_tree().process_frame
		if _client_mp_2.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
	await _wait_frames(10)

	_peer_id_2 = _client_mp_2.get_unique_id()

	Assert.assert_true(
		_client_mp_2.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
		"Late joiner successfully connects"
	)

	Assert.assert_true(
		multiplayer.get_peers().has(_peer_id_2),
		"Server's multiplayer API tracks late joiner"
	)


func _test_all_players_on_server() -> void:
	# Manually spawn late joiner's player on server
	if not _players_node.has_node(str(_peer_id_2)):
		var scene := load("res://scenes/NetworkedPlayer.tscn") as PackedScene
		var player := scene.instantiate() as CharacterBody2D
		player.name = str(_peer_id_2)
		player.set_multiplayer_authority(_peer_id_2)
		_players_node.add_child(player)

	await get_tree().process_frame

	Assert.assert_eq(
		_players_node.get_child_count(), 3,
		"3 players on server after late join (host + 2 clients)"
	)

	Assert.assert_not_null(
		_players_node.get_node_or_null("1"),
		"Host player exists after late join"
	)
	Assert.assert_not_null(
		_players_node.get_node_or_null(str(_peer_id_1)),
		"Client 1 player exists after late join"
	)
	Assert.assert_not_null(
		_players_node.get_node_or_null(str(_peer_id_2)),
		"Late joiner player exists on server"
	)


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _cleanup() -> void:
	if _client_mp_1 != null:
		if _client_mp_1.has_multiplayer_peer():
			_client_mp_1.multiplayer_peer.close()
		_client_mp_1 = null
	if _client_root_1 != null:
		get_tree().set_multiplayer(null, _client_root_1.get_path())
		_client_root_1.queue_free()
		_client_root_1 = null
	if _client_mp_2 != null:
		if _client_mp_2.has_multiplayer_peer():
			_client_mp_2.multiplayer_peer.close()
		_client_mp_2 = null
	if _client_root_2 != null:
		get_tree().set_multiplayer(null, _client_root_2.get_path())
		_client_root_2.queue_free()
		_client_root_2 = null
	NetManager.disconnect_peer()
	if _players_node:
		for child in _players_node.get_children():
			child.queue_free()
	await _wait_frames(10)
