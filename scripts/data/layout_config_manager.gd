class_name LayoutConfigManager
extends RefCounted
## LayoutConfigManager — 布局配置管理
## 从 game_manager.gd 提取，负责 layout_config 字典、导入导出、文件读写、scale setter

const DEFAULT_LAYOUT_PATH := "res://data/default_layout.json"
const USER_LAYOUT_PATH := "user://layout.json"

var config: Dictionary = {}
var _emit_changed: Callable  # GameManager.layout_changed.emit


func setup(emit_changed: Callable) -> RefCounted:
	_emit_changed = emit_changed
	reset_config()
	return self


func reset_config() -> void:
	config = {
		"seats": TableLayout.DEFAULT_SEATS_PCT.duplicate(),
		"chairs": TableLayout.DEFAULT_CHAIRS_PCT.duplicate(),
		"cards": TableLayout.DEFAULT_CARDS_PCT.duplicate(),
		"stacks": TableLayout.DEFAULT_STACKS_PCT.duplicate(),
		"bets": TableLayout.DEFAULT_BETS_PCT.duplicate(),
		"dealer_buttons": TableLayout.DEFAULT_DEALER_BUTTONS_PCT.duplicate(),
		"pot": TableLayout.DEFAULT_POT_PCT,
		"muck": TableLayout.DEFAULT_MUCK_PCT,
		"community_cards": TableLayout.DEFAULT_COMMUNITY_CARDS_PCT,
		"avatar_scale": 2.4,
		"avatar_per_seat_scale": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
		"avatar_rotation": [180.0, 0.0, -37.0, 0.0, 0.0, -125.0, 76.0, 120.0, 126.0],
		"chair_scale": 0.95,
		"chair_rotation": [177.0, -133.0, -39.0, 0.0, 0.0, 0.0, 23.0, 136.0, 177.0],
		"dealer_button_scale": 1.0,
		"hole_card_scale": 0.55,
		"hole_card_gap": 0.6,
		"community_card_scale": 1.0,
		"muck_card_scale": 1.0,
		"bet_label_scale": 2.05,
		"stack_label_scale": 1.0,
		"pitch_hand": TableLayout.DEFAULT_PITCH_HAND_PCT,
		"pitch_hand_scale": 1.0,
		"pitch_hand_rotation": 0.0,
		"hole_card_rotation": TableLayout.DEFAULT_HOLE_CARD_ROTATION.duplicate(),
		"action_boxes": TableLayout.DEFAULT_ACTION_BOXES_PCT.duplicate(),
		"action_box_scale": 1.0,
		"answer_boxes": TableLayout.DEFAULT_ANSWER_BOXES_PCT.duplicate(),
		"answer_box_scale": 1.0,
		"player_chip_scale": 1.45,
		"bet_chip_scale": 1.0,
		"bet_chip_spread": 1.0,
		"pot_chip_scale": 1.0,
		"chip_record": TableLayout.DEFAULT_CHIP_RECORD_PCT,
		"chip_record_scale": 1.0,
		"purple_stacks": TableLayout._make_color_stack_defaults(0),
		"black_stacks": TableLayout._make_color_stack_defaults(1),
		"green_stacks": TableLayout._make_color_stack_defaults(2),
		"ordered_bet_chips": TableLayout.DEFAULT_ORDERED_BET_CHIPS_PCT.duplicate(),
		"ordered_bet_chip_scale": 1.0,
		"display_mode": "chips",
	}


func update_position(category: String, index: int, x: float, y: float) -> void:
	if index >= 0:
		var arr: Array = config[category]
		if arr and index < arr.size():
			arr[index] = Vector2(x, y)
	else:
		config[category] = Vector2(x, y)
	_emit_changed.call()


func get_position_px(category: String, index: int = -1) -> Vector2:
	var pct: Vector2
	if index >= 0:
		var arr: Array = config[category]
		pct = arr[index]
	else:
		pct = config[category]
	return TableLayout.pct_to_px(pct)


# --- Export / Import ---

func export_layout() -> String:
	var out := {}
	for key in config:
		var val = config[key]
		if val is Array:
			var arr := []
			for v in val:
				if v is Vector2:
					arr.append({"x": snapped(v.x, 0.01), "y": snapped(v.y, 0.01)})
				else:
					arr.append(v)
			out[key] = arr
		elif val is Vector2:
			out[key] = {"x": snapped(val.x, 0.01), "y": snapped(val.y, 0.01)}
		else:
			out[key] = val
	return JSON.stringify(out, "\t")


func import_layout(json_str: String) -> void:
	var parsed = JSON.parse_string(json_str)
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	for key in d:
		var val = d[key]
		if val is Array:
			var arr: Array = []
			for item in val:
				if item is Dictionary and item.has("x") and item.has("y"):
					arr.append(Vector2(item["x"], item["y"]))
				else:
					arr.append(item)
			config[key] = arr
		elif val is Dictionary and val.has("x") and val.has("y"):
			config[key] = Vector2(val["x"], val["y"])
		else:
			if key in ["hole_card_rotation", "avatar_rotation", "chair_rotation"] and (val is float or val is int):
				var arr: Array = []
				for _i in range(9):
					arr.append(val)
				config[key] = arr
			else:
				config[key] = val
	_emit_changed.call()


# --- File I/O ---

func save_to_file() -> bool:
	var json := export_layout()
	var file := FileAccess.open(USER_LAYOUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		return true
	return false


func load_from_file() -> bool:
	var loaded := false
	if FileAccess.file_exists(USER_LAYOUT_PATH):
		var file := FileAccess.open(USER_LAYOUT_PATH, FileAccess.READ)
		if file:
			var json := file.get_as_text()
			file.close()
			import_layout(json)
			loaded = true
	if not loaded:
		loaded = _load_default()
	return loaded


func _load_default() -> bool:
	if not FileAccess.file_exists(DEFAULT_LAYOUT_PATH):
		return false
	var file := FileAccess.open(DEFAULT_LAYOUT_PATH, FileAccess.READ)
	if file:
		var json := file.get_as_text()
		file.close()
		import_layout(json)
		return true
	return false


func reset_layout() -> void:
	reset_config()
	_load_default()
	if FileAccess.file_exists(USER_LAYOUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_LAYOUT_PATH))
	_emit_changed.call()


# --- Scale setters (all emit layout_changed) ---

func set_scale(key: String, value: float) -> void:
	config[key] = value
	_emit_changed.call()
