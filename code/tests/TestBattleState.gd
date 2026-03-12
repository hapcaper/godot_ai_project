class_name TestBattleState
extends RefCounted

const TestUtilsRef = preload("res://tests/TestUtils.gd")
const GridServiceRef = preload("res://scripts/core/GridService.gd")
const BattleStateRef = preload("res://scripts/core/BattleState.gd")
const BattleControllerRef = preload("res://scripts/core/BattleController.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var grid = GridServiceRef.new(6, 4)
	for y in range(4):
		for x in range(6):
			grid.set_terrain(Vector2i(x, y), &"plain")

	var battle_state = BattleStateRef.new(grid)
	battle_state.setup_battle(
		[
			{"unit_id": "P1", "camp": "player", "hp": 100, "max_hp": 100, "atk": 35, "defense": 10, "hit": 95, "avoid": 5, "crit": 0, "move_points": 3},
			{"unit_id": "E1", "camp": "enemy", "hp": 30, "max_hp": 30, "atk": 20, "defense": 5, "hit": 80, "avoid": 0, "crit": 0, "move_points": 3},
		],
		{&"P1": Vector2i(1, 1), &"E1": Vector2i(3, 1)}
	)

	TestUtilsRef.expect_true(failures, battle_state.can_player_act(&"P1"), "P1 should be actionable at turn start")
	var reachable: Array[Vector2i] = battle_state.get_reachable_cells(&"P1")
	TestUtilsRef.expect_true(failures, reachable.has(Vector2i(2, 1)), "P1 should be able to move to adjacent tile")

	var moved: bool = battle_state.move_unit(&"P1", Vector2i(2, 1))
	TestUtilsRef.expect_true(failures, moved, "P1 should move successfully")
	var moved_twice: bool = battle_state.move_unit(&"P1", Vector2i(2, 2))
	TestUtilsRef.expect_true(failures, not moved_twice, "P1 should not move twice in one turn")

	var preview: Dictionary = battle_state.preview_attack(&"P1", &"E1")
	TestUtilsRef.expect_true(failures, bool(preview.get("ok", false)), "Preview should be available on legal target")
	TestUtilsRef.expect_true(failures, int(preview.get("hit_rate", 0)) > 0, "Preview should include hit rate")

	var attack_result: Dictionary = battle_state.attack(&"P1", &"E1", {"hit_roll": 1, "crit_roll": 100, "counter_hit_roll": 100})
	TestUtilsRef.expect_true(failures, bool(attack_result.get("ok", false)), "Attack should succeed")
	TestUtilsRef.expect_true(failures, int(attack_result.get("damage", 0)) > 0, "Attack should deal damage")
	TestUtilsRef.expect_eq(failures, battle_state.controller.phase, BattleControllerRef.Phase.VICTORY, "Enemy death should trigger victory")
	TestUtilsRef.expect_eq(failures, battle_state.get_unit_at(Vector2i(3, 1)), &"", "Dead unit tile should become unoccupied")
	TestUtilsRef.expect_true(failures, not battle_state.is_occupied(Vector2i(3, 1)), "Dead unit tile should not block movement")

	# 第二个样例：验证敌方回合可推进
	battle_state.setup_battle(
		[
			{"unit_id": "P1", "camp": "player", "hp": 100, "max_hp": 100, "atk": 20, "defense": 10, "hit": 95, "avoid": 5, "crit": 0, "move_points": 2},
			{"unit_id": "E1", "camp": "enemy", "hp": 100, "max_hp": 100, "atk": 20, "defense": 10, "hit": 95, "avoid": 0, "crit": 0, "move_points": 2},
		],
		{&"P1": Vector2i(1, 1), &"E1": Vector2i(4, 1)}
	)
	var waited: bool = battle_state.wait_unit(&"P1")
	TestUtilsRef.expect_true(failures, waited, "Wait should mark player unit as acted")
	var waited_again: bool = battle_state.wait_unit(&"P1")
	TestUtilsRef.expect_true(failures, not waited_again, "Acted unit should not wait twice in same turn")

	var logs: Array[Dictionary] = battle_state.end_player_turn_and_run_enemy()
	TestUtilsRef.expect_true(failures, logs.size() > 0, "Enemy turn should produce move or attack logs")
	TestUtilsRef.expect_eq(failures, battle_state.controller.phase, BattleControllerRef.Phase.PLAYER_TURN, "Enemy turn should end and return to player phase")
	return failures
