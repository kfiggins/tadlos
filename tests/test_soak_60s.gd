extends Node

## Soak test: runs 8 bots for a short duration, monitoring stability.
## Uses 10s for TestRunner (full 60s via standalone SoakTest.tscn scene).

const TEST_PORT: int = 17776
const SOAK_DURATION := 10.0
const BOT_COUNT := 8

var _game_world: Node2D = null
var _bots: Array = []
var _elapsed: float = 0.0
var _done: bool = false
var _max_bullets_seen: int = 0
var _start_node_count: int = 0
var _start_mem: int = 0
var _game_world_scene: PackedScene = preload("res://scenes/GameWorld.tscn")
var _player_scene: PackedScene = preload("res://scenes/NetworkedPlayer.tscn")


func run_tests() -> void:
	await _test_soak_run()


func _test_soak_run() -> void:
	# Host server
	var err := NetManager.host(TEST_PORT)
	Assert.assert_eq(err, OK, "Soak test host starts")
	await _wait_frames(5)

	# Load game world
	_game_world = _game_world_scene.instantiate()
	add_child(_game_world)
	await _wait_frames(5)

	# Remove the auto-spawned host player
	var players_node := _game_world.get_node("Players")
	for child in players_node.get_children():
		child.queue_free()
	await _wait_frames(3)

	# Spawn bot players
	var spawn_points := SpawnPoints.new()
	for marker in _game_world.get_node("SpawnMarkers").get_children():
		spawn_points.add_point(marker.position)

	for i in BOT_COUNT:
		var peer_id := i + 200
		var pos := spawn_points.get_spawn_point()
		var player := _player_scene.instantiate() as CharacterBody2D
		player.name = str(peer_id)
		player.set_multiplayer_authority(1)
		player.position = pos
		players_node.add_child(player)
		player.is_bot = true

		var game_mode := _game_world.get_node_or_null("GameModeDeathmatch")
		if game_mode:
			game_mode.register_player(peer_id)

		var bot := SoakTestBot.new()
		bot.name = "Bot_%d" % peer_id
		add_child(bot)
		bot.setup(player)
		_bots.append(bot)

	await _wait_frames(3)

	_start_node_count = _count_scene_nodes()
	_start_mem = OS.get_static_memory_usage()

	# Run the soak
	_elapsed = 0.0
	while _elapsed < SOAK_DURATION:
		await get_tree().process_frame
		_elapsed += get_process_delta_time()

		# Track max bullets
		var bullets_node := _game_world.get_node_or_null("Bullets")
		if bullets_node:
			var count := bullets_node.get_child_count()
			if count > _max_bullets_seen:
				_max_bullets_seen = count

	# Assertions
	Assert.assert_true(
		_max_bullets_seen <= NetConstants.MAX_BULLETS_TOTAL,
		"Max bullets seen (%d) within total cap (%d)" % [_max_bullets_seen, NetConstants.MAX_BULLETS_TOTAL]
	)

	var end_node_count := _count_scene_nodes()
	var node_growth := end_node_count - _start_node_count
	Assert.assert_lt(
		node_growth, 200,
		"Node growth bounded (%d new nodes)" % node_growth
	)

	var end_mem := OS.get_static_memory_usage()
	var mem_growth_mb := float(end_mem - _start_mem) / 1048576.0
	Assert.assert_lt(
		mem_growth_mb, 50.0,
		"Memory growth bounded (%.1f MB)" % mem_growth_mb
	)

	# Verify players still alive
	var players_alive := 0
	var players := _game_world.get_node("Players")
	for child in players.get_children():
		if is_instance_valid(child):
			players_alive += 1
	Assert.assert_eq(
		players_alive, BOT_COUNT,
		"All %d bot players still present" % BOT_COUNT
	)

	# Cleanup
	for bot in _bots:
		bot.queue_free()
	_bots.clear()
	_game_world.queue_free()
	_game_world = null
	NetManager.disconnect_peer()
	await _wait_frames(10)


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _count_scene_nodes() -> int:
	return _count_recursive(get_tree().root)


func _count_recursive(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_recursive(child)
	return count
