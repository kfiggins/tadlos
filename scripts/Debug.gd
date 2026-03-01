extends Node

## Debug logging helper with category-based toggles.
## Registered as an autoload so any script can call Debug.log(...).

# Future feature toggles (used in later phases)
var draw_hitboxes: bool = false
var show_ping: bool = false
var show_velocity: bool = false

# Category enable/disable map
var _enabled_categories: Dictionary = {}


func enable_category(category: String) -> void:
	_enabled_categories[category] = true


func disable_category(category: String) -> void:
	_enabled_categories[category] = false


func is_category_enabled(category: String) -> bool:
	return _enabled_categories.get(category, false)


func log(category: String, message: String) -> void:
	if _enabled_categories.get(category, false):
		print("[%s] %s" % [category, message])
