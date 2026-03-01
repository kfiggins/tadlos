class_name SpawnPoints
extends RefCounted

## Manages spawn point selection for deathmatch.
## Pure logic class — no scene dependencies for testability.

var _points: Array[Vector2] = []


func _init(points: Array[Vector2] = []) -> void:
	_points = points


func add_point(pos: Vector2) -> void:
	_points.append(pos)


func get_point_count() -> int:
	return _points.size()


func get_points() -> Array[Vector2]:
	return _points.duplicate()


## Pick a spawn point. If avoid_positions is provided, returns the point
## with the greatest minimum distance from all avoid positions.
func get_spawn_point(avoid_positions: Array[Vector2] = []) -> Vector2:
	if _points.is_empty():
		return Vector2(400, 280)  # Fallback

	if avoid_positions.is_empty():
		return _points[randi() % _points.size()]

	# Pick the point farthest from all occupied positions
	var best_point := _points[0]
	var best_min_dist := -1.0
	for point in _points:
		var min_dist := INF
		for avoid in avoid_positions:
			var d := point.distance_to(avoid)
			if d < min_dist:
				min_dist = d
		if min_dist > best_min_dist:
			best_min_dist = min_dist
			best_point = point
	return best_point
