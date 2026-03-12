class_name BattleController
extends RefCounted

enum Phase {
	SETUP,
	PLAYER_TURN,
	ENEMY_TURN,
	VICTORY,
	DEFEAT,
}

var phase: Phase = Phase.SETUP
var player_unit_ids: Array[StringName] = []
var enemy_unit_ids: Array[StringName] = []
var acted_units: Dictionary = {}


func start_battle(player_ids: Array[StringName], enemy_ids: Array[StringName]) -> void:
	player_unit_ids.clear()
	for unit_id in player_ids:
		player_unit_ids.append(unit_id)
	enemy_unit_ids.clear()
	for unit_id in enemy_ids:
		enemy_unit_ids.append(unit_id)
	acted_units.clear()
	phase = Phase.PLAYER_TURN


func mark_unit_acted(unit_id: StringName) -> void:
	if phase != Phase.PLAYER_TURN:
		return
	acted_units[unit_id] = true


func all_player_acted() -> bool:
	for unit_id in player_unit_ids:
		if not acted_units.has(unit_id):
			return false
	return player_unit_ids.size() > 0


func end_player_turn() -> void:
	if phase == Phase.PLAYER_TURN:
		phase = Phase.ENEMY_TURN
		acted_units.clear()


func end_enemy_turn() -> void:
	if phase == Phase.ENEMY_TURN:
		phase = Phase.PLAYER_TURN
		acted_units.clear()


func resolve_battle_result(player_alive_count: int, enemy_alive_count: int) -> void:
	if player_alive_count <= 0 and enemy_alive_count <= 0:
		phase = Phase.DEFEAT
	elif enemy_alive_count <= 0:
		phase = Phase.VICTORY
	elif player_alive_count <= 0:
		phase = Phase.DEFEAT
