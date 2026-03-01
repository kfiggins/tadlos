extends Node

## Tests that the server accepts 8 players and rejects the 9th.

const TEST_PORT: int = 17775

var _clients: Array = []  # Array of {root: Node, mp: SceneMultiplayer}


func run_tests() -> void:
	await _test_host_starts()
	await _test_connect_7_clients()
	await _test_all_8_connected()
	await _test_reject_9th_connection()
	await _cleanup()


func _test_host_starts() -> void:
	var err := NetManager.host(TEST_PORT)
	Assert.assert_eq(err, OK, "Host starts for max-players test")
	await _wait_frames(5)


func _test_connect_7_clients() -> void:
	for i in 7:
		var client := _create_and_connect_client(i)
		await _wait_for_connection(client.mp)
		_clients.append(client)
		await _wait_frames(3)

	Assert.assert_eq(
		NetManager.connected_peers.size(), 7,
		"7 client peers connected"
	)


func _test_all_8_connected() -> void:
	# Host (peer 1) + 7 clients = 8 total
	var total := NetManager.connected_peers.size() + 1
	Assert.assert_eq(total, 8, "Total players is 8 (host + 7 clients)")


func _test_reject_9th_connection() -> void:
	var peers_before := NetManager.connected_peers.size()

	# Attempt 9th connection
	var client_9 := _create_and_connect_client(99)

	# Wait for connection attempt and potential rejection
	await _wait_frames(60)

	# Server should have rejected the 9th peer
	Assert.assert_eq(
		NetManager.connected_peers.size(), peers_before,
		"Peer count unchanged after 9th connection attempt (still %d)" % peers_before
	)

	# Cleanup 9th client
	if client_9.mp.has_multiplayer_peer():
		client_9.mp.multiplayer_peer.close()
	get_tree().set_multiplayer(null, client_9.root.get_path())
	client_9.root.queue_free()
	await _wait_frames(5)


func _create_and_connect_client(index: int) -> Dictionary:
	var root := Node.new()
	root.name = "TestClient_%d" % index
	get_tree().root.add_child(root)

	var mp := SceneMultiplayer.new()
	get_tree().set_multiplayer(mp, root.get_path())

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client("127.0.0.1", TEST_PORT)
	Assert.assert_eq(err, OK, "Client %d peer creation OK" % index)
	mp.multiplayer_peer = peer

	return {"root": root, "mp": mp}


func _wait_for_connection(mp: SceneMultiplayer) -> void:
	for i in 300:
		await get_tree().process_frame
		if mp.has_multiplayer_peer() and \
			mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			return
	Assert.assert_true(false, "Client connected within timeout")


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _cleanup() -> void:
	for client in _clients:
		if client.mp != null and client.mp.has_multiplayer_peer():
			client.mp.multiplayer_peer.close()
		if client.root != null:
			get_tree().set_multiplayer(null, client.root.get_path())
			client.root.queue_free()
	_clients.clear()
	NetManager.disconnect_peer()
	await _wait_frames(10)
