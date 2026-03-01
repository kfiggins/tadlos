extends Node2D

## The networked game world scene.
## Contains map geometry, a Players container, and a PlayerSpawner.
## Server and clients both load this scene after host/join succeeds.

func _ready() -> void:
	NetManager.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
	if NetManager.server_disconnected.is_connected(_on_server_disconnected):
		NetManager.server_disconnected.disconnect(_on_server_disconnected)


func _on_server_disconnected() -> void:
	Debug.log("net", "Server disconnected, returning to menu")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
