class_name TestBattleController
extends RefCounted

const TestUtilsRef = preload("res://tests/TestUtils.gd")
const BattleControllerRef = preload("res://scripts/core/BattleController.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var controller = BattleControllerRef.new()
	controller.start_battle([&"p1", &"p2"], [&"e1"])

	TestUtilsRef.expect_eq(failures, controller.phase, BattleControllerRef.Phase.PLAYER_TURN, "Battle should start at player turn")
	controller.mark_unit_acted(&"p1")
	TestUtilsRef.expect_true(failures, not controller.all_player_acted(), "Not all units should be acted yet")
	controller.mark_unit_acted(&"p2")
	TestUtilsRef.expect_true(failures, controller.all_player_acted(), "All units should be acted after two marks")

	controller.end_player_turn()
	TestUtilsRef.expect_eq(failures, controller.phase, BattleControllerRef.Phase.ENEMY_TURN, "Phase should move to enemy turn")
	controller.end_enemy_turn()
	TestUtilsRef.expect_eq(failures, controller.phase, BattleControllerRef.Phase.PLAYER_TURN, "Phase should return to player turn")

	controller.resolve_battle_result(2, 0)
	TestUtilsRef.expect_eq(failures, controller.phase, BattleControllerRef.Phase.VICTORY, "Enemy defeated should be victory")
	return failures
