extends Node2D

## The networked game world scene.
## Contains map geometry, a Players container, and a PlayerSpawner.
## Server and clients both load this scene after host/join succeeds.

func _ready() -> void:
	NetManager.server_disconnected.connect(_on_server_disconnected)
	_setup_game_mode()


func _setup_game_mode() -> void:
	var game_mode: Node
	match NetManager.game_mode:
		TeamConstants.GameMode.TEAM_DEATHMATCH:
			game_mode = GameModeTeamDeathmatch.new()
		_:
			game_mode = GameModeDeathmatch.new()
	game_mode.name = "GameMode"
	# Add before PlayerSpawner so it's available in PlayerSpawner._ready()
	add_child(game_mode)
	move_child(game_mode, $PlayerSpawner.get_index())
	game_mode.kill_occurred.connect(_on_kill_occurred)


func _exit_tree() -> void:
	if NetManager.server_disconnected.is_connected(_on_server_disconnected):
		NetManager.server_disconnected.disconnect(_on_server_disconnected)


func _process(_delta: float) -> void:
	Debug.set_bullets_alive($Bullets.get_child_count())

	if Input.is_action_just_pressed("leave_game"):
		_leave_game()


func _leave_game() -> void:
	NetManager.disconnect_peer()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_server_disconnected() -> void:
	Debug.log("net", "Server disconnected, returning to menu")
	NetManager.disconnect_peer()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_kill_occurred(killer_id: int, victim_id: int) -> void:
	# Find local player's HUD and add kill feed entry
	if not multiplayer.has_multiplayer_peer():
		return
	var local_id := multiplayer.get_unique_id()
	var player_node := $Players.get_node_or_null(str(local_id))
	if player_node == null:
		return
	var hud := player_node.get_node_or_null("HUD")
	if hud and hud.has_method("add_kill_feed"):
		hud.add_kill_feed(killer_id, victim_id)
