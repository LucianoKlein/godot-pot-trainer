class_name QuestionPanelManager
extends RefCounted
## QuestionPanelManager — 答题面板 + 数字键盘 + 答题反馈特效

const AnswerBoxScene := preload("res://scenes/game/components/answer_box.tscn")

var _parent: Control
var _question_panel: Control
var _numpad_panel: PanelContainer
var _submit_feedback: Control


func setup(parent: Control) -> RefCounted:
	_parent = parent
	return self


func build() -> void:
	_build_question_panel()
	_build_submit_feedback()


func _build_question_panel() -> void:
	_question_panel = AnswerBoxScene.instantiate()
	_question_panel.name = "QuestionPanel"
	_question_panel.visible = false
	_question_panel.z_index = 300
	_question_panel.preview_mode = false
	_question_panel.scale_factor = 1.0
	_parent.add_child(_question_panel)
	_question_panel.submit_pressed.connect(_on_answer_box_submit)
	_build_numpad()


func _build_numpad() -> void:
	_numpad_panel = PanelContainer.new()
	_numpad_panel.name = "NumpadPanel"
	_numpad_panel.visible = false
	_numpad_panel.z_index = 301
	_numpad_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sf := 1.0
	var pad_sb := StyleBoxFlat.new()
	pad_sb.bg_color = Color(0.08, 0.08, 0.10, 0.96)
	pad_sb.border_color = Color(0.50, 0.40, 0.16)
	pad_sb.set_border_width_all(1)
	pad_sb.set_corner_radius_all(6)
	pad_sb.content_margin_left = int(6 * sf)
	pad_sb.content_margin_right = int(6 * sf)
	pad_sb.content_margin_top = int(6 * sf)
	pad_sb.content_margin_bottom = int(6 * sf)
	pad_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	pad_sb.shadow_size = int(4 * sf)
	_numpad_panel.add_theme_stylebox_override("panel", pad_sb)

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(4 * sf))
	grid.add_theme_constant_override("v_separation", int(4 * sf))
	_numpad_panel.add_child(grid)

	var keys: Array[String] = [
		"1", "2", "3", "4", "5", "6", "7", "8", "9", "cancel", "0", "confirm",
	]

	for key in keys:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(60, 48) * sf
		if key == "confirm":
			btn.text = Locale.tr_key("numpad_confirm")
			btn.add_theme_color_override("font_color", Color(0.25, 0.85, 0.45))
		elif key == "cancel":
			btn.text = Locale.tr_key("numpad_cancel")
			btn.add_theme_color_override("font_color", Color(0.85, 0.40, 0.35))
		else:
			btn.text = key
			btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		btn.add_theme_font_size_override("font_size", int(22 * sf))

		var ns := StyleBoxFlat.new()
		ns.bg_color = Color(0.14, 0.13, 0.12, 0.9)
		ns.border_color = Color(0.50, 0.40, 0.16, 0.5)
		ns.set_border_width_all(1)
		ns.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", ns)

		var hs := StyleBoxFlat.new()
		hs.bg_color = Color(0.20, 0.18, 0.14, 0.9)
		hs.border_color = Color(0.72, 0.58, 0.24)
		hs.set_border_width_all(1)
		hs.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", hs)

		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.10, 0.09, 0.08, 0.95)
		ps.border_color = Color(0.72, 0.58, 0.24)
		ps.set_border_width_all(1)
		ps.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("pressed", ps)

		var captured_key := key
		btn.pressed.connect(func() -> void: _question_panel.numpad_key_pressed(captured_key))
		grid.add_child(btn)

	_parent.add_child(_numpad_panel)
	_question_panel.set_numpad(_numpad_panel)


func _build_submit_feedback() -> void:
	_submit_feedback = Control.new()
	_submit_feedback.name = "SubmitFeedback"
	_submit_feedback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_submit_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_submit_feedback.z_index = 190
	_submit_feedback.visible = false
	_parent.add_child(_submit_feedback)


# --- Signal handlers (called by game_table) ---

func on_game_reset() -> void:
	_question_panel.visible = false
	_numpad_panel.visible = false
	_question_panel.clear_input()
	_question_panel.clear_result()


func on_question_appeared(question: Dictionary) -> void:
	_question_panel.visible = true
	_numpad_panel.visible = true
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
	_numpad_panel.set_deferred("visible", false)
	_question_panel.clear_input()
	_question_panel.clear_result()


func on_answer_result(correct: bool, user_answer: int, expected: int) -> void:
	if correct:
		_question_panel.set_result_text(Locale.tr_key("correct_answer") % expected, Color(0.25, 0.75, 0.40))
		_flash_correct()
	else:
		_question_panel.set_result_text(Locale.tr_key("wrong_answer") % [user_answer, expected], Color(0.85, 0.30, 0.30))
		_flash_wrong()


func _on_answer_box_submit(answer: int) -> void:
	var correct: bool = GameManager.submit_answer(answer)
	if not correct:
		_question_panel.clear_input()


func position_for_seat(seat: int) -> void:
	var scale: float = GameManager.layout_config.get("answer_box_scale", 1.0)
	_question_panel.update_scale(scale)
	var box_size := Vector2(420, 210) * scale
	var pos: Vector2 = GameManager.get_layout_position_px("answer_boxes", seat)
	_question_panel.position = pos - box_size * 0.5
	var gap: int = int(8 * scale)
	var numpad_width: float = _numpad_panel.get_combined_minimum_size().x
	var screen_width: float = _parent.get_viewport_rect().size.x
	var right_x := _question_panel.position.x + box_size.x + gap
	if right_x + numpad_width > screen_width:
		_numpad_panel.position = Vector2(_question_panel.position.x - numpad_width - gap, _question_panel.position.y)
	else:
		_numpad_panel.position = Vector2(right_x, _question_panel.position.y)


# --- Feedback effects ---

func _play_sfx(path: String) -> void:
	var main_node := _parent.get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.play_sfx(path)


func _flash_wrong() -> void:
	_play_sfx("res://assets/music/sounds_effect/wrong.ogg")
	for c in _submit_feedback.get_children():
		c.queue_free()
	_submit_feedback.visible = true
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.8, 0.1, 0.1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_submit_feedback.add_child(flash)
	var tw := _parent.create_tween()
	tw.tween_property(flash, "color:a", 0.35, 0.1)
	tw.tween_property(flash, "color:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		_submit_feedback.visible = false
		for c2 in _submit_feedback.get_children():
			c2.queue_free()
	)


func _flash_correct() -> void:
	_play_sfx("res://assets/music/sounds_effect/right.ogg")
	for c in _submit_feedback.get_children():
		c.queue_free()
	_submit_feedback.visible = true
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.1, 0.8, 0.3, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_submit_feedback.add_child(flash)
	var tw_flash := _parent.create_tween()
	tw_flash.tween_property(flash, "color:a", 0.3, 0.1)
	tw_flash.tween_property(flash, "color:a", 0.0, 0.35)
	await _parent.get_tree().create_timer(0.5).timeout
	_submit_feedback.visible = false
	for c2 in _submit_feedback.get_children():
		c2.queue_free()
	var symbols: Array[String] = ["★", "✦", "♠", "♥", "♦", "♣", "●", "◆"]
	var colors: Array[Color] = [Color.YELLOW, Color(0.2, 1.0, 0.4), Color.CYAN, Color.WHITE, Color(1.0, 0.6, 0.1)]
	_submit_feedback.visible = true
	for _i in range(18):
		var p := Label.new()
		p.text = symbols[randi() % symbols.size()]
		p.add_theme_font_size_override("font_size", randi_range(36, 72))
		p.add_theme_color_override("font_color", colors[randi() % colors.size()])
		p.position = Vector2(randi_range(100, 1820), randi_range(100, 980))
		_submit_feedback.add_child(p)
		var tw := _parent.create_tween()
		tw.set_parallel(true)
		var target := p.position + Vector2(randf_range(-200, 200), randf_range(-300, 100))
		tw.tween_property(p, "position", target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_LINEAR)
	await _parent.get_tree().create_timer(0.5).timeout
	_submit_feedback.visible = false
	for c3 in _submit_feedback.get_children():
		c3.queue_free()
