class_name TestScenarioRunner
extends RefCounted

const TestUtilsRef = preload("res://tests/TestUtils.gd")
const ScenarioRunnerRef = preload("res://scripts/core/ScenarioRunner.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var runner = ScenarioRunnerRef.new()

	TestUtilsRef.expect_true(failures, runner.is_management_stage(2), "Stage 2 should be management stage")
	TestUtilsRef.expect_true(failures, runner.is_boss_stage(6), "Stage 6 should be boss stage")
	TestUtilsRef.expect_eq(failures, runner.chapter_of_stage(7), 2, "Stage 7 should be chapter 2")

	runner.current_stage = 6
	var next_node: Dictionary = runner.advance_after_victory()
	TestUtilsRef.expect_eq(failures, next_node["node"], "merchant", "Boss clear should enter merchant node")
	TestUtilsRef.expect_eq(failures, int(next_node["next_stage"]), 7, "Next stage after boss should be 7")
	return failures
