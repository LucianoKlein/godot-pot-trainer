class_name QuestionPanelManager
extends RefCounted
## QuestionPanelManager — 答题面板协调器

const AnswerBoxScene := preload("res://scenes/game/components/answer_box.tscn")
const NumpadUIScript := preload("res://scripts/features/training/numpad_ui.gd")
const FeedbackFXScript := preload("res://scripts/features/training/feedback_fx.gd")
const GuestDialogScript := preload("res://scripts/features/training/guest_dialog.gd")

var _parent: Control
var _question_panel: Control
var _numpad: NumpadUI
var _feedback_fx: FeedbackFX
var _guest_dialog: GuestDialog


func setup(parent: Control) -> RefCounted:
	_parent = parent
	return self


func build() -> void:
	_build_question_panel()
	_build_feedback_fx()
	_build_guest_dialog()


func _build_question_panel() -> void:
	_question_panel = AnswerBoxScene.instantiate()
	_question_panel.name = "QuestionPanel"
	_question_panel.visible = false
	_question_panel.z_index = 300
	_question_panel.preview_mode = false
	_question_panel.scale_factor = 1.0
	_parent.add_child(_question_panel)
	_question_panel.submit_pressed.connect(_on_answer_box_submit)

	# 创建数字键盘
	_numpad = NumpadUIScript.new()
	_numpad.name = "NumpadPanel"
	_numpad.visible = false
	_numpad.z_index = 301
	_numpad.mouse_filter = Control.MOUSE_FILTER_STOP
	_parent.add_child(_numpad)
	_numpad.key_pressed.connect(_on_numpad_key_pressed)
	_question_panel.set_numpad(_numpad)


func _on_numpad_key_pressed(key: String) -> void:
	_question_panel.numpad_key_pressed(key)


func _build_feedback_fx() -> void:
	_feedback_fx = FeedbackFXScript.new()
	_feedback_fx.name = "FeedbackFX"
	_parent.add_child(_feedback_fx)


# --- Signal handlers (called by game_table) ---

func on_game_reset() -> void:
	_question_panel.visible = false
	_numpad.visible = false
	_question_panel.clear_input()
	_question_panel.clear_result()


func on_question_appeared(question: Dictionary) -> void:
	_question_panel.visible = true
	_numpad.visible = true
	# Move to front of node tree so input events are captured before siblings below
	_question_panel.move_to_front()
	_numpad.move_to_front()
	_question_panel.clear_input()
	_question_panel.clear_result()
	_question_panel.grab_input_focus()
	var seat: int = question["seat"]
	var physical_seat: int = GameManager.get_physical_seat(seat)
	position_for_seat(physical_seat)
	var template_name := ""
	if seat < GameManager.players.size() and GameManager.players[seat].template:
		template_name = Locale.tr_key(GameManager.players[seat].template.template_name)
	_question_panel.set_player_label(physical_seat, template_name)
	_question_panel.set_question_text(Locale.tr_key("question_text"))


func on_question_cleared() -> void:
	# Defer hiding to next frame so the current input event is fully consumed
	# and doesn't pass through to the control panel below.
	_question_panel.set_deferred("visible", false)
	_numpad.set_deferred("visible", false)
	_question_panel.clear_input()
	_question_panel.clear_result()


func on_answer_result(correct: bool, user_answer: int, expected: int) -> void:
	if correct:
		_question_panel.set_result_text(Locale.tr_key("correct_answer") % expected, Color(0.25, 0.75, 0.40))
		_feedback_fx.play_correct()
		GameManager.increment_guest_answer_count()
	else:
		_question_panel.set_result_text(Locale.tr_key("wrong_answer") % [user_answer, expected], Color(0.85, 0.30, 0.30))
		_feedback_fx.play_wrong()


func _on_answer_box_submit(answer: int) -> void:
	if GameManager.is_guest_mode:
		_show_guest_login_dialog()
		return
	var correct: bool = GameManager.submit_answer(answer)
	if not correct:
		_question_panel.clear_input()


func position_for_seat(seat: int) -> void:
	var scale: float = GameManager.layout_config.get("answer_box_scale", 1.0)
	_question_panel.update_scale(scale)
	var box_size := Vector2(420, 140) * scale
	var pos: Vector2 = GameManager.get_layout_position_px("answer_boxes", seat)
	_question_panel.position = pos - box_size * 0.5
	var gap: int = int(8 * scale)
	var numpad_width: float = _numpad.get_combined_minimum_size().x
	var numpad_height: float = _numpad.get_combined_minimum_size().y
	var screen_size: Vector2 = _parent.get_viewport_rect().size

	# Clamp answer box bottom within screen
	if _question_panel.position.y + box_size.y > screen_size.y:
		_question_panel.position.y = screen_size.y - box_size.y

	# Horizontal: prefer right side, fallback to left
	var right_x := _question_panel.position.x + box_size.x + gap
	if right_x + numpad_width > screen_size.x:
		_numpad.position = Vector2(_question_panel.position.x - numpad_width - gap, _question_panel.position.y)
	else:
		_numpad.position = Vector2(right_x, _question_panel.position.y)

	# Clamp numpad bottom within screen
	if _numpad.position.y + numpad_height > screen_size.y:
		_numpad.position.y = screen_size.y - numpad_height


func _build_guest_dialog() -> void:
	_guest_dialog = GuestDialogScript.new()
	_guest_dialog.name = "GuestDialog"
	_parent.add_child(_guest_dialog)
	_guest_dialog.go_to_login.connect(_on_guest_dialog_go_to_login)


func _show_guest_login_dialog() -> void:
	_guest_dialog.show_dialog()


func _on_guest_dialog_go_to_login() -> void:
	GameManager.change_state(GameManager.State.MENU)
	_parent.get_tree().root.get_node("Main").switch_scene("res://scenes/main_menu/main_menu.tscn")
