class_name LayoutSliderBuilder
extends RefCounted
## LayoutSliderBuilder — 布局面板滑块构建器（数据驱动）

signal display_mode_changed(mode: String)
signal blinds_mode_changed(mode: String)

var _sliders: Dictionary = {}
var _numbers_rows: Array[Control] = []
var _chips_rows: Array[Control] = []
var _display_mode: String = "numbers"
var _blinds_mode: String = "25/50"
var _visibility_manager: RefCounted = null

# Toggle button refs
var _display_btns: Array[Button] = []
var _blinds_btns: Array[Button] = []

# Slider config: [config_key, locale_key, element_key, min, max, default, group]
# group: "" = always visible, "numbers" = numbers mode, "chips" = chips mode
const SLIDER_DEFS: Array = [
	["dealer_button_scale", "dealer_button_label", "dealer_buttons", 0.5, 3.0, 1.0, ""],
	["hole_card_scale", "hole_cards_label", "hole_cards", 0.3, 3.0, 1.0, ""],
	["hole_card_gap", "hole_card_gap_label", "", 0.0, 1.5, 0.6, ""],
	["community_card_scale", "community_cards_label", "community_cards", 0.3, 3.0, 1.0, ""],
	["street_badge_scale", "street_badge_label", "street_badge", 0.5, 3.0, 1.0, ""],
	# --- display/blinds toggles inserted here ---
	["bet_label_scale", "bet_label_label", "bet_labels", 0.5, 3.0, 1.0, "numbers"],
	["stack_label_scale", "stack_label_label", "stack_labels", 0.5, 3.0, 1.0, "numbers"],
	["pot_display_scale", "pot_display_label", "pot_display", 0.5, 3.0, 1.0, "numbers"],
	["player_chip_scale", "player_chips_label", "player_chips", 0.3, 3.0, 1.0, "chips"],
	["bet_chip_scale", "bet_chips_label", "bet_chips", 0.3, 3.0, 1.0, "chips"],
	["bet_chip_spread", "bet_spread_label", "", 0.5, 3.0, 1.0, "chips"],
	["pot_chip_scale", "pot_chips_label", "pot_chips", 0.3, 3.0, 1.0, "chips"],
	["chip_record_scale", "chip_record_label", "chip_record", 0.3, 3.0, 1.0, "chips"],
	["ordered_bet_chip_scale", "ordered_chips_label", "ordered_bet_chips", 0.3, 3.0, 1.0, "chips"],
	["ordered_chip_v_gap", "ordered_chip_v_gap_label", "", 0.0, 20.0, 6.0, "chips"],
	["answer_box_scale", "answer_box_label", "answer_boxes", 0.5, 3.0, 1.0, ""],
	["action_box_scale", "action_box_label", "action_boxes", 0.5, 3.0, 1.0, ""],
]

const DISPLAY_MODES: Array = ["numbers", "chips"]
const BLINDS_MODES: Array = ["25/50", "5/10", "1/2", "1/2/5"]


func build_sliders(parent: VBoxContainer, visibility_manager: RefCounted) -> void:
	_visibility_manager = visibility_manager
	var toggles_inserted := false
	for def in SLIDER_DEFS:
		var config_key: String = def[0]
		var locale_key: String = def[1]
		var element_key: String = def[2]
		var min_val: float = def[3]
		var max_val: float = def[4]
		var default_val: float = def[5]
		var group: String = def[6]

		# Insert toggles before first grouped slider
		if not toggles_inserted and group != "":
			_build_display_mode_toggle(parent)
			_build_blinds_mode_toggle(parent)
			toggles_inserted = true

		var row_start: int = parent.get_child_count()
		var checkbox: CheckBox = null
		if element_key != "" and visibility_manager:
			checkbox = visibility_manager.create_element_checkbox(element_key)

		var label_width := 160.0 if element_key == "" else 120.0
		_sliders[config_key] = UiFactory.make_slider_row(
			parent, Locale.tr_key(locale_key), min_val, max_val,
			GameManager.layout_config.get(config_key, default_val),
			func(v: float) -> void: GameManager.set_layout_scale(config_key, v),
			label_width, 0.05, checkbox)

		if group == "numbers":
			_numbers_rows.append(parent.get_child(row_start))
		elif group == "chips":
			_chips_rows.append(parent.get_child(row_start))

	_apply_display_mode()


func sync_sliders() -> void:
	for def in SLIDER_DEFS:
		var key: String = def[0]
		var default_val: float = def[5]
		if _sliders.has(key):
			_sliders[key].value = GameManager.layout_config.get(key, default_val)
	_display_mode = GameManager.display_mode
	_blinds_mode = GameManager.blinds_mode
	_apply_display_mode()
	_update_display_styles()
	_update_blinds_styles()


func get_active_chip_slider() -> HSlider:
	return _sliders.get("player_chip_scale", null)


func get_display_mode() -> String:
	return _display_mode


# --- Toggle builders ---

func _build_display_mode_toggle(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	parent.add_child(sep)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	row.add_child(UiFactory.make_label(Locale.tr_key("display_mode_toggle")))

	_display_btns.clear()
	for mode in DISPLAY_MODES:
		var btn := UiFactory.make_toggle_btn(Locale.tr_key(mode + "_mode"))
		var m: String = mode  # capture
		btn.pressed.connect(func() -> void: _set_display_mode(m))
		row.add_child(btn)
		_display_btns.append(btn)
	_update_display_styles()


func _build_blinds_mode_toggle(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	row.add_child(UiFactory.make_label(Locale.tr_key("blinds_mode_toggle")))

	_blinds_btns.clear()
	for mode in BLINDS_MODES:
		var width := 100.0 if mode == "1/2" else 120.0
		var btn := UiFactory.make_toggle_btn(mode, width)
		var m: String = mode  # capture
		btn.pressed.connect(func() -> void: _set_blinds_mode(m))
		row.add_child(btn)
		_blinds_btns.append(btn)
	_update_blinds_styles()


func _set_display_mode(mode: String) -> void:
	if _display_mode == mode:
		return
	_display_mode = mode
	_apply_display_mode()
	_update_display_styles()
	display_mode_changed.emit(_display_mode)


func _set_blinds_mode(mode: String) -> void:
	if _blinds_mode == mode:
		return
	_blinds_mode = mode
	_update_blinds_styles()
	blinds_mode_changed.emit(_blinds_mode)


func _apply_display_mode() -> void:
	var is_numbers: bool = _display_mode == "numbers"
	for row in _numbers_rows:
		row.visible = is_numbers
	for row in _chips_rows:
		row.visible = not is_numbers
	if _visibility_manager:
		var hidden: Array[String] = []
		for def in SLIDER_DEFS:
			var element_key: String = def[2]
			var group: String = def[6]
			if element_key == "":
				continue
			if (group == "numbers" and not is_numbers) or (group == "chips" and is_numbers):
				hidden.append(element_key)
		_visibility_manager.set_hidden_keys(hidden)


func _update_display_styles() -> void:
	var idx := DISPLAY_MODES.find(_display_mode)
	UiFactory.apply_toggle_styles(_display_btns, idx)


func _update_blinds_styles() -> void:
	var idx := BLINDS_MODES.find(_blinds_mode)
	UiFactory.apply_toggle_styles(_blinds_btns, idx)
