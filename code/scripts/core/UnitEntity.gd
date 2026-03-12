class_name UnitEntity
extends RefCounted

var unit_id: StringName
var camp: StringName
var max_hp: int
var hp: int
var atk: int
var defense: int
var hit: int
var avoid: int
var crit: int
var crit_resist: int
var attack_range_min: int
var attack_range_max: int
var counter_range: int
var move_points: int
var roles: Array[String]


func _init(data: Dictionary = {}) -> void:
	unit_id = StringName(data.get("unit_id", "unit"))
	camp = StringName(data.get("camp", "player"))
	max_hp = int(data.get("max_hp", 100))
	hp = int(data.get("hp", max_hp))
	atk = int(data.get("atk", 25))
	defense = int(data.get("defense", 10))
	hit = int(data.get("hit", 85))
	avoid = int(data.get("avoid", 5))
	crit = int(data.get("crit", 10))
	crit_resist = int(data.get("crit_resist", 0))
	attack_range_min = int(data.get("attack_range_min", 1))
	attack_range_max = int(data.get("attack_range_max", 1))
	counter_range = int(data.get("counter_range", 1))
	move_points = int(data.get("move_points", 4))
	roles = []
	var raw_roles: Array = data.get("roles", ["frontline"])
	for role_name in raw_roles:
		roles.append(String(role_name))


func is_alive() -> bool:
	return hp > 0


func apply_damage(value: int) -> int:
	var damage: int = maxi(0, value)
	hp = maxi(0, hp - damage)
	return damage


func in_counter_range(distance: int, is_melee_attack: bool) -> bool:
	if not is_alive():
		return false
	if is_melee_attack:
		return distance <= counter_range
	return false
