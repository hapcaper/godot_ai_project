class_name ScenarioRunner
extends RefCounted

const TOTAL_STAGES: int = 24

var current_stage: int = 1
var current_chapter: int = 1


func chapter_of_stage(stage: int) -> int:
	return int(((stage - 1) / 6) + 1)


func is_boss_stage(stage: int) -> bool:
	return stage % 6 == 0


func is_management_stage(stage: int) -> bool:
	return stage % 2 == 0 and not is_boss_stage(stage)


func is_run_complete() -> bool:
	return current_stage > TOTAL_STAGES


func advance_after_victory() -> Dictionary:
	var node_type: String = "battle"
	if is_boss_stage(current_stage):
		node_type = "merchant"
	elif is_management_stage(current_stage):
		node_type = "management"

	current_stage += 1
	if current_stage <= TOTAL_STAGES:
		current_chapter = chapter_of_stage(current_stage)

	if current_stage > TOTAL_STAGES:
		return {"node": "run_complete", "next_stage": current_stage, "next_chapter": current_chapter}

	return {"node": node_type, "next_stage": current_stage, "next_chapter": current_chapter}
