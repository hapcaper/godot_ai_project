class_name TestCombatResolver
extends RefCounted

const TestUtilsRef = preload("res://tests/TestUtils.gd")
const UnitEntityRef = preload("res://scripts/core/UnitEntity.gd")
const CombatResolverRef = preload("res://scripts/core/CombatResolver.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var attacker = UnitEntityRef.new({
		"unit_id": "hero",
		"atk": 40,
		"defense": 12,
		"hit": 90,
		"avoid": 10,
		"crit": 20,
		"crit_resist": 0,
		"hp": 120,
	})
	var defender = UnitEntityRef.new({
		"unit_id": "bandit",
		"atk": 25,
		"defense": 8,
		"hit": 80,
		"avoid": 5,
		"crit": 5,
		"crit_resist": 0,
		"hp": 100,
	})

	var resolver = CombatResolverRef.new()
	var pv: Dictionary = resolver.preview(attacker, defender, {"distance": 1, "is_melee_attack": true})
	TestUtilsRef.expect_true(failures, int(pv["base_damage"]) >= 1, "Preview damage should be positive")
	TestUtilsRef.expect_true(failures, bool(pv["can_counter"]), "Melee should allow counter")

	var result: Dictionary = resolver.resolve_attack(
		attacker,
		defender,
		{"distance": 1, "is_melee_attack": true},
		{"hit_roll": 1, "crit_roll": 100, "counter_hit_roll": 1}
	)
	TestUtilsRef.expect_true(failures, bool(result["hit_success"]), "Attack should hit with low roll")
	TestUtilsRef.expect_true(failures, int(result["damage"]) > 0, "Damage should be applied")
	TestUtilsRef.expect_true(failures, int(result["counter_damage"]) >= 0, "Counter result should exist")
	return failures
