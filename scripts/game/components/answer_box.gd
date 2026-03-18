extends PanelContainer
## Answer Box Component — 答题框组件
## 支持游戏模式（交互）和布局预览模式（静态）
## 包含悬浮数字小键盘，禁止系统键盘呼出

signal submit_pressed(answer: int)

@export var preview_mode: bool = false
@export var scale_factor: float = 1.0

var _player_label: Label
var _question_label: Label
var _result_label: Label
var _answer_input: LineEdit
var _numpad_panel: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_apply_scale()
	if preview_mode:
		_disable_interaction()


func _build_ui() -> void:
	# Panel style — BoardAnalysis gold theme
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.10, 0.96 if not preview_mode else 0.88)
	sb.border_color = Color(0.50, 0.40, 0.16)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = int(6 * scale_factor)
	sb.content_margin_right = int(6 * scale_factor)
	sb.content_margin_top = int(4 * scale_factor)
	sb.content_margin_bottom = int(4 * scale_factor)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	sb.shadow_size = int(4 * scale_factor)
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(3 * scale_factor))
	add_child(vbox)

	# --- Player tag row ---
	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tag_row)

	_player_label = Label.new()
	_player_label.text = ""
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	var tag_bg := StyleBoxFlat.new()
	tag_bg.bg_color = Color(0.50, 0.40, 0.16, 0.7)
	tag_bg.set_corner_radius_all(6)
	tag_bg.content_margin_left = int(10 * scale_factor)
	tag_bg.content_margin_right = int(10 * scale_factor)
	tag_bg.content_margin_top = int(2 * scale_factor)
	tag_bg.content_margin_bottom = int(2 * scale_factor)
	_player_label.add_theme_stylebox_override("normal", tag_bg)
	_player_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	tag_row.add_child(_player_label)

	# --- Question label ---
	_question_label = Label.new()
	_question_label.text = Locale.tr_key("question_text")
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_label.add_theme_font_size_override("font_size", int(24 * scale_factor))
	_question_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.32))
	vbox.add_child(_question_label)

	# --- Result label (correct/wrong feedback) ---
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", int(20 * scale_factor))
	_result_label.add_theme_color_override("font_color", Color.WHITE)
	_result_label.visible = false
	vbox.add_child(_result_label)

	# --- Input row (input only, no submit button — numpad handles it) ---
	var input_hbox := HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", int(8 * scale_factor))
	input_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(input_hbox)

	# Input field — disable virtual keyboard
	_answer_input = LineEdit.new()
	_answer_input.placeholder_text = Locale.tr_key("amount_placeholder")
	_answer_input.custom_minimum_size = Vector2(300, 48) * scale_factor
	_answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_answer_input.add_theme_font_size_override("font_size", int(24 * scale_factor))
	_answer_input.add_theme_color_override("font_color", Color.WHITE)
	_answer_input.add_theme_color_override("font_placeholder_color", Color(0.50, 0.40, 0.30))
	_answer_input.virtual_keyboard_enabled = false
	var input_bg := StyleBoxFlat.new()
	input_bg.bg_color = Color(0.08, 0.08, 0.10, 0.9)
	input_bg.border_color = Color(0.50, 0.40, 0.16, 0.6)
	input_bg.set_border_width_all(1)
	input_bg.set_corner_radius_all(6)
	input_bg.content_margin_left = int(10 * scale_factor)
	input_bg.content_margin_right = int(10 * scale_factor)
	input_bg.content_margin_top = int(4 * scale_factor)
	input_bg.content_margin_bottom = int(4 * scale_factor)
	_answer_input.add_theme_stylebox_override("normal", input_bg)
	var input_focus := input_bg.duplicate()
	input_focus.border_color = Color(0.72, 0.58, 0.24, 0.9)
	input_focus.set_border_width_all(1)
	_answer_input.add_theme_stylebox_override("focus", input_focus)
	input_hbox.add_child(_answer_input)

	# Connect signals (only in game mode)
	if not preview_mode:
		_answer_input.text_submitted.connect(_on_answer_submitted)


func _apply_scale() -> void:
	custom_minimum_size = Vector2(420, 210) * scale_factor
	size = Vector2(420, 210) * scale_factor


func update_scale(new_scale: float) -> void:
	scale_factor = new_scale
	if is_node_ready():
		_rebuild_ui()


func _rebuild_ui() -> void:
	for child in get_children():
		child.queue_free()
	_build_ui()
	_apply_scale()
	if preview_mode:
		_disable_interaction()


func _disable_interaction() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_answer_input.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_player_label(seat: int, template_name: String) -> void:
	if _player_label:
		if template_name.is_empty():
			_player_label.text = Locale.tr_key("seat_label") % (seat + 1)
		else:
			_player_label.text = Locale.tr_key("seat_label_template") % [seat + 1, template_name]


func set_question_text(text: String) -> void:
	if _question_label:
		_question_label.text = text


func set_result_text(text: String, color: Color = Color.WHITE) -> void:
	if _result_label:
		_result_label.text = text
		_result_label.add_theme_color_override("font_color", color)
		_result_label.visible = not text.is_empty()


func clear_input() -> void:
	if _answer_input:
		_answer_input.text = ""


func clear_result() -> void:
	if _result_label:
		_result_label.text = ""
		_result_label.visible = false


func grab_input_focus() -> void:
	if _answer_input and not preview_mode:
		_answer_input.grab_focus()


# =============================================================================
# NUMPAD — built as sibling by game_table, controlled here
# =============================================================================

func set_numpad(panel: PanelContainer) -> void:
	_numpad_panel = panel


func get_numpad() -> PanelContainer:
	return _numpad_panel


func numpad_key_pressed(key: String) -> void:
	match key:
		"confirm":
			_try_submit()
		"cancel":
			clear_input()
			clear_result()
		_:
			# Digit key — append to input
			_answer_input.text += key
			_answer_input.caret_column = _answer_input.text.length()


func _on_answer_submitted(_text: String) -> void:
	_try_submit()


func _try_submit() -> void:
	var text := _answer_input.text.strip_edges()
	if text.is_empty():
		return
	if not text.is_valid_int():
		set_result_text(Locale.tr_key("err_invalid_number"), Color(0.85, 0.30, 0.30))
		clear_input()
		return
	var val := text.to_int()
	submit_pressed.emit(val)
