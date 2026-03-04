extends Node

## Tests bot spawning integration: correct count, peer IDs, authority, game mode registration.
## Requires hosting a server and loading a minimal GameWorld-like structure.

const TEST_PORT: int = 17778

var _players_node: Node = null
var _game_mode: Node = null
var _spawner: Node = null


func run_tests() -> void:
	await _test_host_with_bots()
	await _test_bot_count()
	await _test_bot_peer_ids()
	await _test_bot_authority()
	await _test_bot_is_bot_flag()
	await _test_bot_registered_in_game_mode()
	await _test_host_player_unaffected()
	await _cleanup()


func _test_host_with_bots() -> void:
	NetManager.requested_bot_count = 3
	var err := NetManager.host(TEST_PORT)
	Assert.assert_eq(err, OK, "Host starts OK for bot spawn test")
	await _wait_frames(5)

	# Build minimal GameWorld-like structure
	_players_node = Node.new()
	_players_node.name = "Players"
	add_child(_players_node)

	# Add SpawnMarkers
	var spawn_markers := Node2D.new()
	spawn_markers.name = "SpawnMarkers"
	add_child(spawn_markers)
	for i in 6:
		var marker := Marker2D.new()
		marker.name = "Spawn%d" % (i + 1)
		marker.position = Vector2(200 + i * 100, 280)
		spawn_markers.add_child(marker)

	# Add GameMode (FFA deathmatch)
	_game_mode = Node.new()
	_game_mode.name = "GameMode"
	_game_mode.set_script(load("res://scripts/GameModeDeathmatch.gd"))
	add_child(_game_mode)

	# Skip countdown for test
	_game_mode.skip_countdown()

	# Add PlayerSpawner (this triggers _ready which spawns host + bots)
	_spawner = Node.new()
	_spawner.name = "PlayerSpawner"
	_spawner.set_script(load("res://scripts/net/PlayerSpawner.gd"))
	add_child(_spawner)

	await _wait_frames(10)


func _test_bot_count() -> void:
	# 1 host + 3 bots = 4 players
	var count := _players_node.get_child_count()
	Assert.assert_eq(count, 4, "4 players total (1 host + 3 bots), got %d" % count)


func _test_bot_peer_ids() -> void:
	for i in 3:
		var peer_id := BotConstants.BOT_PEER_ID_START + i
		var node := _players_node.get_node_or_null(str(peer_id))
		Assert.assert_not_null(node, "Bot %d exists in Players node" % peer_id)


func _test_bot_authority() -> void:
	for i in 3:
		var peer_id := BotConstants.BOT_PEER_ID_START + i
		var node := _players_node.get_node_or_null(str(peer_id))
		if node:
			Assert.assert_eq(
				node.get_multiplayer_authority(), 1,
				"Bot %d authority is server (1)" % peer_id
			)


func _test_bot_is_bot_flag() -> void:
	for i in 3:
		var peer_id := BotConstants.BOT_PEER_ID_START + i
		var node := _players_node.get_node_or_null(str(peer_id))
		if node:
			Assert.assert_true(node.is_bot, "Bot %d has is_bot=true" % peer_id)


func _test_bot_registered_in_game_mode() -> void:
	if _game_mode == null:
		Assert.assert_true(false, "Game mode is null")
		return
	for i in 3:
		var peer_id := BotConstants.BOT_PEER_ID_START + i
		Assert.assert_true(
			_game_mode.scores.has(peer_id),
			"Bot %d registered in game mode scores" % peer_id
		)


func _test_host_player_unaffected() -> void:
	var host_node := _players_node.get_node_or_null("1")
	Assert.assert_not_null(host_node, "Host player (peer 1) still exists")
	if host_node:
		Assert.assert_eq(
			host_node.get_multiplayer_authority(), 1,
			"Host player authority is 1"
		)
		Assert.assert_false(host_node.is_bot, "Host player is_bot is false")


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _cleanup() -> void:
	NetManager.disconnect_peer()
	for child in _players_node.get_children():
		child.queue_free()
	await _wait_frames(10)
