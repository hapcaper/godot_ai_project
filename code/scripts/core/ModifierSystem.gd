class_name ModifierSystem
extends RefCounted

var small_affixes: Array[String] = [
	"atk_up_10",
	"def_up_10",
	"morale_up_10",
]

var medium_affixes: Array[String] = [
	"move_plus_1",
	"first_turn_range_plus_1",
	"status_resist_up",
]

var chapter_rules: Array[String] = [
	"mountain_mastery",
	"night_battle",
	"river_crossing",
	"city_fortification",
]


func generate_for_stage(stage_index: int, chapter_index: int, is_elite: bool, is_boss: bool, seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(seed_value + stage_index * 97 + chapter_index * 997)

	var picked_small: Array[String] = []
	var picked_medium: Array[String] = []
	var picked_chapter: Array[String] = []

	if is_boss:
		picked_medium = _pick_unique(rng, medium_affixes, 2)
		picked_chapter = _pick_unique(rng, [chapter_rules[(chapter_index - 1) % chapter_rules.size()]], 1)
	elif is_elite:
		picked_small = _pick_unique(rng, small_affixes, 1)
		picked_medium = _pick_unique(rng, medium_affixes, 1)
	else:
		picked_small = _pick_unique(rng, small_affixes, 1)

	return {
		"small": picked_small,
		"medium": picked_medium,
		"chapter": picked_chapter,
	}


func _pick_unique(rng: RandomNumberGenerator, pool: Array[String], count: int) -> Array[String]:
	var temp: Array[String] = []
	for item in pool:
		temp.append(item)
	var out: Array[String] = []
	for _i in range(mini(count, temp.size())):
		var idx: int = rng.randi_range(0, temp.size() - 1)
		out.append(temp[idx])
		temp.remove_at(idx)
	return out
