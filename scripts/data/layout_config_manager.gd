class_name LayoutConfigManager
extends RefCounted
## LayoutConfigManager — 布局配置管理
## 负责 layout_config 字典、导入导出、文件读写、scale setter
## 支持按盲注模式（25/50 vs 5/10）分开保存手牌和筹码相关配置

const USER_LAYOUT_PATH := "user://layout.json"

# 按盲注模式分开保存的配置键
const MODE_KEYS: Array[String] = [
	"cards", "bets", "purple_stacks", "black_stacks", "green_stacks",
	"red_stacks_1", "red_stacks_2", "red_stacks_3", "ordered_bet_chips",
	"pot", "chip_record",
	"hole_card_scale", "hole_card_gap",
	"player_chip_scale", "bet_chip_scale", "bet_chip_spread",
	"pot_chip_scale", "chip_record_scale",
	"ordered_bet_chip_scale", "ordered_chip_v_gap",
]

var config: Dictionary = {}
var _emit_changed: Callable  # GameManager.layout_changed.emit
var _mode_configs: Dictionary = {}  # {"25/50": {...}, "5/10": {...}}
var _current_mode: String = "25/50"


func setup(emit_changed: Callable) -> RefCounted:
	_emit_changed = emit_changed
	reset_config()
	return self


func reset_config() -> void:
	config = _make_global_defaults()
	_mode_configs = {
		"25/50": _make_mode_defaults_2550(),
		"5/10": _make_mode_defaults_510(),
		"1/2": _make_mode_defaults(),
		"1/2/5": _make_mode_defaults(),
	}
	_current_mode = "25/50"
	_apply_mode_to_config()


## 切换盲注模式，保存当前模式配置并加载目标模式配置
func switch_mode(mode: String) -> void:
	if mode == _current_mode:
		return
	_save_mode_from_config()
	_current_mode = mode
	_apply_mode_to_config()
	_emit_changed.call()


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
	# 先同步当前模式的值回 _mode_configs
	_save_mode_from_config()

	var out := {}
	# 只导出全局键
	for key in config:
		if key in MODE_KEYS:
			continue
		var val = config[key]
		out[key] = _serialize_value(val)

	# 导出两套模式配置
	var mc := {}
	for mode_name in _mode_configs:
		var mode_out := {}
		for key in _mode_configs[mode_name]:
			mode_out[key] = _serialize_value(_mode_configs[mode_name][key])
		mc[mode_name] = mode_out
	out["mode_configs"] = mc
	out["current_mode"] = _current_mode

	return JSON.stringify(out, "\t")


func import_layout(json_str: String) -> void:
	var parsed = JSON.parse_string(json_str)
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed

	# 检查是否有新格式的 mode_configs
	var has_mode_configs: bool = d.has("mode_configs")

	if has_mode_configs:
		# 新格式：全局键写入 config，模式键从 mode_configs 读取
		for key in d:
			if key == "mode_configs" or key == "current_mode":
				continue
			config[key] = _deserialize_value(key, d[key])

		var mc: Dictionary = d["mode_configs"]
		for mode_name in mc:
			if not _mode_configs.has(mode_name):
				_mode_configs[mode_name] = _make_mode_defaults()
			var mode_data: Dictionary = mc[mode_name]
			for key in mode_data:
				_mode_configs[mode_name][key] = _deserialize_value(key, mode_data[key])

		if d.has("current_mode"):
			_current_mode = d["current_mode"]
	else:
		# 旧格式兼容：所有键都在顶层，当作 25/50 的配置
		for key in d:
			config[key] = _deserialize_value(key, d[key])
		# 把 MODE_KEYS 的值存为 25/50 配置
		for key in MODE_KEYS:
			if config.has(key):
				_mode_configs["25/50"][key] = _deep_duplicate(config[key])
		# 5/10, 1/2, 1/2/5 用默认值
		_mode_configs["5/10"] = _make_mode_defaults()
		_mode_configs["1/2"] = _make_mode_defaults()
		_mode_configs["1/2/5"] = _make_mode_defaults()

	_apply_mode_to_config()
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
	# 默认布局已硬编码在 reset_config() 中，无需读取文件
	reset_config()
	return true


func reset_layout() -> void:
	reset_config()
	if FileAccess.file_exists(USER_LAYOUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_LAYOUT_PATH))
	_emit_changed.call()


# --- Scale setters (all emit layout_changed) ---

func set_scale(key: String, value: float) -> void:
	config[key] = value
	_emit_changed.call()


# --- Internal helpers ---

## 构建全局默认配置（不含 MODE_KEYS）— 硬编码自 default_layout.json
func _make_global_defaults() -> Dictionary:
	return {
		"seats": TableLayout.DEFAULT_SEATS_PCT.duplicate(),
		"chairs": [
			Vector2(31.27, 82.37), Vector2(4.72, 70.45), Vector2(5.2, 16.62),
			Vector2(24.28, 3.56), Vector2(49.78, 3.75), Vector2(75.75, 3.56),
			Vector2(94.79, 13.46), Vector2(93.91, 73.99), Vector2(75.2, 82.58),
		],
		"stacks": TableLayout.DEFAULT_STACKS_PCT.duplicate(),
		"dealer_buttons": TableLayout.DEFAULT_DEALER_BUTTONS_PCT.duplicate(),
		"muck": TableLayout.DEFAULT_MUCK_PCT,
		"community_cards": TableLayout.DEFAULT_COMMUNITY_CARDS_PCT,
		"avatar_scale": 2.45,
		"avatar_per_seat_scale": [1.2, 1.3, 1.2, 0.9, 1.45, 1.25, 1.2, 1.3, 1.05],
		"avatar_rotation": [59.0, -130.0, -52.0, 153.0, 0.0, -44.0, 76.0, 135.0, 179.0],
		"chair_scale": 1.35,
		"chair_rotation": [175.0, -133.0, -39.0, 0.0, 0.0, 0.0, 23.0, 136.0, 177.0],
		"dealer_button_scale": 2.0,
		"community_card_scale": 1.4,
		"muck_card_scale": 1.0,
		"bet_label_scale": 1.65,
		"stack_label_scale": 1.2,
		"pot_display_scale": 2.65,
		"pitch_hand": TableLayout.DEFAULT_PITCH_HAND_PCT,
		"pitch_hand_scale": 1.0,
		"pitch_hand_rotation": 0.0,
		"hole_card_rotation": TableLayout.DEFAULT_HOLE_CARD_ROTATION.duplicate(),
		"action_boxes": TableLayout.DEFAULT_ACTION_BOXES_PCT.duplicate(),
		"action_box_scale": 0.65,
		"answer_boxes": [
			Vector2(30.36, 82.1), Vector2(11.2, 60.03), Vector2(12.96, 16.16),
			Vector2(27.86, 11.11), Vector2(51.05, 9.67), Vector2(72.18, 10.29),
			Vector2(91.76, 15.84), Vector2(90.66, 58.79), Vector2(73.1, 87.69),
		],
		"answer_box_scale": 1.15,
		"street_badge": TableLayout.DEFAULT_STREET_BADGE_PCT,
		"street_badge_scale": 2.65,
		"display_mode": "numbers",
	}


## 构建模式相关的默认配置（通用，用于 1/2 和 1/2/5）
func _make_mode_defaults() -> Dictionary:
	return {
		"cards": TableLayout.DEFAULT_CARDS_PCT.duplicate(),
		"bets": TableLayout.DEFAULT_BETS_PCT.duplicate(),
		"purple_stacks": TableLayout._make_color_stack_defaults(0),
		"black_stacks": TableLayout._make_color_stack_defaults(1),
		"green_stacks": TableLayout._make_color_stack_defaults(2),
		"red_stacks_1": TableLayout._make_color_stack_defaults(3),
		"red_stacks_2": TableLayout._make_color_stack_defaults(4),
		"red_stacks_3": TableLayout._make_color_stack_defaults(5),
		"ordered_bet_chips": TableLayout.DEFAULT_ORDERED_BET_CHIPS_PCT.duplicate(),
		"pot": TableLayout.DEFAULT_POT_PCT,
		"chip_record": TableLayout.DEFAULT_CHIP_RECORD_PCT,
		"hole_card_scale": 1.3,
		"hole_card_gap": 0.25,
		"player_chip_scale": 1.4,
		"bet_chip_scale": 1.7,
		"bet_chip_spread": 1.6,
		"pot_chip_scale": 0.95,
		"chip_record_scale": 0.85,
		"ordered_bet_chip_scale": 1.05,
		"ordered_chip_v_gap": 6.0,
	}


## 25/50 模式硬编码默认配置
func _make_mode_defaults_2550() -> Dictionary:
	return {
		"cards": TableLayout.DEFAULT_CARDS_PCT.duplicate(),
		"bets": TableLayout.DEFAULT_BETS_PCT.duplicate(),
		"purple_stacks": TableLayout._make_color_stack_defaults(0),
		"black_stacks": TableLayout._make_color_stack_defaults(1),
		"green_stacks": TableLayout._make_color_stack_defaults(2),
		"red_stacks_1": TableLayout._make_color_stack_defaults(3),
		"red_stacks_2": TableLayout._make_color_stack_defaults(4),
		"red_stacks_3": TableLayout._make_color_stack_defaults(5),
		"ordered_bet_chips": TableLayout.DEFAULT_ORDERED_BET_CHIPS_PCT.duplicate(),
		"pot": TableLayout.DEFAULT_POT_PCT,
		"chip_record": TableLayout.DEFAULT_CHIP_RECORD_PCT,
		"hole_card_scale": 1.3,
		"hole_card_gap": 0.25,
		"player_chip_scale": 1.3,
		"bet_chip_scale": 2.2,
		"bet_chip_spread": 1.6,
		"pot_chip_scale": 0.95,
		"chip_record_scale": 0.85,
		"ordered_bet_chip_scale": 1.65,
		"ordered_chip_v_gap": 6.0,
	}


## 5/10 模式硬编码默认配置
func _make_mode_defaults_510() -> Dictionary:
	return {
		"cards": [
			Vector2(38.84, 65.91), Vector2(11.08, 55.88), Vector2(14.08, 25.38),
			Vector2(25.37, 19.75), Vector2(50.96, 19.83), Vector2(76.21, 18.69),
			Vector2(86.91, 23.06), Vector2(86.57, 48.05), Vector2(72.19, 65.14),
		],
		"bets": [
			Vector2(30.73, 51.97), Vector2(20.7, 49.5), Vector2(18.65, 34.75),
			Vector2(33.36, 29.65), Vector2(56.91, 29.82), Vector2(70.0, 28.84),
			Vector2(79.95, 36.77), Vector2(79.37, 46.71), Vector2(70.47, 51.18),
		],
		"purple_stacks": TableLayout._make_color_stack_defaults(0),
		"black_stacks": [
			Vector2(32.09, 66.51), Vector2(19.8, 65.26), Vector2(11.82, 36.48),
			Vector2(32.24, 19.88), Vector2(57.73, 20.0), Vector2(68.57, 19.29),
			Vector2(86.58, 35.62), Vector2(84.52, 61.97), Vector2(74.85, 62.46),
		],
		"green_stacks": [
			Vector2(29.61, 66.81), Vector2(17.65, 64.49), Vector2(9.01, 36.19),
			Vector2(34.75, 19.88), Vector2(60.14, 19.81), Vector2(71.25, 18.9),
			Vector2(89.37, 36.97), Vector2(85.73, 58.98), Vector2(78.24, 64.19),
		],
		"red_stacks_1": [
			Vector2(24.47, 67.0), Vector2(12.45, 62.94), Vector2(9.35, 32.32),
			Vector2(29.72, 19.2), Vector2(55.54, 19.91), Vector2(66.32, 18.23),
			Vector2(87.32, 32.61), Vector2(86.95, 61.59), Vector2(77.22, 66.71),
		],
		"red_stacks_2": [
			Vector2(27.09, 67.09), Vector2(15.13, 63.32), Vector2(6.66, 36.77),
			Vector2(31.91, 16.79), Vector2(57.51, 17.39), Vector2(68.41, 15.23),
			Vector2(91.91, 35.52), Vector2(88.81, 57.04), Vector2(80.94, 65.55),
		],
		"red_stacks_3": [
			Vector2(25.7, 64.49), Vector2(13.9, 60.34), Vector2(7.22, 32.04),
			Vector2(33.88, 17.85), Vector2(59.49, 17.78), Vector2(69.89, 17.45),
			Vector2(89.43, 33.88), Vector2(88.39, 59.56), Vector2(79.05, 66.51),
		],
		"ordered_bet_chips": [
			Vector2(31.36, 46.95), Vector2(19.48, 42.08), Vector2(17.7, 25.37),
			Vector2(28.84, 25.68), Vector2(54.02, 26.05), Vector2(64.89, 25.86),
			Vector2(74.75, 26.22), Vector2(77.71, 41.5), Vector2(65.44, 44.61),
		],
		"pot": Vector2(36.91, 40.44),
		"chip_record": TableLayout.DEFAULT_CHIP_RECORD_PCT,
		"hole_card_scale": 1.3,
		"hole_card_gap": 0.25,
		"player_chip_scale": 1.45,
		"bet_chip_scale": 1.7,
		"bet_chip_spread": 1.65,
		"pot_chip_scale": 0.9,
		"chip_record_scale": 0.85,
		"ordered_bet_chip_scale": 1.05,
		"ordered_chip_v_gap": 5.95,
	}


## 从 config 中提取 MODE_KEYS 的值保存到 _mode_configs[_current_mode]
func _save_mode_from_config() -> void:
	if not _mode_configs.has(_current_mode):
		_mode_configs[_current_mode] = {}
	for key in MODE_KEYS:
		if config.has(key):
			_mode_configs[_current_mode][key] = _deep_duplicate(config[key])


## 从 _mode_configs[_current_mode] 中取出值写入 config
func _apply_mode_to_config() -> void:
	if not _mode_configs.has(_current_mode):
		_mode_configs[_current_mode] = _make_mode_defaults()
	var mc: Dictionary = _mode_configs[_current_mode]
	for key in MODE_KEYS:
		if mc.has(key):
			config[key] = _deep_duplicate(mc[key])


## 深拷贝值（Array 和 Vector2 需要拷贝，float/int/String 不需要）
func _deep_duplicate(val) -> Variant:
	if val is Array:
		var arr: Array = []
		for v in val:
			arr.append(v)  # Vector2 和 float 都是值类型，直接 append 即可
		return arr
	return val


## 序列化单个值用于 JSON 导出
func _serialize_value(val) -> Variant:
	if val is Array:
		var arr := []
		for v in val:
			if v is Vector2:
				arr.append({"x": snapped(v.x, 0.01), "y": snapped(v.y, 0.01)})
			else:
				arr.append(v)
		return arr
	elif val is Vector2:
		return {"x": snapped(val.x, 0.01), "y": snapped(val.y, 0.01)}
	return val


## 反序列化单个值用于 JSON 导入
func _deserialize_value(key: String, val) -> Variant:
	if val is Array:
		var arr: Array = []
		for item in val:
			if item is Dictionary and item.has("x") and item.has("y"):
				arr.append(Vector2(item["x"], item["y"]))
			else:
				arr.append(item)
		return arr
	elif val is Dictionary and val.has("x") and val.has("y"):
		return Vector2(val["x"], val["y"])
	elif key in ["hole_card_rotation", "avatar_rotation", "chair_rotation"] and (val is float or val is int):
		var arr: Array = []
		for _i in range(9):
			arr.append(val)
		return arr
	return val
