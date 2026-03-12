class_name BattleState
extends RefCounted

const UnitEntityRef = preload("res://scripts/core/UnitEntity.gd")
const BattleControllerRef = preload("res://scripts/core/BattleController.gd")
const GridServiceRef = preload("res://scripts/core/GridService.gd")
const CombatResolverRef = preload("res://scripts/core/CombatResolver.gd")

var grid: GridService
var controller: BattleController
var resolver: CombatResolver
var units: Dictionary = {}
var positions: Dictionary = {}
var moved_units: Dictionary = {}


func _init(grid_service: GridService = null) -> void:
	grid = grid_service if grid_service != null else GridServiceRef.new(8, 8)
	controller = BattleControllerRef.new()
	resolver = CombatResolverRef.new()


func setup_battle(unit_defs: Array[Dictionary], unit_positions: Dictionary) -> void:
	units.clear()
	positions.clear()
	moved_units.clear()
	var player_ids: Array[StringName] = []
	var enemy_ids: Array[StringName] = []

	for item in unit_defs:
		var unit = UnitEntityRef.new(item)
		units[unit.unit_id] = unit
		if String(unit.camp) == "player":
			player_ids.append(unit.unit_id)
		else:
			enemy_ids.append(unit.unit_id)

	var occupied: Dictionary = {}
	for uid in unit_positions.keys():
		if not units.has(uid):
			continue
		var cell: Vector2i = unit_positions[uid]
		if not grid.is_in_bounds(cell):
			continue
		if occupied.has(cell):
			continue
		positions[uid] = cell
		occupied[cell] = uid

	controller.start_battle(player_ids, enemy_ids)
	_update_battle_result()


func get_unit(unit_id: StringName):
	return units.get(unit_id)


func get_position(unit_id: StringName) -> Vector2i:
	if not positions.has(unit_id):
		return Vector2i(-1, -1)
	return positions[unit_id]


func get_unit_at(cell: Vector2i) -> StringName:
	for uid in positions.keys():
		if positions[uid] != cell:
			continue
		var unit = units.get(uid)
		if unit == null or not unit.is_alive():
			continue
		return uid
	return &""


func is_occupied(cell: Vector2i) -> bool:
	return get_unit_at(cell) != &""


func has_moved(unit_id: StringName) -> bool:
	return moved_units.has(unit_id)


func player_units_alive() -> Array[StringName]:
	var out: Array[StringName] = []
	for uid in controller.player_unit_ids:
		var unit = units.get(uid)
		if unit != null and unit.is_alive():
			out.append(uid)
	return out


func enemy_units_alive() -> Array[StringName]:
	var out: Array[StringName] = []
	for uid in controller.enemy_unit_ids:
		var unit = units.get(uid)
		if unit != null and unit.is_alive():
			out.append(uid)
	return out


func can_player_act(unit_id: StringName) -> bool:
	if controller.phase != BattleControllerRef.Phase.PLAYER_TURN:
		return false
	if not controller.player_unit_ids.has(unit_id):
		return false
	if controller.acted_units.has(unit_id):
		return false
	var unit = units.get(unit_id)
	return unit != null and unit.is_alive()


func get_reachable_cells(unit_id: StringName) -> Array[Vector2i]:
	var unit = units.get(unit_id)
	if unit == null:
		return []
	var start: Vector2i = get_position(unit_id)
	if start.x < 0:
		return []

	var reachable: Dictionary = {start: 0}
	var frontier: Array[Vector2i] = [start]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = int(reachable[current])
		for nxt in grid.get_neighbors4(current):
			if is_occupied(nxt) and nxt != start:
				continue
			var new_cost: int = current_cost + grid.get_move_cost(nxt)
			if new_cost > unit.move_points:
				continue
			if not reachable.has(nxt) or new_cost < int(reachable[nxt]):
				reachable[nxt] = new_cost
				if not frontier.has(nxt):
					frontier.append(nxt)

	var cells: Array[Vector2i] = []
	for cell in reachable.keys():
		cells.append(cell)
	return cells


func find_movement_path(unit_id: StringName, target_cell: Vector2i) -> Array[Vector2i]:
	var unit = units.get(unit_id)
	if unit == null:
		return []
	var start: Vector2i = get_position(unit_id)
	if start.x < 0:
		return []
	if target_cell == start:
		return [start]

	var reachable: Dictionary = {start: 0}
	var came_from: Dictionary = {start: start}
	var frontier: Array[Vector2i] = [start]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = int(reachable[current])
		for nxt in grid.get_neighbors4(current):
			if is_occupied(nxt) and nxt != start:
				continue
			var new_cost: int = current_cost + grid.get_move_cost(nxt)
			if new_cost > unit.move_points:
				continue
			if not reachable.has(nxt) or new_cost < int(reachable[nxt]):
				reachable[nxt] = new_cost
				came_from[nxt] = current
				if not frontier.has(nxt):
					frontier.append(nxt)

	if not came_from.has(target_cell):
		return []

	var path: Array[Vector2i] = [target_cell]
	var current_cell: Vector2i = target_cell
	while current_cell != start:
		current_cell = came_from[current_cell]
		path.push_front(current_cell)
	return path


func move_unit(unit_id: StringName, target_cell: Vector2i) -> bool:
	if not can_player_act(unit_id):
		return false
	if moved_units.has(unit_id):
		return false
	if is_occupied(target_cell) and get_unit_at(target_cell) != unit_id:
		return false
	var reachable: Array[Vector2i] = get_reachable_cells(unit_id)
	if not reachable.has(target_cell):
		return false
	positions[unit_id] = target_cell
	moved_units[unit_id] = true
	return true


func can_attack_target(attacker_id: StringName, defender_id: StringName) -> bool:
	if not units.has(attacker_id) or not units.has(defender_id):
		return false
	var attacker = units[attacker_id]
	var defender = units[defender_id]
	if not attacker.is_alive() or not defender.is_alive():
		return false
	if String(attacker.camp) == String(defender.camp):
		return false

	if String(attacker.camp) == "player":
		if not can_player_act(attacker_id):
			return false
	elif String(attacker.camp) == "enemy":
		if controller.phase != BattleControllerRef.Phase.ENEMY_TURN:
			return false
	else:
		return false

	var distance: int = _distance(get_position(attacker_id), get_position(defender_id))
	return distance >= attacker.attack_range_min and distance <= attacker.attack_range_max


func preview_attack(attacker_id: StringName, defender_id: StringName) -> Dictionary:
	if not can_attack_target(attacker_id, defender_id):
		return {"ok": false, "reason": "cannot_attack"}
	var attacker = units[attacker_id]
	var defender = units[defender_id]
	var distance: int = _distance(get_position(attacker_id), get_position(defender_id))
	var context: Dictionary = {
		"distance": distance,
		"is_melee_attack": distance == 1,
	}
	var data: Dictionary = resolver.preview(attacker, defender, context)
	data["ok"] = true
	data["attacker"] = attacker_id
	data["defender"] = defender_id
	return data


func wait_unit(unit_id: StringName) -> bool:
	if not can_player_act(unit_id):
		return false
	controller.mark_unit_acted(unit_id)
	return true


func attack(attacker_id: StringName, defender_id: StringName, rolls: Dictionary = {}) -> Dictionary:
	if not units.has(attacker_id) or not units.has(defender_id):
		return {"ok": false, "reason": "missing_unit"}

	var attacker = units[attacker_id]
	var defender = units[defender_id]
	if not attacker.is_alive() or not defender.is_alive():
		return {"ok": false, "reason": "dead_unit"}
	if String(attacker.camp) == String(defender.camp):
		return {"ok": false, "reason": "friendly_fire_blocked"}

	if String(attacker.camp) == "player":
		if not can_player_act(attacker_id):
			return {"ok": false, "reason": "not_player_actionable"}
	elif String(attacker.camp) == "enemy":
		if controller.phase != BattleControllerRef.Phase.ENEMY_TURN:
			return {"ok": false, "reason": "not_enemy_turn"}
	else:
		return {"ok": false, "reason": "unknown_camp"}

	var distance: int = _distance(get_position(attacker_id), get_position(defender_id))
	if distance < attacker.attack_range_min or distance > attacker.attack_range_max:
		return {"ok": false, "reason": "out_of_range"}

	var context: Dictionary = {
		"distance": distance,
		"is_melee_attack": distance == 1,
	}
	var result: Dictionary = resolver.resolve_attack(attacker, defender, context, rolls)
	result["ok"] = true
	result["attacker"] = attacker_id
	result["defender"] = defender_id
	if not attacker.is_alive():
		positions.erase(attacker_id)
	if not defender.is_alive():
		positions.erase(defender_id)

	if controller.player_unit_ids.has(attacker_id):
		controller.mark_unit_acted(attacker_id)

	_update_battle_result()
	return result


func end_player_turn_and_run_enemy() -> Array[Dictionary]:
	var logs: Array[Dictionary] = []
	if controller.phase != BattleControllerRef.Phase.PLAYER_TURN:
		return logs

	controller.end_player_turn()

	for enemy_id in enemy_units_alive():
		if controller.phase != BattleControllerRef.Phase.ENEMY_TURN:
			break

		var target_id: StringName = _nearest_player(enemy_id)
		if target_id == &"":
			continue

		var e_pos: Vector2i = get_position(enemy_id)
		var t_pos: Vector2i = get_position(target_id)
		var d: int = _distance(e_pos, t_pos)

		if d > 1:
			var move_cell: Vector2i = _choose_enemy_step(enemy_id, target_id)
			if move_cell.x >= 0:
				var from_cell: Vector2i = positions[enemy_id]
				positions[enemy_id] = move_cell
				logs.append({"type": "enemy_move", "unit": enemy_id, "from": from_cell, "to": move_cell})
			e_pos = get_position(enemy_id)
			d = _distance(e_pos, t_pos)

		if d == 1:
			var outcome: Dictionary = attack(enemy_id, target_id, {"hit_roll": 1, "crit_roll": 100, "counter_hit_roll": 1})
			logs.append({"type": "enemy_attack", "unit": enemy_id, "target": target_id, "outcome": outcome})

	_update_battle_result()
	if controller.phase == BattleControllerRef.Phase.ENEMY_TURN:
		controller.end_enemy_turn()
	if controller.phase == BattleControllerRef.Phase.PLAYER_TURN:
		controller.acted_units.clear()
		moved_units.clear()
	_update_battle_result()
	return logs


func _choose_enemy_step(enemy_id: StringName, target_id: StringName) -> Vector2i:
	var start: Vector2i = get_position(enemy_id)
	var target: Vector2i = get_position(target_id)
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_dist: int = _distance(start, target)
	for nxt in grid.get_neighbors4(start):
		if is_occupied(nxt):
			continue
		var d: int = _distance(nxt, target)
		if d < best_dist:
			best_dist = d
			best_cell = nxt
	return best_cell


func _nearest_player(enemy_id: StringName) -> StringName:
	var best_id: StringName = &""
	var best_dist: int = 999999
	var e_pos: Vector2i = get_position(enemy_id)
	for pid in player_units_alive():
		var d: int = _distance(e_pos, get_position(pid))
		if d < best_dist:
			best_dist = d
			best_id = pid
	return best_id


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _update_battle_result() -> void:
	controller.resolve_battle_result(player_units_alive().size(), enemy_units_alive().size())
