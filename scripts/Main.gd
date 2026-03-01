extends Control


func _ready() -> void:
	%PlayButton.pressed.connect(_on_play_pressed)
	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MovementTestMap.tscn")


func _on_host_pressed() -> void:
	print("Host pressed — not yet implemented")


func _on_join_pressed() -> void:
	print("Join pressed — not yet implemented")


func _on_quit_pressed() -> void:
	get_tree().quit()
