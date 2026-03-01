extends Node

## Tests that key scenes load without errors and contain expected nodes.


func run_tests() -> void:
	_test_main_scene_loads()
	_test_test_runner_scene_loads()


func _test_main_scene_loads() -> void:
	var scene := load("res://scenes/Main.tscn") as PackedScene
	Assert.assert_not_null(scene, "Main.tscn loads successfully")

	var instance := scene.instantiate()
	Assert.assert_not_null(instance, "Main.tscn instantiates successfully")

	# Verify key nodes exist
	var host_button := instance.find_child("HostButton")
	Assert.assert_not_null(host_button, "Main has HostButton")

	var join_button := instance.find_child("JoinButton")
	Assert.assert_not_null(join_button, "Main has JoinButton")

	var quit_button := instance.find_child("QuitButton")
	Assert.assert_not_null(quit_button, "Main has QuitButton")

	instance.free()


func _test_test_runner_scene_loads() -> void:
	var scene := load("res://scenes/TestRunner.tscn") as PackedScene
	Assert.assert_not_null(scene, "TestRunner.tscn loads successfully")

	var instance := scene.instantiate()
	Assert.assert_not_null(instance, "TestRunner.tscn instantiates successfully")

	Assert.assert_true(instance.has_method("_run_all_tests"), "TestRunner has _run_all_tests method")

	instance.free()
