class_name CombatResolver
extends RefCounted


func preview(attacker: UnitEntity, defender: UnitEntity, context: Dictionary = {}) -> Dictionary:
	var attack_bonus: int = int(context.get("attack_bonus", 0))
	var defense_bonus: int = int(context.get("defense_bonus", 0))
	var hit_bonus: int = int(context.get("hit_bonus", 0))
	var avoid_bonus: int = int(context.get("avoid_bonus", 0))
	var distance: int = int(context.get("distance", 1))
	var is_melee_attack: bool = bool(context.get("is_melee_attack", true))

	var hit_rate: int = clampi(attacker.hit + hit_bonus - defender.avoid - avoid_bonus, 5, 95)
	var crit_rate: int = clampi(attacker.crit - defender.crit_resist, 0, 60)
	var base_damage: int = maxi(1, attacker.atk + attack_bonus - defender.defense - defense_bonus)
	var crit_damage: int = int(round(base_damage * 1.5))
	var can_counter: bool = defender.in_counter_range(distance, is_melee_attack)

	return {
		"hit_rate": hit_rate,
		"crit_rate": crit_rate,
		"base_damage": base_damage,
		"crit_damage": crit_damage,
		"can_counter": can_counter,
	}


func resolve_attack(attacker: UnitEntity, defender: UnitEntity, context: Dictionary = {}, rolls: Dictionary = {}) -> Dictionary:
	var pv: Dictionary = preview(attacker, defender, context)
	var hit_roll: int = int(rolls.get("hit_roll", 1))
	var crit_roll: int = int(rolls.get("crit_roll", 100))

	var hit_success: bool = hit_roll <= int(pv["hit_rate"])
	var crit_success: bool = hit_success and crit_roll <= int(pv["crit_rate"])
	var damage: int = 0
	if hit_success:
		damage = int(pv["crit_damage"]) if crit_success else int(pv["base_damage"])
		defender.apply_damage(damage)

	var counter_damage: int = 0
	var counter_hit: bool = false
	if bool(pv["can_counter"]) and defender.is_alive():
		var cpv: Dictionary = preview(defender, attacker, context)
		var counter_hit_roll: int = int(rolls.get("counter_hit_roll", 1))
		counter_hit = counter_hit_roll <= int(cpv["hit_rate"])
		if counter_hit:
			counter_damage = int(cpv["base_damage"])
			attacker.apply_damage(counter_damage)

	return {
		"hit_success": hit_success,
		"crit_success": crit_success,
		"damage": damage,
		"counter_hit": counter_hit,
		"counter_damage": counter_damage,
		"attacker_hp": attacker.hp,
		"defender_hp": defender.hp,
	}
