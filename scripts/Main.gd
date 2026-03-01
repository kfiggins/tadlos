extends Control

## Main menu with Host/Join/Play/Quit buttons.
## Host starts a server and transitions to GameWorld.
## Join connects to an IP and transitions to GameWorld on success.

func _ready() -> void:
	%PlayButton.pressed.connect(_on_play_pressed)
	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)

	NetManager.connection_succeeded.connect(_on_connection_succeeded)
	NetManager.connection_failed.connect(_on_connection_failed)


func _exit_tree() -> void:
	if NetManager.connection_succeeded.is_connected(_on_connection_succeeded):
		NetManager.connection_succeeded.disconnect(_on_connection_succeeded)
	if NetManager.connection_failed.is_connected(_on_connection_failed):
		NetManager.connection_failed.disconnect(_on_connection_failed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MovementTestMap.tscn")


func _on_host_pressed() -> void:
	var port: int = NetConstants.DEFAULT_PORT
	var err: Error = NetManager.host(port)
	if err == OK:
		%StatusLabel.text = "Hosting on port %d..." % port
		get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")
	else:
		%StatusLabel.text = "Failed to host: %s" % error_string(err)


func _on_join_pressed() -> void:
	var ip: String = %IPInput.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	var port: int = NetConstants.DEFAULT_PORT
	%StatusLabel.text = "Connecting to %s:%d..." % [ip, port]
	var err: Error = NetManager.join(ip, port)
	if err != OK:
		%StatusLabel.text = "Failed to join: %s" % error_string(err)


func _on_connection_succeeded() -> void:
	get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")


func _on_connection_failed() -> void:
	%StatusLabel.text = "Connection failed"


func _on_quit_pressed() -> void:
	get_tree().quit()
