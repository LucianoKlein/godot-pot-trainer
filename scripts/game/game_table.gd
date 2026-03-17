extends Control

const CardDisplayScene := preload("res://scenes/game/components/card_display.tscn")
const AnswerBoxScene := preload("res://scenes/game/components/answer_box.tscn")
const LayoutEditor := preload("res://scripts/game/layout_editor.gd")
const PotChipArea := preload("res://scripts/game/components/pot_chip_area.gd")
const SeatUI := preload("res://scripts/game/components/seat_ui.gd")
const TableCenter := preload("res://scripts/game/components/table_center.gd")
const ControlPanelManager := preload("res://scripts/game/ui/control_panel_manager.gd")
const ChipRecord := preload("res://scripts/game/components/chip_record.gd")

# --- Node references ---
var _chairs: Array[TextureRect] = []
var _table_overlay: Control

# --- Per-seat UI (managed by SeatUI components) ---
var _seats: Array[SeatUI] = []

# --- Control Panel (managed by ControlPanelManager) ---
var _control_panel_manager: ControlPanelManager

var _dealer_button: Control
var _dealer_tween: Tween

# --- Pot chip area ---
var _pot_chip_area: Control

# --- Chip record (abacus) ---
var _chip_record: Control

# --- Table center (managed by TableCenter component) ---
var _table_center: TableCenter

# --- Training question UI ---
var _question_panel: Control  # AnswerBox component

# --- Layout editor ---
var _layout_editor: RefCounted

# --- Answer feedback overlay (full-screen flash + particles) ---
var _submit_feedback: Control

var _bg: TextureRect


func _ready() -> void:
	_bg = $Background
	for i in range(1, 10):
		_chairs.append(get_node("Chair%d" % i) as TextureRect)
	GameManager.init_game()
	_build_table_overlay()
	_build_seats()
	_build_pot_chip_area()
	_build_chip_record()
	_build_dealer_button()
	_table_center = TableCenter.new(self, _table_overlay)
	_table_center.build()
	_build_submit_feedback()
	_control_panel_manager = ControlPanelManager.new(self)
	_control_panel_manager.build(_on_back_to_menu_pressed)
	_connect_control_panel_signals()
	_build_question_panel()
	_layout_editor = LayoutEditor.new(self, _table_overlay, _control_panel_manager.layout_btn, _control_panel_manager.control_panel, _on_back_to_menu_pressed, {
		"avatars": _seats.map(func(s: SeatUI) -> TextureRect: return s.avatar),
		"chairs": _chairs,
		"bet_labels": _seats.map(func(s: SeatUI) -> Label: return s.bet_label),
		"stack_labels": _seats.map(func(s: SeatUI) -> Label: return s.stack_label),
		"dealer_button": _dealer_button,
		"pot_display": _table_center.pot_display,
		"community_cards_container": _table_center.community_cards_container,
		"purple_stacks": _seats.map(func(s: SeatUI) -> Node2D: return s.purple_stack),
		"black_stacks": _seats.map(func(s: SeatUI) -> Node2D: return s.black_stack),
		"green_stacks": _seats.map(func(s: SeatUI) -> Node2D: return s.green_stack),
		"player_bet_chips": _seats.map(func(s: SeatUI) -> Control: return s.bet_chips_container),
		"pot_chip_area": _pot_chip_area,
		"chip_record": _chip_record,
		"action_boxes": _seats.map(func(s: SeatUI) -> Label: return s.action_box),
	})
	_layout_editor.build()
	_connect_signals()
	GameManager.load_layout_from_file()
	# Apply persisted display_mode to UI after layout load
	_on_display_mode_changed(GameManager.display_mode)
	_refresh_all()
	if GameManager.pending_layout_mode:
		GameManager.pending_layout_mode = false
		_layout_editor.toggle()


func _build_table_overlay() -> void:
	_table_overlay = Control.new()
	_table_overlay.name = "TableOverlay"
	_table_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_table_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_table_overlay)


# =============================================================================
# SEATS (managed by SeatUI components)
# =============================================================================

func _build_seats() -> void:
	for i in range(9):
		var seat := SeatUI.new(i, _table_overlay)
		seat.build()
		_seats.append(seat)


# =============================================================================
# POT CHIP AREA
# =============================================================================

func _build_pot_chip_area() -> void:
	_pot_chip_area = Control.new()
	_pot_chip_area.set_script(PotChipArea)
	_pot_chip_area.name = "PotChipArea"
	_pot_chip_area.z_index = 8
	var pot_pos: Vector2 = GameManager.get_layout_position_px("pot")
	_pot_chip_area.position = pot_pos - Vector2(80, 60)
	_pot_chip_area.area_width = 160.0
	_pot_chip_area.area_height = 120.0
	_pot_chip_area.chip_scale = GameManager.layout_config.get("pot_chip_scale", 1.0)
	_pot_chip_area.is_editing = false
	_table_overlay.add_child(_pot_chip_area)


# =============================================================================
# CHIP RECORD (ABACUS)
# =============================================================================

func _build_chip_record() -> void:
	_chip_record = Control.new()
	_chip_record.set_script(ChipRecord)
	_chip_record.name = "ChipRecord"
	_chip_record.z_index = 9
	var cr_pos: Vector2 = GameManager.get_layout_position_px("chip_record")
	var cr_scale: float = GameManager.layout_config.get("chip_record_scale", 1.0)
	_chip_record.scale_factor = cr_scale
	var cr_size: Vector2 = _chip_record.get_display_size()
	_chip_record.position = cr_pos - cr_size * 0.5
	# Hidden by default in numbers mode
	_chip_record.visible = GameManager.display_mode == "chips" or GameManager.layout_mode
	_table_overlay.add_child(_chip_record)


# =============================================================================
# DEALER BUTTON
# =============================================================================

func _build_dealer_button() -> void:
	var scale: float = GameManager.layout_config.get("dealer_button_scale", 1.0)
	var btn_size := Vector2(28, 28) * scale

	_dealer_button = Control.new()
	_dealer_button.name = "DealerButton"
	_dealer_button.custom_minimum_size = btn_size
	_dealer_button.size = btn_size
	_dealer_button.z_index = 3

	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = Color.BLACK
	sb.set_border_width_all(2)
	var radius := int(btn_size.x / 2)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dealer_button.add_child(bg)

	var lbl := Label.new()
	lbl.text = "D"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(14 * scale))
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dealer_button.add_child(lbl)

	var pos: Vector2 = GameManager.get_layout_position_px("dealer_buttons", GameManager.get_physical_seat(GameManager.dealer_index))
	_dealer_button.position = pos - btn_size * 0.5
	_table_overlay.add_child(_dealer_button)


# =============================================================================
# TRAINING QUESTION PANEL
# =============================================================================

func _build_question_panel() -> void:
	_question_panel = AnswerBoxScene.instantiate()
	_question_panel.name = "QuestionPanel"
	_question_panel.visible = false
	_question_panel.z_index = 300
	_question_panel.preview_mode = false
	_question_panel.scale_factor = 1.0
	add_child(_question_panel)
	_question_panel.submit_pressed.connect(_on_answer_box_submit)


func _build_submit_feedback() -> void:
	_submit_feedback = Control.new()
	_submit_feedback.name = "SubmitFeedback"
	_submit_feedback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_submit_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_submit_feedback.z_index = 190
	_submit_feedback.visible = false
	add_child(_submit_feedback)


func _play_sfx(path: String) -> void:
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.play_sfx(path)


# =============================================================================
# SIGNAL CONNECTIONS
# =============================================================================

func _connect_control_panel_signals() -> void:
	_control_panel_manager.start_pressed.connect(_on_start_pressed)
	_control_panel_manager.pause_pressed.connect(_on_pause_pressed)
	_control_panel_manager.reset_pressed.connect(_on_reset_pressed)
	_control_panel_manager.player_count_changed.connect(func(count: int) -> void:
		GameManager.set_player_count(count)
		_control_panel_manager.update_dealer_options()
	)
	_control_panel_manager.blinds_changed.connect(func(sb: int, bb: int) -> void:
		GameManager.set_blinds(sb, bb)
	)
	_control_panel_manager.preset_changed.connect(func(preset: int) -> void:
		GameManager.set_table_preset(preset)
	)
	_control_panel_manager.mode_changed.connect(func(mode: String) -> void:
		GameManager.set_training_mode(mode)
	)
	_control_panel_manager.display_mode_changed.connect(func(mode: String) -> void:
		GameManager.set_display_mode(mode)
	)
	_control_panel_manager.dealer_changed.connect(func(index: int) -> void:
		GameManager.set_dealer_index(index)
	)


func _connect_signals() -> void:
	GameManager.pot_changed.connect(_on_pot_changed)
	GameManager.street_changed.connect(_on_street_changed)
	GameManager.community_cards_changed.connect(_on_community_cards_changed)
	GameManager.current_player_changed.connect(_on_current_player_changed)
	GameManager.last_action_changed.connect(_on_last_action_changed)
	GameManager.dealer_moved.connect(_on_dealer_moved)
	GameManager.layout_changed.connect(_on_layout_changed)
	GameManager.game_reset.connect(_on_game_reset)
	GameManager.training_question_appeared.connect(_on_question_appeared)
	GameManager.training_question_cleared.connect(_on_question_cleared)
	GameManager.answer_result.connect(_on_answer_result)
	GameManager.game_over.connect(_on_game_over)
	GameManager.display_mode_changed.connect(_on_display_mode_changed)
	GameManager.hole_cards_changed.connect(_on_hole_cards_changed)
	GameManager.npc_acted.connect(_on_npc_acted)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_pot_changed(_new_pot: int) -> void:
	_table_center.refresh_pot(_pot_chip_area)
	_refresh_chip_record()

func _on_street_changed(_new_street: String) -> void:
	_table_center.refresh_street()
	_refresh_seats()

func _on_community_cards_changed() -> void:
	_table_center.refresh_community_cards()

func _on_current_player_changed(_index: int) -> void:
	_refresh_current_player()

func _on_last_action_changed(text: String) -> void:
	_table_center.set_last_action(text)

func _on_dealer_moved(_index: int) -> void:
	_refresh_dealer_button()

func _on_layout_changed() -> void:
	# Skip heavy refresh during active drag — the drag handler already moves the node directly
	if _layout_editor.is_dragging:
		return
	_refresh_all()
	# Re-apply layout editor visibility after _refresh_all resets everything visible
	if GameManager.layout_mode:
		_layout_editor.apply_all_visibility()
	# Update seat positions and chip scales
	for seat in _seats:
		seat.update_position()
		seat.update_chip_scale()
	# Update pot chip scale
	if _pot_chip_area and is_instance_valid(_pot_chip_area):
		_pot_chip_area.chip_scale = GameManager.layout_config.get("pot_chip_scale", 1.0)
		_pot_chip_area._rebuild()
	# Re-enable drag and refresh preview after chip stacks are rebuilt
	# (fixes stale DragOverlay issue for both chips and preview elements like hole cards)
	if GameManager.layout_mode:
		_layout_editor.rebuild_drag_connections()

func _on_game_reset() -> void:
	_question_panel.visible = false
	_question_panel.clear_input()
	_question_panel.clear_result()
	_refresh_all()

func _on_question_appeared(question: Dictionary) -> void:
	_question_panel.visible = true
	_question_panel.clear_input()
	_question_panel.clear_result()
	_question_panel.grab_input_focus()
	var seat: int = question["seat"]  # logical index
	var physical_seat: int = GameManager.get_physical_seat(seat)

	# Position panel first (may rebuild UI via update_scale)
	_position_question_panel_for_seat(physical_seat)

	# Player label with template name (must be after positioning to survive rebuild)
	var template_name := ""
	if seat < GameManager.players.size() and GameManager.players[seat].template:
		template_name = GameManager.players[seat].template.template_name
	_question_panel.set_player_label(physical_seat, template_name)

	_question_panel.set_question_text("底池限注最大加注是多少？")

func _on_question_cleared() -> void:
	_question_panel.visible = false
	_question_panel.clear_input()
	_question_panel.clear_result()
	_refresh_seats()

func _on_answer_result(correct: bool, user_answer: int, expected: int) -> void:
	if correct:
		_question_panel.set_result_text("正确！%d" % expected, Color(0.25, 0.75, 0.40))
		_flash_correct()
	else:
		_question_panel.set_result_text("错误！你答: %d，正确: %d" % [user_answer, expected], Color(0.85, 0.30, 0.30))
		_flash_wrong()

func _on_game_over() -> void:
	_refresh_seats()

func _on_display_mode_changed(_mode: String) -> void:
	_refresh_seats()
	_table_center.refresh_pot(_pot_chip_area)
	_refresh_chip_record()
	_control_panel_manager._update_display_mode_styles()

func _on_hole_cards_changed() -> void:
	_refresh_seats()

func _on_npc_acted(_seat: int, _action: String, _amount: int) -> void:
	_refresh_seats()
	_refresh_current_player()


# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_start_pressed() -> void:
	GameManager.start_game()

func _on_pause_pressed() -> void:
	GameManager.pause_game()

func _on_reset_pressed() -> void:
	GameManager.reset_game()
	GameManager.init_game()

func _on_back_to_menu_pressed() -> void:
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.play_sfx("res://assets/music/sounds_effect/button.ogg")
	# Ensure layout mode is fully exited before leaving
	if GameManager.layout_mode:
		_layout_editor.toggle()
	GameManager.reset_game()
	GameManager.change_state(GameManager.State.MENU)
	if main_node:
		main_node.switch_scene("res://scenes/main_menu/main_menu.tscn")

func _on_answer_box_submit(answer: int) -> void:
	var correct := GameManager.submit_answer(answer)
	if not correct:
		_question_panel.clear_input()


func _position_question_panel_for_seat(seat: int) -> void:
	var scale: float = GameManager.layout_config.get("answer_box_scale", 1.0)
	_question_panel.update_scale(scale)
	var box_size := Vector2(420, 210) * scale
	var pos: Vector2 = GameManager.get_layout_position_px("answer_boxes", seat)
	_question_panel.position = pos - box_size * 0.5


# =============================================================================
# REFRESH METHODS
# =============================================================================

func _refresh_all() -> void:
	_refresh_seats()
	_table_center.refresh_pot(_pot_chip_area)
	_table_center.refresh_street()
	_refresh_dealer_button()
	_table_center.refresh_community_cards()
	_refresh_current_player()
	_refresh_chip_record()


func _refresh_seats() -> void:
	var chair_scale: float = GameManager.layout_config.get("chair_scale", 1.0)
	var chair_rotations: Array = GameManager.layout_config.get("chair_rotation", [])
	var chair_size := TableLayout.DEFAULT_CHAIR_SIZE * chair_scale
	# Build a reverse map: physical_seat -> player_data
	var seat_to_player: Dictionary = {}
	for logical_i in range(GameManager.players.size()):
		var physical_seat: int = GameManager.get_physical_seat(logical_i)
		seat_to_player[physical_seat] = GameManager.players[logical_i]

	for i in range(9):
		var has_player: bool = seat_to_player.has(i)
		_chairs[i].visible = GameManager.layout_mode or has_player
		var chair_pos: Vector2 = GameManager.get_layout_position_px("chairs", i)
		_chairs[i].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_chairs[i].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_chairs[i].custom_minimum_size = chair_size
		_chairs[i].size = chair_size
		_chairs[i].position = chair_pos - chair_size * 0.5
		_chairs[i].pivot_offset = chair_size * 0.5
		_chairs[i].rotation_degrees = chair_rotations[i] if i < chair_rotations.size() else 0.0

		var player_data: PlayerData = null
		if has_player:
			player_data = seat_to_player[i]

		_seats[i].refresh(player_data, GameManager.layout_mode)


func _refresh_dealer_button() -> void:
	var physical_seat: int = GameManager.get_physical_seat(GameManager.dealer_index)
	var scale: float = GameManager.layout_config.get("dealer_button_scale", 1.0)
	var btn_size := Vector2(28, 28) * scale
	_dealer_button.size = btn_size

	var pos: Vector2 = GameManager.get_layout_position_px("dealer_buttons", physical_seat)
	var target := pos - btn_size * 0.5

	if _dealer_tween:
		_dealer_tween.kill()
	_dealer_tween = create_tween()
	_dealer_tween.tween_property(_dealer_button, "position", target, 0.3)


func _refresh_chip_record() -> void:
	if not _chip_record or not is_instance_valid(_chip_record):
		return
	# Only show pot_total (settled rounds + folded players' contributions)
	var total := GameManager.engine.pot_total
	_chip_record.set_amount(total)
	# Update position
	var cr_pos: Vector2 = GameManager.get_layout_position_px("chip_record")
	var cr_scale: float = GameManager.layout_config.get("chip_record_scale", 1.0)
	_chip_record.scale_factor = cr_scale
	var cr_size: Vector2 = _chip_record.get_display_size()
	_chip_record.position = cr_pos - cr_size * 0.5
	# Visibility: chips mode or layout mode
	if not GameManager.layout_mode:
		_chip_record.visible = GameManager.display_mode == "chips"


func _refresh_current_player() -> void:
	var cp := GameManager.current_player_index
	# Build reverse map: physical_seat -> logical_index
	var seat_to_logical: Dictionary = {}
	for logical_i in range(GameManager.players.size()):
		var physical_seat: int = GameManager.get_physical_seat(logical_i)
		seat_to_logical[physical_seat] = logical_i

	for i in range(_seats.size()):
		if not seat_to_logical.has(i):
			# No player at this seat — disable highlight
			_seats[i].set_current_player(false, false)
			continue
		var logical_i: int = seat_to_logical[i]
		var is_folded := GameManager.players[logical_i].folded
		_seats[i].set_current_player(logical_i == cp, is_folded)


# =============================================================================
# ANSWER FEEDBACK EFFECTS (from BoardAnalysis)
# =============================================================================

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
	var tw := create_tween()
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

	# Green flash
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.1, 0.8, 0.3, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_submit_feedback.add_child(flash)
	var tw_flash := create_tween()
	tw_flash.tween_property(flash, "color:a", 0.3, 0.1)
	tw_flash.tween_property(flash, "color:a", 0.0, 0.35)

	# Wait for flash, then particles
	await get_tree().create_timer(0.5).timeout
	_submit_feedback.visible = false
	for c2 in _submit_feedback.get_children():
		c2.queue_free()

	# Particle celebration
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
		var tw := create_tween()
		tw.set_parallel(true)
		var target := p.position + Vector2(randf_range(-200, 200), randf_range(-300, 100))
		tw.tween_property(p, "position", target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_LINEAR)

	await get_tree().create_timer(0.5).timeout
	_submit_feedback.visible = false
	for c3 in _submit_feedback.get_children():
		c3.queue_free()
