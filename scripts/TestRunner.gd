extends Node

## Loads and runs all registered test scenes, printing results.
## Each test scene must have a root node with a `run_tests()` method.

var _test_scenes: Array[String] = [
	"res://tests/test_asserts.tscn",
	"res://tests/test_scene_loads.tscn",
]

var _total_passed: int = 0
var _total_failed: int = 0


func _ready() -> void:
	print("=== TestRunner START ===")
	_run_all_tests()
	print("=== TestRunner END ===")
	print("Total PASSED: %d" % _total_passed)
	print("Total FAILED: %d" % _total_failed)
	if _total_failed > 0:
		print("RESULT: SOME TESTS FAILED")
	else:
		print("RESULT: ALL TESTS PASSED")
	# Exit with appropriate code when running headless
	get_tree().quit(0 if _total_failed == 0 else 1)


func _run_all_tests() -> void:
	for scene_path in _test_scenes:
		print("")
		print("--- Running: %s ---" % scene_path)
		var scene_resource := load(scene_path) as PackedScene
		if scene_resource == null:
			print("[FAIL] Could not load test scene: %s" % scene_path)
			_total_failed += 1
			continue

		var test_instance := scene_resource.instantiate()
		add_child(test_instance)

		# Reset Assert counters before each test scene
		Assert.reset()

		# Call run_tests() on the test scene root
		if test_instance.has_method("run_tests"):
			test_instance.run_tests()
		else:
			print("[FAIL] Test scene missing run_tests(): %s" % scene_path)
			_total_failed += 1

		_total_passed += Assert.pass_count
		_total_failed += Assert.fail_count

		# Clean up
		test_instance.queue_free()
