class_name TestRewardSystem
extends RefCounted

const TestUtilsRef = preload("res://tests/TestUtils.gd")
const RewardSystemRef = preload("res://scripts/core/RewardSystem.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var reward_system = RewardSystemRef.new()
	reward_system.register_team_roles(["frontline"]) # healer / cleanse missing -> pity increases
	reward_system.register_team_roles(["frontline"]) # stack streak

	var choices: Array[Dictionary] = reward_system.generate_choices(20260308)
	TestUtilsRef.expect_eq(failures, choices.size(), 3, "Must generate exactly three choices")

	var ids: Dictionary = {}
	for c in choices:
		ids[c["id"]] = true
	TestUtilsRef.expect_eq(failures, ids.size(), 3, "Three choices must be unique")
	return failures
