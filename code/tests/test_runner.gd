extends SceneTree

const TestBattleControllerRef = preload("res://tests/TestBattleController.gd")
const TestGridServiceRef = preload("res://tests/TestGridService.gd")
const TestCombatResolverRef = preload("res://tests/TestCombatResolver.gd")
const TestRewardSystemRef = preload("res://tests/TestRewardSystem.gd")
const TestScenarioRunnerRef = preload("res://tests/TestScenarioRunner.gd")
const TestBattleStateRef = preload("res://tests/TestBattleState.gd")


func _init() -> void:
	var all_failures: Array[String] = []
	var suites: Array = [
		{"name": "TestBattleController", "suite": TestBattleControllerRef},
		{"name": "TestGridService", "suite": TestGridServiceRef},
		{"name": "TestCombatResolver", "suite": TestCombatResolverRef},
		{"name": "TestRewardSystem", "suite": TestRewardSystemRef},
		{"name": "TestScenarioRunner", "suite": TestScenarioRunnerRef},
		{"name": "TestBattleState", "suite": TestBattleStateRef},
	]

	for item in suites:
		var suite_name: String = item["name"]
		var suite_ref = item["suite"]
		var failures: Array[String] = suite_ref.run()
		if failures.is_empty():
			print("[PASS] %s" % suite_name)
		else:
			for failure in failures:
				all_failures.append("[%s] %s" % [suite_name, failure])

	if all_failures.is_empty():
		print("All tests passed.")
		quit(0)
		return

	for f in all_failures:
		printerr(f)
	printerr("Total failures: %d" % all_failures.size())
	quit(1)
