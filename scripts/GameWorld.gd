extends Node2D

## The networked game world scene.
## Contains map geometry, a Players container, and a PlayerSpawner.
## Server and clients both load this scene after host/join succeeds.

func _ready() -> void:
	NetManager.server_disconnected.connect(_on_server_disconnected)
	# Wire kill feed: when a kill occurs, push it to the local player's HUD
	var game_mode := $GameModeDeathmatch
	if game_mode:
		game_mode.kill_occurred.connect(_on_kill_occurred)


func _exit_tree() -> void:
	if NetManager.server_disconnected.is_connected(_on_server_disconnected):
		NetManager.server_disconnected.disconnect(_on_server_disconnected)


func _process(_delta: float) -> void:
	Debug.set_bullets_alive($Bullets.get_child_count())


func _on_server_disconnected() -> void:
	Debug.log("net", "Server disconnected, returning to menu")
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
