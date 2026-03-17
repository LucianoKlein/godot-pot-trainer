class_name LayoutVisibilityManager
extends RefCounted
## LayoutVisibilityManager — 布局编辑器可见性管理
## 管理元素可见性状态、复选框逻辑、显示/隐藏控制

signal visibility_changed(element_key: String, visible: bool)

var _element_visibility: Dictionary = {
	"hole_cards": true,
	"community_cards": true,
	"dealer_buttons": true,
	"bet_labels": true,
	"stack_labels": true,
	"pot_display": true,
	"answer_boxes": true,
	"action_boxes": true,
	"player_chips": true,
	"bet_chips": true,
	"pot_chips": true,
	"chip_record": true,
}

var _element_checkboxes: Dictionary = {}  # key: element_name, value: CheckBox
var _select_all_checkbox: CheckBox = null

# References to actual game UI elements
var _bet_labels: Array[Label]
var _stack_labels: Array[Label]
var _dealer_button: Control
var _pot_display: VBoxContainer
var _community_cards_container: HBoxContainer
var _purple_stacks: Array[Node2D]
var _black_stacks: Array[Node2D]
var _green_stacks: Array[Node2D]
var _player_bet_chips: Array[Control]
var _pot_chip_area: Control
var _chip_record: Control
var _action_boxes: Array[Label]

# Preview elements (managed externally, but we control visibility)
var _preview_hole_card_containers: Array = []
var _preview_comm_cards: Array = []
var _preview_dealer_buttons: Array[Control] = []
var _preview_answer_boxes: Array[Control] = []


func _init(refs: Dictionary) -> void:
	_bet_labels = refs.get("bet_labels", [])
	_stack_labels = refs.get("stack_labels", [])
	_dealer_button = refs.get("dealer_button", null)
	_pot_display = refs.get("pot_display", null)
	_community_cards_container = refs.get("community_cards_container", null)
	_purple_stacks = refs.get("purple_stacks", [])
	_black_stacks = refs.get("black_stacks", [])
	_green_stacks = refs.get("green_stacks", [])
	_player_bet_chips = refs.get("player_bet_chips", [])
	_pot_chip_area = refs.get("pot_chip_area", null)
	_chip_record = refs.get("chip_record", null)
	_action_boxes.assign(refs.get("action_boxes", []))


func set_preview_references(preview_refs: Dictionary) -> void:
	_preview_hole_card_containers = preview_refs.get("hole_card_containers", [])
	_preview_comm_cards = preview_refs.get("comm_cards", [])
	_preview_dealer_buttons = preview_refs.get("dealer_buttons", [])
	_preview_answer_boxes = preview_refs.get("answer_boxes", [])


func build_select_all_checkbox(parent: VBoxContainer) -> void:
	var select_all_row := HBoxContainer.new()
	select_all_row.add_theme_constant_override("separation", 10)
	parent.add_child(select_all_row)

	_select_all_checkbox = CheckBox.new()
	_select_all_checkbox.button_pressed = true
	_select_all_checkbox.custom_minimum_size = Vector2(32, 32)
	_select_all_checkbox.toggled.connect(_on_select_all_toggled)
	select_all_row.add_child(_select_all_checkbox)

	var select_all_lbl := Label.new()
	select_all_lbl.text = "全选/取消全选"
	select_all_lbl.add_theme_font_size_override("font_size", 28)
	select_all_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	select_all_lbl.custom_minimum_size.x = 140
	select_all_row.add_child(select_all_lbl)

	# Separator line
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	parent.add_child(separator)


func create_element_checkbox(element_key: String) -> CheckBox:
	var checkbox := CheckBox.new()
	checkbox.button_pressed = _element_visibility.get(element_key, true)
	checkbox.custom_minimum_size = Vector2(32, 32)
	checkbox.toggled.connect(func(pressed: bool) -> void:
		_element_visibility[element_key] = pressed
		update_element_visibility(element_key, pressed)
		_update_select_all_checkbox()
		visibility_changed.emit(element_key, pressed)
	)
	_element_checkboxes[element_key] = checkbox
	return checkbox


func update_element_visibility(element_key: String, visible: bool) -> void:
	match element_key:
		"hole_cards":
			for container in _preview_hole_card_containers:
				if is_instance_valid(container):
					container.visible = visible
		"community_cards":
			if _community_cards_container:
				_community_cards_container.visible = visible
			for card in _preview_comm_cards:
				if is_instance_valid(card) and card.get_parent():
					card.get_parent().visible = visible
		"dealer_buttons":
			if _dealer_button:
				_dealer_button.visible = visible
			for btn in _preview_dealer_buttons:
				if is_instance_valid(btn):
					btn.visible = visible
		"bet_labels":
			for label in _bet_labels:
				label.visible = visible
		"stack_labels":
			for label in _stack_labels:
				label.visible = visible
		"pot_display":
			if _pot_display:
				_pot_display.visible = visible
		"answer_boxes":
			for box in _preview_answer_boxes:
				if is_instance_valid(box):
					box.visible = visible
		"action_boxes":
			for ab in _action_boxes:
				if is_instance_valid(ab):
					ab.visible = visible
		"player_chips":
			for stack in _purple_stacks:
				if is_instance_valid(stack):
					stack.visible = visible
			for stack in _black_stacks:
				if is_instance_valid(stack):
					stack.visible = visible
			for stack in _green_stacks:
				if is_instance_valid(stack):
					stack.visible = visible
		"bet_chips":
			for bet_chip in _player_bet_chips:
				if is_instance_valid(bet_chip):
					bet_chip.visible = visible
		"pot_chips":
			if _pot_chip_area and is_instance_valid(_pot_chip_area):
				_pot_chip_area.visible = visible
		"chip_record":
			if _chip_record and is_instance_valid(_chip_record):
				_chip_record.visible = visible


func apply_all_visibility() -> void:
	for key in _element_visibility.keys():
		update_element_visibility(key, _element_visibility[key])


## Force all elements visible and sync checkboxes (used when entering layout mode)
func select_all() -> void:
	for key in _element_visibility.keys():
		_element_visibility[key] = true
		if _element_checkboxes.has(key):
			(_element_checkboxes[key] as CheckBox).set_pressed_no_signal(true)
		update_element_visibility(key, true)
	if _select_all_checkbox:
		_select_all_checkbox.set_pressed_no_signal(true)
	visibility_changed.emit("all", true)


func restore_all_visibility() -> void:
	# When returning to game mode, respect display_mode setting
	var is_numbers := GameManager.display_mode == "numbers"

	for label in _bet_labels:
		label.visible = is_numbers
	for label in _stack_labels:
		label.visible = is_numbers
	for stack in _purple_stacks:
		if is_instance_valid(stack):
			stack.visible = not is_numbers
	for stack in _black_stacks:
		if is_instance_valid(stack):
			stack.visible = not is_numbers
	for stack in _green_stacks:
		if is_instance_valid(stack):
			stack.visible = not is_numbers
	for bet_chip in _player_bet_chips:
		if is_instance_valid(bet_chip):
			bet_chip.visible = not is_numbers
	if _pot_chip_area and is_instance_valid(_pot_chip_area):
		_pot_chip_area.visible = not is_numbers
	if _chip_record and is_instance_valid(_chip_record):
		_chip_record.visible = not is_numbers
	if _pot_display:
		_pot_display.visible = is_numbers
	if _community_cards_container:
		_community_cards_container.visible = true
	if _dealer_button:
		_dealer_button.visible = true
	# Action boxes: hidden by default in game mode (shown dynamically per action)
	for ab in _action_boxes:
		if is_instance_valid(ab):
			ab.visible = false


func is_element_visible(element_key: String) -> bool:
	return _element_visibility.get(element_key, true)


## Apply display mode: "numbers" hides chips, "chips" hides labels
func apply_display_mode(mode: String) -> void:
	var numbers_keys := ["bet_labels", "stack_labels", "pot_display"]
	var chips_keys := ["player_chips", "bet_chips", "pot_chips", "chip_record"]

	if mode == "numbers":
		for key in numbers_keys:
			_element_visibility[key] = true
			update_element_visibility(key, true)
			if _element_checkboxes.has(key):
				(_element_checkboxes[key] as CheckBox).set_pressed_no_signal(true)
		for key in chips_keys:
			_element_visibility[key] = false
			update_element_visibility(key, false)
			if _element_checkboxes.has(key):
				(_element_checkboxes[key] as CheckBox).set_pressed_no_signal(false)
	else:
		for key in chips_keys:
			_element_visibility[key] = true
			update_element_visibility(key, true)
			if _element_checkboxes.has(key):
				(_element_checkboxes[key] as CheckBox).set_pressed_no_signal(true)
		for key in numbers_keys:
			_element_visibility[key] = false
			update_element_visibility(key, false)
			if _element_checkboxes.has(key):
				(_element_checkboxes[key] as CheckBox).set_pressed_no_signal(false)

	_update_select_all_checkbox()
	visibility_changed.emit("all", true)


func _on_select_all_toggled(pressed: bool) -> void:
	for key in _element_visibility.keys():
		_element_visibility[key] = pressed
		if _element_checkboxes.has(key):
			var cb: CheckBox = _element_checkboxes[key]
			cb.set_pressed_no_signal(pressed)
		update_element_visibility(key, pressed)
	visibility_changed.emit("all", pressed)


func _update_select_all_checkbox() -> void:
	if not _select_all_checkbox:
		return
	var all_checked := true
	for key in _element_visibility.keys():
		if not _element_visibility[key]:
			all_checked = false
			break
	_select_all_checkbox.set_pressed_no_signal(all_checked)
