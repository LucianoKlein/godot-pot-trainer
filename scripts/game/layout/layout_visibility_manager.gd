class_name LayoutVisibilityManager
extends RefCounted
## LayoutVisibilityManager — 布局编辑器可见性管理

signal visibility_changed(element_key: String, visible: bool)

var _element_visibility: Dictionary = {
	"hole_cards": true, "community_cards": true, "dealer_buttons": true,
	"bet_labels": true, "stack_labels": true, "pot_display": true,
	"street_badge": true, "answer_boxes": true, "action_boxes": true,
	"player_chips": true, "bet_chips": true, "ordered_bet_chips": true,
	"pot_chips": true, "chip_record": true,
}

var _element_checkboxes: Dictionary = {}
var _select_all_checkbox: CheckBox = null

# All refs stored in a single dict for cleaner access
var _refs: Dictionary = {}
var _preview_refs: Dictionary = {}


func setup(refs: Dictionary) -> RefCounted:
	_refs = refs
	return self


func set_preview_references(preview_refs: Dictionary) -> void:
	_preview_refs = preview_refs


func build_select_all_checkbox(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	_select_all_checkbox = CheckBox.new()
	_select_all_checkbox.button_pressed = true
	_select_all_checkbox.custom_minimum_size = Vector2(32, 32)
	_select_all_checkbox.toggled.connect(_on_select_all_toggled)
	row.add_child(_select_all_checkbox)

	row.add_child(UiFactory.make_label(Locale.tr_key("select_all"), 28, UiFactory.LAYOUT_LABEL))

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)


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
			_set_array_visible(_preview_refs.get("hole_card_containers", []), visible)
		"community_cards":
			_set_single_visible(_refs.get("community_cards_container"), visible)
			for card in _preview_refs.get("comm_cards", []):
				if is_instance_valid(card) and card.get_parent():
					card.get_parent().visible = visible
		"dealer_buttons":
			_set_single_visible(_refs.get("dealer_button"), visible)
			_set_array_visible(_preview_refs.get("dealer_buttons", []), visible)
		"bet_labels":
			_set_array_visible(_refs.get("bet_labels", []), visible)
		"stack_labels":
			_set_array_visible(_refs.get("stack_labels", []), visible)
		"pot_display":
			_set_single_visible(_refs.get("pot_display"), visible)
		"street_badge":
			_set_single_visible(_refs.get("street_badge"), visible)
		"answer_boxes":
			_set_array_visible(_preview_refs.get("answer_boxes", []), visible)
		"action_boxes":
			_set_array_visible(_refs.get("action_boxes", []), visible)
		"player_chips":
			_update_player_chips_visibility(visible)
		"bet_chips":
			_set_array_visible(_refs.get("player_bet_chips", []), visible)
		"ordered_bet_chips":
			_set_array_visible(_refs.get("ordered_bet_chips", []), visible)
		"pot_chips":
			_set_single_visible(_refs.get("pot_chip_area"), visible)
		"chip_record":
			_set_single_visible(_refs.get("chip_record"), visible)


func _update_player_chips_visibility(visible: bool) -> void:
	var bm: String = GameManager.blinds_mode
	var is_small: bool = (bm == "5/10")
	var is_12: bool = (bm == "1/2" or bm == "1/2/5")
	var use_red: bool = is_small or is_12
	_set_array_visible(_refs.get("purple_stacks", []), visible and not is_small and not is_12)
	_set_array_visible(_refs.get("black_stacks", []), visible and not is_12)
	_set_array_visible(_refs.get("green_stacks", []), visible)
	_set_array_visible(_refs.get("red_stacks_1", []), visible and use_red)
	_set_array_visible(_refs.get("red_stacks_2", []), visible and use_red)
	_set_array_visible(_refs.get("red_stacks_3", []), visible and use_red)
	_set_array_visible(_refs.get("white_stacks", []), visible and is_12)


func apply_all_visibility() -> void:
	for key in _element_visibility.keys():
		update_element_visibility(key, _element_visibility[key])


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
	var is_numbers: bool = GameManager.display_mode == "numbers"
	var bm: String = GameManager.blinds_mode
	var is_small: bool = (bm == "5/10")
	var is_12: bool = (bm == "1/2" or bm == "1/2/5")
	var use_red: bool = is_small or is_12

	_set_array_visible(_refs.get("bet_labels", []), is_numbers)
	_set_array_visible(_refs.get("stack_labels", []), is_numbers)
	_set_array_visible(_refs.get("black_stacks", []), not is_numbers and not is_12)
	_set_array_visible(_refs.get("green_stacks", []), not is_numbers)
	_set_array_visible(_refs.get("red_stacks_1", []), not is_numbers and use_red)
	_set_array_visible(_refs.get("red_stacks_2", []), not is_numbers and use_red)
	_set_array_visible(_refs.get("red_stacks_3", []), not is_numbers and use_red)
	_set_array_visible(_refs.get("white_stacks", []), not is_numbers and is_12)
	_set_array_visible(_refs.get("purple_stacks", []), not is_numbers and not is_small and not is_12)
	_set_array_visible(_refs.get("player_bet_chips", []), not is_numbers)
	_set_array_visible(_refs.get("ordered_bet_chips", []), false)
	_set_single_visible(_refs.get("pot_chip_area"), not is_numbers)
	_set_single_visible(_refs.get("chip_record"), not is_numbers)
	_set_single_visible(_refs.get("pot_display"), is_numbers)
	_set_single_visible(_refs.get("community_cards_container"), true)
	_set_single_visible(_refs.get("dealer_button"), true)
	_set_single_visible(_refs.get("street_badge"), true)
	# Action boxes: hidden by default in game mode
	_set_array_visible(_refs.get("action_boxes", []), false)


func is_element_visible(element_key: String) -> bool:
	return _element_visibility.get(element_key, true)


func apply_display_mode(mode: String) -> void:
	var numbers_keys: Array = ["bet_labels", "stack_labels", "pot_display"]
	var chips_keys: Array = ["player_chips", "bet_chips", "ordered_bet_chips", "pot_chips", "chip_record"]
	var on_keys: Array = numbers_keys if mode == "numbers" else chips_keys
	var off_keys: Array = chips_keys if mode == "numbers" else numbers_keys

	for key in on_keys:
		_set_visibility_and_checkbox(key, true)
	for key in off_keys:
		_set_visibility_and_checkbox(key, false)

	_update_select_all_checkbox()
	visibility_changed.emit("all", true)


# =============================================================================
# Helpers
# =============================================================================

func _set_array_visible(arr: Array, visible: bool) -> void:
	for node in arr:
		if is_instance_valid(node):
			node.visible = visible


func _set_single_visible(node: Variant, visible: bool) -> void:
	if node and is_instance_valid(node):
		node.visible = visible


func _set_visibility_and_checkbox(key: String, visible: bool) -> void:
	_element_visibility[key] = visible
	update_element_visibility(key, visible)
	if _element_checkboxes.has(key):
		(_element_checkboxes[key] as CheckBox).set_pressed_no_signal(visible)


func _on_select_all_toggled(pressed: bool) -> void:
	for key in _element_visibility.keys():
		_element_visibility[key] = pressed
		if _element_checkboxes.has(key):
			(_element_checkboxes[key] as CheckBox).set_pressed_no_signal(pressed)
		update_element_visibility(key, pressed)
	visibility_changed.emit("all", pressed)


func _update_select_all_checkbox() -> void:
	if not _select_all_checkbox:
		return
	var all_checked: bool = true
	for key in _element_visibility.keys():
		if not _element_visibility[key]:
			all_checked = false
			break
	_select_all_checkbox.set_pressed_no_signal(all_checked)
