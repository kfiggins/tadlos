extends Node

## Autoload singleton managing network state.
## Handles hosting, joining, and tracking connected peers.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()

var is_host: bool = false
var local_peer_id: int = 0
var connected_peers: Array[int] = []


func host(port: int = NetConstants.DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, NetConstants.MAX_PLAYERS)
	if err != OK:
		Debug.log("net", "Failed to create server on port %d: %s" % [port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	is_host = true
	local_peer_id = 1

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	Debug.log("net", "Hosting on port %d" % port)
	return OK


func join(ip: String, port: int = NetConstants.DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		Debug.log("net", "Failed to create client for %s:%d: %s" % [ip, port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	is_host = false

	multiplayer.connected_to_server.connect(_on_connection_succeeded)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	Debug.log("net", "Joining %s:%d" % [ip, port])
	return OK


func disconnect_peer() -> void:
	# Disconnect signals before closing peer to avoid callbacks during teardown
	_disconnect_signal(multiplayer.peer_connected, _on_peer_connected)
	_disconnect_signal(multiplayer.peer_disconnected, _on_peer_disconnected)
	_disconnect_signal(multiplayer.connected_to_server, _on_connection_succeeded)
	_disconnect_signal(multiplayer.connection_failed, _on_connection_failed)
	_disconnect_signal(multiplayer.server_disconnected, _on_server_disconnected)

	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_reset()
	Debug.log("net", "Disconnected")


func _reset() -> void:
	is_host = false
	local_peer_id = 0
	connected_peers.clear()


func _disconnect_signal(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_peer_connected(peer_id: int) -> void:
	if is_host and connected_peers.size() >= NetConstants.MAX_PLAYERS - 1:
		Debug.log("net", "Rejecting peer %d: server full" % peer_id)
		var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if peer:
			peer.disconnect_peer(peer_id)
		return

	if peer_id not in connected_peers:
		connected_peers.append(peer_id)
	Debug.log("net", "Peer connected: %d (total: %d)" % [peer_id, connected_peers.size()])
	player_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	connected_peers.erase(peer_id)
	Debug.log("net", "Peer disconnected: %d (total: %d)" % [peer_id, connected_peers.size()])
	player_disconnected.emit(peer_id)


func _on_connection_succeeded() -> void:
	local_peer_id = multiplayer.get_unique_id()
	Debug.log("net", "Connected to server, peer_id: %d" % local_peer_id)
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	Debug.log("net", "Connection failed")
	_reset()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	Debug.log("net", "Server disconnected")
	_reset()
	server_disconnected.emit()
