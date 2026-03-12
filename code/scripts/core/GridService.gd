class_name GridService
extends RefCounted

var width: int
var height: int
var terrain_map: Dictionary = {}
var terrain_defs: Dictionary = {
	"plain": {"move_cost": 1, "passable": true, "tags": ["all"]},
	"forest": {"move_cost": 2, "passable": true, "tags": ["infantry", "all"]},
	"mountain": {"move_cost": 3, "passable": true, "tags": ["infantry", "all"]},
	"city": {"move_cost": 1, "passable": true, "tags": ["all"]},
	"shoal": {"move_cost": 2, "passable": true, "tags": ["all"]},
	"wall": {"move_cost": 99, "passable": false, "tags": []},
}


func _init(map_width: int = 12, map_height: int = 12) -> void:
	width = map_width
	height = map_height


func set_terrain(cell: Vector2i, terrain_id: StringName) -> void:
	terrain_map[cell] = String(terrain_id)


func get_terrain(cell: Vector2i) -> String:
	if not terrain_map.has(cell):
		return "plain"
	return String(terrain_map[cell])


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_passable(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	var terrain_id: String = get_terrain(cell)
	if not terrain_defs.has(terrain_id):
		return false
	return bool(terrain_defs[terrain_id].get("passable", true))


func get_move_cost(cell: Vector2i) -> int:
	var terrain_id: String = get_terrain(cell)
	if not terrain_defs.has(terrain_id):
		return 99
	return int(terrain_defs[terrain_id].get("move_cost", 1))


func get_neighbors4(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for d in dirs:
		var nxt: Vector2i = cell + d
		if is_passable(nxt):
			neighbors.append(nxt)
	return neighbors


func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not is_passable(start) or not is_passable(goal):
		return []

	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0}

	while frontier.size() > 0:
		var current: Vector2i = _pop_lowest_cost(frontier, cost_so_far)
		if current == goal:
			break
		for nxt in get_neighbors4(current):
			var new_cost: int = int(cost_so_far[current]) + get_move_cost(nxt)
			if not cost_so_far.has(nxt) or new_cost < int(cost_so_far[nxt]):
				cost_so_far[nxt] = new_cost
				if not frontier.has(nxt):
					frontier.append(nxt)
				came_from[nxt] = current

	if not came_from.has(goal):
		return []
	return _reconstruct_path(came_from, start, goal)


func count_distinct_paths_limited(start: Vector2i, goal: Vector2i, max_paths: int = 2, max_depth: int = 128) -> int:
	var visited: Dictionary = {}
	return _dfs_count(start, goal, visited, max_paths, max_depth)


func validate_map_constraints(spawn_a: Vector2i, spawn_b: Vector2i, key_points: Array[Vector2i], role_zones: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var path_count: int = count_distinct_paths_limited(spawn_a, spawn_b, 2, width * height)
	if path_count < 2:
		errors.append("Spawn points require at least two distinct paths.")

	for point in key_points:
		if find_path(spawn_a, point).is_empty() or find_path(spawn_b, point).is_empty():
			errors.append("Key point %s is blocked from one side." % [point])

	for role_name in role_zones.keys():
		var zone_cells: Array = role_zones[role_name]
		var has_playable_cell: bool = false
		for cell in zone_cells:
			if is_passable(cell):
				has_playable_cell = true
				break
		if not has_playable_cell:
			errors.append("Role %s has no playable zone." % [role_name])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"path_count": path_count,
	}


func _pop_lowest_cost(frontier: Array[Vector2i], costs: Dictionary) -> Vector2i:
	var best_index: int = 0
	var best_cell: Vector2i = frontier[0]
	var best_cost: int = int(costs.get(best_cell, 1_000_000))
	for i in range(1, frontier.size()):
		var cell: Vector2i = frontier[i]
		var c: int = int(costs.get(cell, 1_000_000))
		if c < best_cost:
			best_cost = c
			best_cell = cell
			best_index = i
	frontier.remove_at(best_index)
	return best_cell


func _reconstruct_path(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var current: Vector2i = goal
	while current != start:
		current = came_from[current]
		path.push_front(current)
	return path


func _dfs_count(current: Vector2i, goal: Vector2i, visited: Dictionary, max_paths: int, depth_left: int) -> int:
	if depth_left <= 0:
		return 0
	if current == goal:
		return 1
	visited[current] = true
	var found: int = 0
	for nxt in get_neighbors4(current):
		if visited.has(nxt):
			continue
		found += _dfs_count(nxt, goal, visited, max_paths, depth_left - 1)
		if found >= max_paths:
			visited.erase(current)
			return found
	visited.erase(current)
	return found
