extends Node2D

const BattleStateRef = preload("res://scripts/core/BattleState.gd")
const GridServiceRef = preload("res://scripts/core/GridService.gd")
const BattleControllerRef = preload("res://scripts/core/BattleController.gd")

const CELL_SIZE: int = 64
const MIN_GRID_SIZE: int = 4
const MAX_GRID_SIZE: int = 40

@onready var status_label: Label = $UI/StatusLabel
@onready var camera_2d: Camera2D = $Camera2D
@onready var hint_label: Label = $UI/HintLabel
@onready var preview_label: Label = $UI/PreviewLabel
@onready var move_cost_check: CheckButton = $UI/MoveCostCheck
@onready var grid_size_input: LineEdit = $UI/GridSizeInput
@onready var apply_grid_button: Button = $UI/ApplyGridButton
@onready var heatmap_option: OptionButton = $UI/HeatmapOption
@onready var zoom_lock_check: CheckButton = $UI/ZoomLockCheck
@onready var zoom_input: LineEdit = $UI/ZoomInput
@onready var inspect_title_label: Label = $UI/InspectPanel/VBox/InspectTitle
@onready var inspect_detail_label: Label = $UI/InspectPanel/VBox/InspectDetail
@onready var inspect_history_box: RichTextLabel = $UI/InspectPanel/VBox/InspectHistory
@onready var set_baseline_button: Button = $UI/InspectPanel/VBox/CompareButtons/SetBaselineButton
@onready var clear_baseline_button: Button = $UI/InspectPanel/VBox/CompareButtons/ClearBaselineButton
@onready var move_button: Button = $UI/ActionPanel/HBox/MoveButton
@onready var attack_button: Button = $UI/ActionPanel/HBox/AttackButton
@onready var wait_button: Button = $UI/ActionPanel/HBox/WaitButton
@onready var end_turn_button: Button = $UI/ActionPanel/HBox/EndTurnButton

var battle_state
var selected_unit_id: StringName = &""
var reachable_cells: Array[Vector2i] = []

enum ActionMode {
	NONE,
	MOVE,
	ATTACK,
}

var action_mode: ActionMode = ActionMode.NONE
var pending_target_id: StringName = &""
var is_animating: bool = false
var unit_visual_positions: Dictionary = {}
var show_move_cost_numbers: bool = true
var inspect_history: Array[String] = []
var baseline_unit_id: StringName = &""
var last_inspected_unit_id: StringName = &""
var player_piece_texture: Texture2D
var enemy_piece_texture: Texture2D
var selected_piece_texture: Texture2D
var grid_w: int = 8
var grid_h: int = 6
var zoom_locked: bool = false
var locked_zoom: float = 1.0

enum HeatmapMode {
	NONE,
	MOVE_COST,
	REACHABLE,
	DANGER,
}

var heatmap_mode: HeatmapMode = HeatmapMode.NONE


func _ready() -> void:
	player_piece_texture = _create_pixel_piece_texture(Color(0.25, 0.55, 1.0), Color(0.9, 0.95, 1.0))
	enemy_piece_texture = _create_pixel_piece_texture(Color(0.9, 0.35, 0.35), Color(1.0, 0.9, 0.9))
	selected_piece_texture = _create_pixel_piece_texture(Color(1.0, 0.8, 0.2), Color(1.0, 0.95, 0.7))
	move_cost_check.toggled.connect(_on_move_cost_toggled)
	apply_grid_button.pressed.connect(_on_apply_grid_size_pressed)
	zoom_lock_check.toggled.connect(_on_zoom_lock_toggled)
	zoom_input.text_submitted.connect(_on_zoom_input_submitted)
	heatmap_option.item_selected.connect(_on_heatmap_selected)
	heatmap_option.clear()
	heatmap_option.add_item("热力层: 关闭", HeatmapMode.NONE)
	heatmap_option.add_item("热力层: 移动代价", HeatmapMode.MOVE_COST)
	heatmap_option.add_item("热力层: 可达区", HeatmapMode.REACHABLE)
	heatmap_option.add_item("热力层: 危险区", HeatmapMode.DANGER)
	heatmap_option.select(0)
	set_baseline_button.pressed.connect(_on_set_baseline_pressed)
	clear_baseline_button.pressed.connect(_on_clear_baseline_pressed)
	move_button.pressed.connect(_on_move_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	wait_button.pressed.connect(_on_wait_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	grid_size_input.text = "%d*%d" % [grid_w, grid_h]
	move_cost_check.button_pressed = show_move_cost_numbers
	zoom_lock_check.button_pressed = zoom_locked
	zoom_input.text = "%.2f" % locked_zoom
	inspect_title_label.text = "右键信息"
	inspect_detail_label.text = "右键单位或地块查看详情"
	inspect_history_box.clear()
	_initialize_battle(grid_w, grid_h)


func _draw() -> void:
	if battle_state == null:
		return
	_draw_grid()
	_draw_reachable_cells()
	_draw_units()


func _unhandled_input(event: InputEvent) -> void:
	if battle_state == null:
		return
	if is_animating:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and battle_state.controller.phase == BattleControllerRef.Phase.PLAYER_TURN:
			_end_player_turn()
			return

	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed:
		return

	var cell: Vector2i = _screen_to_cell(mouse_event.position)
	if not battle_state.grid.is_in_bounds(cell):
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_show_inspect_info(cell)
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if battle_state.controller.phase != BattleControllerRef.Phase.PLAYER_TURN:
		return

	var clicked_id: StringName = battle_state.get_unit_at(cell)
	if clicked_id != &"":
		var unit = battle_state.get_unit(clicked_id)
		if unit == null:
			return
		if String(unit.camp) == "player":
			_select_player_unit(clicked_id)
			return
		if selected_unit_id != &"" and action_mode == ActionMode.ATTACK:
			_handle_attack_click(clicked_id)
			return

	if selected_unit_id != &"" and action_mode == ActionMode.MOVE:
		var move_path: Array[Vector2i] = battle_state.find_movement_path(selected_unit_id, cell)
		if move_path.size() > 1:
			await _animate_unit_path(selected_unit_id, move_path, 0.5)
			if battle_state.move_unit(selected_unit_id, cell):
				_sync_visual_positions()
				reachable_cells.clear()
				action_mode = ActionMode.NONE
				pending_target_id = &""
				_update_labels("已移动。请选择 Attack 或 Wait")
				_update_action_buttons()
				queue_redraw()
			else:
				_sync_visual_positions()
				_update_labels("该格不可移动或本单位已移动")
		elif move_path.size() == 1 and move_path[0] == battle_state.get_position(selected_unit_id):
			reachable_cells.clear()
			action_mode = ActionMode.NONE
			pending_target_id = &""
			_update_labels("位置未变化。请选择 Attack 或 Wait")
			_update_action_buttons()
			queue_redraw()
		else:
			_update_labels("该格不可移动或本单位已移动")


func _select_player_unit(unit_id: StringName) -> void:
	if not battle_state.can_player_act(unit_id):
		_update_labels("该单位本回合不可行动")
		return
	selected_unit_id = unit_id
	action_mode = ActionMode.NONE
	pending_target_id = &""
	reachable_cells.clear()
	preview_label.text = ""
	_update_labels("已选中 %s：请选择 Move / Attack / Wait" % [String(unit_id)])
	_update_action_buttons()
	queue_redraw()


func _end_player_turn() -> void:
	selected_unit_id = &""
	action_mode = ActionMode.NONE
	pending_target_id = &""
	reachable_cells.clear()
	preview_label.text = ""
	var logs: Array[Dictionary] = battle_state.end_player_turn_and_run_enemy()
	await _play_enemy_logs(logs)
	_sync_visual_positions()
	if logs.is_empty():
		_update_labels("敌方回合结束，轮到我方")
	else:
		_update_labels("敌方执行了 %d 次行动，轮到我方" % logs.size())
	_update_action_buttons()
	_check_end_state()
	queue_redraw()


func _on_move_pressed() -> void:
	if selected_unit_id == &"":
		_update_labels("请先选择一个我方单位")
		return
	action_mode = ActionMode.MOVE
	pending_target_id = &""
	reachable_cells = battle_state.get_reachable_cells(selected_unit_id)
	preview_label.text = ""
	_update_labels("Move模式：点击蓝色可达格移动")
	_update_action_buttons()
	queue_redraw()


func _on_attack_pressed() -> void:
	if selected_unit_id == &"":
		_update_labels("请先选择一个我方单位")
		return
	action_mode = ActionMode.ATTACK
	pending_target_id = &""
	reachable_cells.clear()
	preview_label.text = "Attack模式：点击敌人查看预览，再次点击同一目标确认攻击"
	_update_labels("Attack模式已开启")
	_update_action_buttons()
	queue_redraw()


func _on_wait_pressed() -> void:
	if selected_unit_id == &"":
		_update_labels("请先选择一个我方单位")
		return
	if battle_state.wait_unit(selected_unit_id):
		selected_unit_id = &""
		action_mode = ActionMode.NONE
		pending_target_id = &""
		reachable_cells.clear()
		preview_label.text = ""
		_update_labels("单位待机完成")
		_update_action_buttons()
		queue_redraw()


func _on_end_turn_pressed() -> void:
	if battle_state.controller.phase == BattleControllerRef.Phase.PLAYER_TURN:
		_end_player_turn()


func _handle_attack_click(enemy_id: StringName) -> void:
	if selected_unit_id == &"":
		return
	var preview: Dictionary = battle_state.preview_attack(selected_unit_id, enemy_id)
	if not bool(preview.get("ok", false)):
		pending_target_id = &""
		preview_label.text = "目标不可攻击"
		return

	if pending_target_id != enemy_id:
		pending_target_id = enemy_id
		preview_label.text = "预览 %s→%s | 命中:%d%% 暴击:%d%% 伤害:%d(暴击:%d) 反击:%s\n再次点击同一目标以确认攻击" % [
			String(selected_unit_id),
			String(enemy_id),
			int(preview.get("hit_rate", 0)),
			int(preview.get("crit_rate", 0)),
			int(preview.get("base_damage", 0)),
			int(preview.get("crit_damage", 0)),
			"是" if bool(preview.get("can_counter", false)) else "否"
		]
		return

	var outcome: Dictionary = battle_state.attack(selected_unit_id, enemy_id, {"hit_roll": 1, "crit_roll": 100, "counter_hit_roll": 1})
	if bool(outcome.get("ok", false)):
		preview_label.text = "攻击结果：造成%d，反击%d" % [int(outcome.get("damage", 0)), int(outcome.get("counter_damage", 0))]
		selected_unit_id = &""
		action_mode = ActionMode.NONE
		pending_target_id = &""
		reachable_cells.clear()
		_update_labels("攻击完成，可继续操作其他单位或结束回合")
		_update_action_buttons()
		_check_end_state()
		queue_redraw()


func _update_action_buttons() -> void:
	var can_use_unit: bool = selected_unit_id != &"" and battle_state != null and battle_state.can_player_act(selected_unit_id)
	var can_move: bool = can_use_unit and not battle_state.has_moved(selected_unit_id)
	move_button.disabled = is_animating or not can_move
	attack_button.disabled = is_animating or not can_use_unit
	wait_button.disabled = is_animating or not can_use_unit
	end_turn_button.disabled = is_animating or battle_state == null or battle_state.controller.phase != BattleControllerRef.Phase.PLAYER_TURN


func _check_end_state() -> void:
	match battle_state.controller.phase:
		BattleControllerRef.Phase.VICTORY:
			_update_labels("胜利！敌方全灭")
		BattleControllerRef.Phase.DEFEAT:
			_update_labels("失败！我方全灭")


func _draw_grid() -> void:
	for y in range(grid_h):
		for x in range(grid_w):
			var rect := Rect2(Vector2(x * CELL_SIZE, y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
			var cell := Vector2i(x, y)
			var terrain_id: String = battle_state.grid.get_terrain(Vector2i(x, y))
			var color: Color = _terrain_color(terrain_id)
			draw_rect(rect, color, true)
			var heat_color: Color = _get_heat_color(cell)
			if heat_color.a > 0.0:
				draw_rect(rect, heat_color, true)
			draw_rect(rect, Color(0, 0, 0, 0.4), false, 1.0)
			if ThemeDB.fallback_font != null:
				draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, 16), _terrain_short_label(terrain_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.95, 0.95, 0.9))
				if show_move_cost_numbers:
					var move_cost: int = battle_state.grid.get_move_cost(Vector2i(x, y))
					draw_string(ThemeDB.fallback_font, rect.position + Vector2(CELL_SIZE - 16, 16), str(move_cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.95, 0.35, 0.95))


func _draw_reachable_cells() -> void:
	for cell in reachable_cells:
		var rect := Rect2(Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(rect, Color(0.3, 0.6, 1.0, 0.35), true)


func _draw_units() -> void:
	for unit_id in battle_state.positions.keys():
		var unit = battle_state.get_unit(unit_id)
		if unit == null or not unit.is_alive():
			continue
		var center: Vector2 = unit_visual_positions.get(unit_id, _cell_center(battle_state.get_position(unit_id)))
		var piece_texture: Texture2D = player_piece_texture if String(unit.camp) == "player" else enemy_piece_texture
		if unit_id == selected_unit_id:
			piece_texture = selected_piece_texture
		if piece_texture != null:
			var icon_rect := Rect2(center - Vector2(16, 16), Vector2(32, 32))
			draw_texture_rect(piece_texture, icon_rect, false)
		else:
			draw_circle(center, 18.0, Color.SKY_BLUE if String(unit.camp) == "player" else Color.INDIAN_RED)
		if ThemeDB.fallback_font != null:
			draw_string(ThemeDB.fallback_font, center + Vector2(-20, 30), "%s(%d)" % [String(unit_id), int(unit.hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _terrain_color(terrain_id: String) -> Color:
	match terrain_id:
		"forest":
			return Color(0.22, 0.42, 0.22)
		"mountain":
			return Color(0.42, 0.38, 0.35)
		"city":
			return Color(0.45, 0.45, 0.52)
		"shoal":
			return Color(0.52, 0.55, 0.38)
		"wall":
			return Color(0.1, 0.1, 0.1)
		_:
			return Color(0.27, 0.5, 0.27)


func _terrain_short_label(terrain_id: String) -> String:
	match terrain_id:
		"plain":
			return "平"
		"forest":
			return "林"
		"mountain":
			return "山"
		"city":
			return "城"
		"shoal":
			return "滩"
		"wall":
			return "墙"
		_:
			return "?"


func _screen_to_cell(_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = to_local(get_global_mouse_position())
	return Vector2i(int(local_pos.x / CELL_SIZE), int(local_pos.y / CELL_SIZE))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5)


func _build_default_terrain(grid) -> void:
	for y in range(grid_h):
		for x in range(grid_w):
			grid.set_terrain(Vector2i(x, y), &"plain")

	# 放一些地形修正示例
	if grid.is_in_bounds(Vector2i(2, 2)):
		grid.set_terrain(Vector2i(2, 2), &"forest")
	if grid.is_in_bounds(Vector2i(3, 2)):
		grid.set_terrain(Vector2i(3, 2), &"forest")
	if grid.is_in_bounds(Vector2i(4, 3)):
		grid.set_terrain(Vector2i(4, 3), &"mountain")
	if grid.is_in_bounds(Vector2i(5, 1)):
		grid.set_terrain(Vector2i(5, 1), &"city")


func _default_units() -> Array[Dictionary]:
	return [
		{"unit_id": "P1", "camp": "player", "hp": 110, "max_hp": 110, "atk": 34, "defense": 12, "hit": 90, "avoid": 8, "crit": 10, "move_points": 4, "counter_range": 1},
		{"unit_id": "P2", "camp": "player", "hp": 95, "max_hp": 95, "atk": 30, "defense": 10, "hit": 88, "avoid": 10, "crit": 12, "move_points": 5, "counter_range": 1},
		{"unit_id": "E1", "camp": "enemy", "hp": 90, "max_hp": 90, "atk": 26, "defense": 8, "hit": 82, "avoid": 5, "crit": 6, "move_points": 4, "counter_range": 1},
		{"unit_id": "E2", "camp": "enemy", "hp": 100, "max_hp": 100, "atk": 28, "defense": 9, "hit": 85, "avoid": 6, "crit": 8, "move_points": 4, "counter_range": 1},
	]


func _default_positions() -> Dictionary:
	var right_col: int = maxi(1, grid_w - 2)
	var y_low: int = mini(1, grid_h - 1)
	var y_high: int = mini(3, grid_h - 1)
	return {
		&"P1": Vector2i(1, y_low),
		&"P2": Vector2i(1, y_high),
		&"E1": Vector2i(right_col, y_low),
		&"E2": Vector2i(right_col, y_high),
	}


func _update_labels(msg: String) -> void:
	var phase_text: String = "未知"
	match battle_state.controller.phase:
		BattleControllerRef.Phase.PLAYER_TURN:
			phase_text = "我方回合"
		BattleControllerRef.Phase.ENEMY_TURN:
			phase_text = "敌方回合"
		BattleControllerRef.Phase.VICTORY:
			phase_text = "胜利"
		BattleControllerRef.Phase.DEFEAT:
			phase_text = "失败"
	status_label.text = "阶段: %s | 我方:%d 敌方:%d" % [phase_text, battle_state.player_units_alive().size(), battle_state.enemy_units_alive().size()]
	hint_label.text = "%s\n操作：左键选中单位；使用按钮 Move/Attack/Wait；Space 或 EndTurn 结束回合" % msg


func _sync_visual_positions() -> void:
	unit_visual_positions.clear()
	for unit_id in battle_state.positions.keys():
		unit_visual_positions[unit_id] = _cell_center(battle_state.get_position(unit_id))


func _animate_unit_path(unit_id: StringName, path: Array[Vector2i], sec_per_cell: float) -> void:
	if path.size() <= 1:
		return
	is_animating = true
	_update_action_buttons()
	for i in range(1, path.size()):
		var from_pos: Vector2 = unit_visual_positions.get(unit_id, _cell_center(path[i - 1]))
		var to_pos: Vector2 = _cell_center(path[i])
		var tween := create_tween()
		tween.tween_method(Callable(self, "_set_unit_visual_position").bind(unit_id), from_pos, to_pos, sec_per_cell)
		await tween.finished
	is_animating = false
	_update_action_buttons()


func _play_enemy_logs(logs: Array[Dictionary]) -> void:
	if logs.is_empty():
		return
	is_animating = true
	_update_action_buttons()
	for log_item in logs:
		if String(log_item.get("type", "")) == "enemy_move":
			var unit_id: StringName = log_item.get("unit", &"")
			var from_cell: Vector2i = log_item.get("from", battle_state.get_position(unit_id))
			var to_cell: Vector2i = log_item.get("to", from_cell)
			var tween := create_tween()
			tween.tween_method(Callable(self, "_set_unit_visual_position").bind(unit_id), _cell_center(from_cell), _cell_center(to_cell), 0.5)
			await tween.finished
	is_animating = false
	_update_action_buttons()


func _set_unit_visual_position(pos: Vector2, unit_id: StringName) -> void:
	unit_visual_positions[unit_id] = pos
	queue_redraw()


func _show_inspect_info(cell: Vector2i) -> void:
	var unit_id: StringName = battle_state.get_unit_at(cell)
	if unit_id != &"":
		var unit = battle_state.get_unit(unit_id)
		if unit != null:
			last_inspected_unit_id = unit_id
			var unit_info: String = _format_unit_info(unit_id)
			inspect_title_label.text = "右键信息：单位"
			inspect_detail_label.text = unit_info
			_append_inspect_history("单位 %s @ %s" % [String(unit_id), str(cell)])
			_update_compare_buttons()
			return
	last_inspected_unit_id = &""
	var terrain_id: String = battle_state.grid.get_terrain(cell)
	var terrain_def: Dictionary = battle_state.grid.terrain_defs.get(terrain_id, {})
	var tile_info: String = "地块 %s (%s) @ %s\n移动消耗:%d | 可通行:%s | 标签:%s" % [
		_terrain_short_label(terrain_id), terrain_id, str(cell), int(terrain_def.get("move_cost", 99)), "是" if bool(terrain_def.get("passable", false)) else "否", str(terrain_def.get("tags", []))
	]
	inspect_title_label.text = "右键信息：地块"
	inspect_detail_label.text = tile_info
	_append_inspect_history("地块 %s(%s) @ %s" % [_terrain_short_label(terrain_id), terrain_id, str(cell)])
	_update_compare_buttons()


func _append_inspect_history(line: String) -> void:
	inspect_history.append(line)
	if inspect_history.size() > 30:
		inspect_history.remove_at(0)
	inspect_history_box.clear()
	for item in inspect_history:
		inspect_history_box.append_text(item + "\n")
	inspect_history_box.scroll_to_line(maxi(0, inspect_history_box.get_line_count() - 1))


func _on_move_cost_toggled(pressed: bool) -> void:
	show_move_cost_numbers = pressed
	queue_redraw()


func _on_zoom_lock_toggled(pressed: bool) -> void:
	zoom_locked = pressed
	if zoom_locked:
		_on_zoom_input_submitted(zoom_input.text)
	elif not zoom_locked:
		_fit_camera_to_grid()


func _on_zoom_input_submitted(text: String) -> void:
	var value: float = text.to_float()
	if value > 0.0:
		locked_zoom = clampf(value, 0.1, 5.0)
		zoom_input.text = "%.2f" % locked_zoom
		if zoom_locked and camera_2d != null:
			camera_2d.zoom = Vector2(locked_zoom, locked_zoom)


func _on_apply_grid_size_pressed() -> void:
	var parsed: Vector2i = _parse_grid_size_text(grid_size_input.text)
	if parsed.x <= 0 or parsed.y <= 0:
		_update_labels("地块数量格式错误，请输入 n*m，例如 12*8")
		return
	_initialize_battle(parsed.x, parsed.y)


func _parse_grid_size_text(raw: String) -> Vector2i:
	var normalized: String = raw.strip_edges().to_lower().replace("×", "*").replace("x", "*")
	var parts: PackedStringArray = normalized.split("*", false)
	if parts.size() != 2:
		return Vector2i(-1, -1)
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	var w: int = clampi(int(parts[0]), MIN_GRID_SIZE, MAX_GRID_SIZE)
	var h: int = clampi(int(parts[1]), MIN_GRID_SIZE, MAX_GRID_SIZE)
	return Vector2i(w, h)


func _initialize_battle(width: int, height: int) -> void:
	grid_w = clampi(width, MIN_GRID_SIZE, MAX_GRID_SIZE)
	grid_h = clampi(height, MIN_GRID_SIZE, MAX_GRID_SIZE)
	grid_size_input.text = "%d*%d" % [grid_w, grid_h]

	selected_unit_id = &""
	action_mode = ActionMode.NONE
	pending_target_id = &""
	reachable_cells.clear()
	preview_label.text = ""
	baseline_unit_id = &""
	last_inspected_unit_id = &""
	inspect_title_label.text = "右键信息"
	inspect_detail_label.text = "右键单位或地块查看详情"

	var grid = GridServiceRef.new(grid_w, grid_h)
	_build_default_terrain(grid)
	battle_state = BattleStateRef.new(grid)
	battle_state.setup_battle(_default_units(), _default_positions())
	_sync_visual_positions()
	_fit_camera_to_grid()
	_update_compare_buttons()
	_update_action_buttons()
	_update_labels("战斗开始：选择我方单位")
	queue_redraw()


func _on_viewport_size_changed() -> void:
	if not zoom_locked:
		_fit_camera_to_grid()


func _fit_camera_to_grid() -> void:
	if camera_2d == null:
		return
	var world_size := Vector2(grid_w * CELL_SIZE, grid_h * CELL_SIZE)
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return

	camera_2d.position = world_size * 0.5
	camera_2d.limit_left = 0
	camera_2d.limit_top = 0
	camera_2d.limit_right = int(world_size.x)
	camera_2d.limit_bottom = int(world_size.y)

	if zoom_locked:
		camera_2d.zoom = Vector2(locked_zoom, locked_zoom)
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var fit_scale: float = minf(viewport_size.x / world_size.x, viewport_size.y / world_size.y)
	fit_scale = clampf(fit_scale, 0.2, 1.0)
	camera_2d.zoom = Vector2(fit_scale, fit_scale)


func _on_heatmap_selected(index: int) -> void:
	var item_id: int = heatmap_option.get_item_id(index)
	heatmap_mode = item_id
	queue_redraw()


func _get_heat_color(cell: Vector2i) -> Color:
	match heatmap_mode:
		HeatmapMode.MOVE_COST:
			var cost: int = battle_state.grid.get_move_cost(cell)
			var t: float = clampf(float(cost) / 4.0, 0.0, 1.0)
			return Color(1.0, 1.0 - t * 0.65, 0.2, 0.22)
		HeatmapMode.REACHABLE:
			if selected_unit_id != &"" and battle_state.get_reachable_cells(selected_unit_id).has(cell):
				return Color(0.2, 0.7, 1.0, 0.24)
			return Color(0, 0, 0, 0)
		HeatmapMode.DANGER:
			if _is_in_enemy_threat(cell):
				return Color(1.0, 0.2, 0.2, 0.22)
			return Color(0, 0, 0, 0)
		_:
			return Color(0, 0, 0, 0)


func _is_in_enemy_threat(cell: Vector2i) -> bool:
	for enemy_id in battle_state.enemy_units_alive():
		var enemy = battle_state.get_unit(enemy_id)
		if enemy == null:
			continue
		var enemy_pos: Vector2i = battle_state.get_position(enemy_id)
		var d: int = absi(enemy_pos.x - cell.x) + absi(enemy_pos.y - cell.y)
		if d >= int(enemy.attack_range_min) and d <= int(enemy.attack_range_max):
			return true
	return false


func _format_unit_info(unit_id: StringName) -> String:
	var unit = battle_state.get_unit(unit_id)
	if unit == null:
		return "单位不存在"
	var text: String = "单位 %s (%s)\nHP %d/%d | 攻%d 防%d | 命中%d 闪避%d 暴击%d | 移动%d" % [
		String(unit_id), String(unit.camp), int(unit.hp), int(unit.max_hp), int(unit.atk), int(unit.defense), int(unit.hit), int(unit.avoid), int(unit.crit), int(unit.move_points)
	]
	if baseline_unit_id != &"" and baseline_unit_id != unit_id:
		var base_unit = battle_state.get_unit(baseline_unit_id)
		if base_unit != null:
			text += "\n\n对比基准: %s\n" % String(baseline_unit_id)
			text += "HP %+d | 攻 %+d | 防 %+d | 命中 %+d | 闪避 %+d | 暴击 %+d | 移动 %+d" % [
				int(unit.max_hp) - int(base_unit.max_hp),
				int(unit.atk) - int(base_unit.atk),
				int(unit.defense) - int(base_unit.defense),
				int(unit.hit) - int(base_unit.hit),
				int(unit.avoid) - int(base_unit.avoid),
				int(unit.crit) - int(base_unit.crit),
				int(unit.move_points) - int(base_unit.move_points),
			]
	return text


func _on_set_baseline_pressed() -> void:
	if last_inspected_unit_id == &"":
		return
	baseline_unit_id = last_inspected_unit_id
	_append_inspect_history("设置对比基准: %s" % String(baseline_unit_id))
	inspect_detail_label.text = _format_unit_info(last_inspected_unit_id)
	_update_compare_buttons()


func _on_clear_baseline_pressed() -> void:
	if baseline_unit_id == &"":
		return
	_append_inspect_history("清除对比基准: %s" % String(baseline_unit_id))
	baseline_unit_id = &""
	if last_inspected_unit_id != &"":
		inspect_detail_label.text = _format_unit_info(last_inspected_unit_id)
	_update_compare_buttons()


func _update_compare_buttons() -> void:
	set_baseline_button.disabled = last_inspected_unit_id == &""
	clear_baseline_button.disabled = baseline_unit_id == &""


func _create_pixel_piece_texture(base_color: Color, detail_color: Color) -> Texture2D:
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(16):
		for x in range(16):
			if x == 0 or y == 0 or x == 15 or y == 15:
				image.set_pixel(x, y, Color(0, 0, 0, 0.85))
			elif x >= 3 and x <= 12 and y >= 3 and y <= 12:
				image.set_pixel(x, y, base_color)
			if x >= 6 and x <= 9 and y >= 5 and y <= 6:
				image.set_pixel(x, y, detail_color)
			if x >= 5 and x <= 10 and y >= 9 and y <= 11:
				image.set_pixel(x, y, detail_color.darkened(0.2))
	var texture := ImageTexture.create_from_image(image)
	return texture
