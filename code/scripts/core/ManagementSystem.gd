class_name ManagementSystem
extends RefCounted

const ACTIONS: Array[String] = [
	"recruit",
	"reforge",
	"unlock_passive",
	"buy_supply",
	"scout",
]

var max_actions_per_node: int = 3


func default_state() -> Dictionary:
	return {
		"gold": 300,
		"supplies": 2,
		"intel_level": 0,
		"actions_left": max_actions_per_node,
		"units": 4,
		"passives": 0,
	}


func list_actions() -> Array[String]:
	var copied: Array[String] = []
	for action_name in ACTIONS:
		copied.append(action_name)
	return copied


func apply_action(state: Dictionary, action_name: String) -> Dictionary:
	if not ACTIONS.has(action_name):
		return {"ok": false, "reason": "unknown_action"}
	if int(state.get("actions_left", 0)) <= 0:
		return {"ok": false, "reason": "no_actions_left"}

	state["actions_left"] = int(state.get("actions_left", 0)) - 1
	match action_name:
		"recruit":
			state["gold"] = int(state.get("gold", 0)) - 120
			state["units"] = int(state.get("units", 0)) + 1
		"reforge":
			state["gold"] = int(state.get("gold", 0)) - 80
		"unlock_passive":
			state["gold"] = int(state.get("gold", 0)) - 100
			state["passives"] = int(state.get("passives", 0)) + 1
		"buy_supply":
			state["gold"] = int(state.get("gold", 0)) - 50
			state["supplies"] = int(state.get("supplies", 0)) + 1
		"scout":
			state["intel_level"] = int(state.get("intel_level", 0)) + 1

	return {"ok": true, "reason": "applied", "state": state}
