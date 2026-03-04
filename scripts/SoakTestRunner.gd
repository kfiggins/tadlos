extends Node

## Soak test orchestrator. Hosts a server, spawns 8 bot players in a GameWorld,
## and runs for a configurable duration monitoring stability.

const SOAK_DURATION := 60.0
const BOT_COUNT := 8
const SOAK_PORT := 17777

var _game_world: Node2D = null
var _bots: Array[Node] = []
var _elapsed: float = 0.0
var _start_node_count: int = 0
var _start_mem: int = 0
var _max_bullets_seen: int = 0
var _player_scene: PackedScene = preload("res://scenes/NetworkedPlayer.tscn")
var _game_world_scene: PackedScene = preload("res://scenes/GameWorld.tscn")


func _ready() -> void:
	_start_mem = OS.get_static_memory_usage()

	# Host server
	var err := NetManager.host(SOAK_PORT)
	if err != OK:
		print("[SOAK] Failed to host: %s" % error_string(err))
		get_tree().quit(1)
		return

	# Load game world (but prevent its PlayerSpawner from running normally
	# by removing it and handling spawns ourselves)
	_game_world = _game_world_scene.instantiate()
	add_child(_game_world)

	# Wait a frame for the scene to initialize
	await get_tree().process_frame

	# Remove the auto-spawned host player (PlayerSpawner creates one for peer 1)
	var players_node := _game_world.get_node("Players")
	for child in players_node.get_children():
		child.queue_free()
	await get_tree().process_frame

	# Spawn bot players directly
	var spawn_points := SpawnPoints.new()
	for marker in _game_world.get_node("SpawnMarkers").get_children():
		spawn_points.add_point(marker.position)

	for i in BOT_COUNT:
		var peer_id := i + 100  # Use fake peer IDs 100-107
		var pos := spawn_points.get_spawn_point()
		var player := _player_scene.instantiate() as CharacterBody2D
		player.name = str(peer_id)
		player.set_multiplayer_authority(1)  # Server controls all bots
		player.position = pos
		players_node.add_child(player)
		player.is_bot = true

		# Register in game mode
		var game_mode := _game_world.get_node("GameMode")
		if game_mode:
			game_mode.register_player(peer_id)

		# Create bot AI
		var bot := SoakTestBot.new()
		bot.name = "Bot_%d" % peer_id
		add_child(bot)
		bot.setup(player)
		_bots.append(bot)

	_start_node_count = _count_scene_nodes()
	print("[SOAK] Started with %d bots, %d nodes" % [BOT_COUNT, _start_node_count])


func _process(delta: float) -> void:
	_elapsed += delta

	# Track max bullets
	var bullets_node := _game_world.get_node_or_null("Bullets") if _game_world else null
	if bullets_node:
		var bullet_count := bullets_node.get_child_count()
		if bullet_count > _max_bullets_seen:
			_max_bullets_seen = bullet_count

	# Progress report every 10s
	if int(_elapsed) % 10 == 0 and int(_elapsed) > 0 and absf(_elapsed - int(_elapsed)) < delta:
		print("[SOAK] %.0fs elapsed, bullets: %d, nodes: %d" % [
			_elapsed,
			bullets_node.get_child_count() if bullets_node else 0,
			_count_scene_nodes()
		])

	if _elapsed >= SOAK_DURATION:
		_finish()


func _finish() -> void:
	var end_node_count := _count_scene_nodes()
	var end_mem := OS.get_static_memory_usage()
	var mem_growth_mb := float(end_mem - _start_mem) / 1048576.0
	var node_growth := end_node_count - _start_node_count

	print("[SOAK] === Results ===")
	print("[SOAK] Duration: %.1fs" % _elapsed)
	print("[SOAK] Max bullets seen: %d (cap: %d)" % [_max_bullets_seen, NetConstants.MAX_BULLETS_TOTAL])
	print("[SOAK] Node count: start=%d end=%d growth=%d" % [_start_node_count, end_node_count, node_growth])
	print("[SOAK] Memory: growth=%.1f MB" % mem_growth_mb)
	print("[SOAK] Bullet cap respected: %s" % str(_max_bullets_seen <= NetConstants.MAX_BULLETS_TOTAL))

	# Cleanup
	for bot in _bots:
		bot.queue_free()
	_bots.clear()
	NetManager.disconnect_peer()

	get_tree().quit(0)


func _count_scene_nodes() -> int:
	return _count_nodes_recursive(get_tree().root)


func _count_nodes_recursive(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count
