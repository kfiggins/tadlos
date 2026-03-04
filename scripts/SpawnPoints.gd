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
		return Vector2(3000, 960)  # Fallback

	if avoid_positions.is_empty():
		return _points[randi() % _points.size()]

	return _best_avoidance_point(_points, avoid_positions)


## Pick a spawn point preferring a side of the map (for team modes).
## team_side: -1 for left (Red), +1 for right (Blue), 0 for any side.
## Falls back to all points if no team-side points available.
func get_team_spawn_point(team_side: int, avoid_positions: Array[Vector2] = [], midpoint_x: float = 3000.0) -> Vector2:
	if _points.is_empty():
		return Vector2(3000, 960)

	# Filter points by team side
	var team_points: Array[Vector2] = []
	if team_side != 0:
		for p in _points:
			if team_side < 0 and p.x < midpoint_x:
				team_points.append(p)
			elif team_side > 0 and p.x > midpoint_x:
				team_points.append(p)

	# Fallback to all points if no team-side points
	if team_points.is_empty():
		team_points = _points.duplicate()

	if avoid_positions.is_empty():
		return team_points[randi() % team_points.size()]

	return _best_avoidance_point(team_points, avoid_positions)


## Pick the point farthest from all occupied positions (minimax).
func _best_avoidance_point(points: Array[Vector2], avoid_positions: Array[Vector2]) -> Vector2:
	var best_point := points[0]
	var best_min_dist := -1.0
	for point in points:
		var min_dist := INF
		for avoid in avoid_positions:
			var d := point.distance_to(avoid)
			if d < min_dist:
				min_dist = d
		if min_dist > best_min_dist:
			best_min_dist = min_dist
			best_point = point
	return best_point
