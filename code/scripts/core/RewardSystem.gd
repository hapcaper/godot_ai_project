class_name RewardSystem
extends RefCounted

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var missing_role_streaks: Dictionary = {
	"healer": 0,
	"frontline": 0,
	"cleanse": 0,
}

var reward_pool: Array[Dictionary] = [
	{"id": "eq_iron_blade", "type": "equipment", "rarity_weight": 35.0, "supports": ["frontline"]},
	{"id": "eq_guard_shield", "type": "equipment", "rarity_weight": 25.0, "supports": ["frontline"]},
	{"id": "scroll_heal", "type": "scroll", "rarity_weight": 20.0, "supports": ["healer"]},
	{"id": "scroll_cleanse", "type": "scroll", "rarity_weight": 12.0, "supports": ["cleanse"]},
	{"id": "passive_vanguard", "type": "passive", "rarity_weight": 10.0, "supports": ["frontline"]},
	{"id": "res_gold_pack", "type": "resource", "rarity_weight": 45.0, "supports": []},
	{"id": "res_supply_pack", "type": "resource", "rarity_weight": 30.0, "supports": []},
]


func register_team_roles(current_roles: Array[String]) -> void:
	for role_name in missing_role_streaks.keys():
		if current_roles.has(role_name):
			missing_role_streaks[role_name] = 0
		else:
			missing_role_streaks[role_name] = int(missing_role_streaks[role_name]) + 1


func generate_choices(seed_value: int = -1) -> Array[Dictionary]:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var available: Array[Dictionary] = reward_pool.duplicate(true)
	var choices: Array[Dictionary] = []

	while choices.size() < 3 and available.size() > 0:
		var weights: Array[float] = []
		for reward in available:
			var base_weight: float = float(reward.get("rarity_weight", 1.0))
			weights.append(base_weight * _pity_multiplier(reward))
		var pick_index: int = _weighted_index(weights)
		choices.append(available[pick_index])
		available.remove_at(pick_index)

	return choices


func _pity_multiplier(reward: Dictionary) -> float:
	var supports: Array = reward.get("supports", [])
	var mul: float = 1.0
	for role_name in supports:
		if missing_role_streaks.has(role_name):
			mul += minf(1.25, float(missing_role_streaks[role_name]) * 0.35)
	return mul


func _weighted_index(weights: Array[float]) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 0
	var roll: float = rng.randf_range(0.0, total)
	var cumulative: float = 0.0
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return i
	return weights.size() - 1
