extends Node

## Tests host/join networking: server creation, client connection,
## player count tracking, and host player spawning.
## Uses real ENet peers on localhost with proper SceneMultiplayer contexts.

const TEST_PORT: int = 17771

var _client_root: Node = null
var _client_mp: SceneMultiplayer = null


func run_tests() -> void:
	await _test_host_creates_server()
	await _test_host_state()
	await _test_client_connects_to_host()
	await _test_player_count_after_connect()
	await _test_host_player_is_peer_1()
	await _cleanup()


func _test_host_creates_server() -> void:
	var err := NetManager.host(TEST_PORT)
	Assert.assert_eq(err, OK, "Host returns OK")
	await _wait_frames(5)


func _test_host_state() -> void:
	Assert.assert_true(NetManager.is_host, "is_host is true after hosting")
	Assert.assert_eq(NetManager.local_peer_id, 1, "Host peer_id is 1")


func _test_client_connects_to_host() -> void:
	# Create a proper client multiplayer context so SceneTree polls both sides
	_client_root = Node.new()
	_client_root.name = "TestClient"
	get_tree().root.add_child(_client_root)

	_client_mp = SceneMultiplayer.new()
	get_tree().set_multiplayer(_client_mp, _client_root.get_path())

	var client_peer := ENetMultiplayerPeer.new()
	var err := client_peer.create_client("127.0.0.1", TEST_PORT)
	Assert.assert_eq(err, OK, "Client peer creation returns OK")

	_client_mp.multiplayer_peer = client_peer

	# Wait for connection - both sides now polled by SceneTree
	var connected := false
	for i in 300:
		await get_tree().process_frame
		if _client_mp.has_multiplayer_peer() and \
			_client_mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			connected = true
			break

	Assert.assert_true(connected, "Client connects to host within timeout")
	# Extra frames for server to process the event
	await _wait_frames(5)


func _test_player_count_after_connect() -> void:
	await _wait_frames(10)

	Assert.assert_true(
		multiplayer.get_peers().size() >= 1,
		"multiplayer.get_peers() has at least 1 peer (got %d)" % multiplayer.get_peers().size()
	)
	Assert.assert_true(
		NetManager.connected_peers.size() >= 1,
		"NetManager tracks at least 1 connected peer (got %d)" % NetManager.connected_peers.size()
	)


func _test_host_player_is_peer_1() -> void:
	Assert.assert_eq(NetManager.local_peer_id, 1, "Host local_peer_id remains 1")


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
	await _wait_frames(10)
