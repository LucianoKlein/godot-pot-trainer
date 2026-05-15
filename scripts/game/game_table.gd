extends Control

func _t(en: String, zh: String) -> String:
	return zh if GameManager.language == "zh" else en

const CardDisplayScene := preload("res://scenes/game/components/card_display.tscn")
const LayoutEditorScript := preload("res://scripts/game/layout_editor.gd")
const SeatManagerScript := preload("res://scripts/ui/managers/seat_manager.gd")
const ChipManagerScript := preload("res://scripts/ui/managers/chip_manager.gd")
const DealerButtonScript := preload("res://scripts/ui/components/dealer_button.gd")
const TableCenterScript := preload("res://scripts/game/components/table_center.gd")
const ControlPanelManagerScript := preload("res://scripts/game/ui/control_panel_manager.gd")
const QuestionPanelManagerScript := preload("res://scripts/game/ui/question_panel_manager.gd")
const GameOverManagerScript := preload("res://scripts/game/ui/game_over_manager.gd")
const ActionBoxManagerScript := preload("res://scripts/game/ui/action_box_manager.gd")
const AdDialogManagerScript := preload("res://scripts/game/ui/ad_dialog_manager.gd")
const AuthDialogManagerScript := preload("res://scripts/game/systems/auth_dialog_manager.gd")

# --- Node references ---
var _bg: TextureRect
var _chairs: Array[TextureRect] = []
var _table_overlay: Control
var _seat_mgr: SeatManager
var _chip_mgr: ChipManager
var _dealer_btn: DealerButton
var _control_panel_manager: RefCounted
var _table_center: RefCounted
var _layout_editor: RefCounted

# --- Delegated managers ---
var _question_mgr: RefCounted
var _game_over_mgr: RefCounted
var _action_box_mgr: RefCounted
var _ad_dialog_mgr: RefCounted
var _auth_dialog_mgr: RefCounted

# --- Pending purchase (login gate) ---
var _pending_purchase: bool = false


func _ready() -> void:
	var vp_size := get_viewport_rect().size
	TableLayout.set_viewport_size(vp_size)
	_bg = $Background
	for i in range(1, 10):
		_chairs.append(get_node("Chair%d" % i) as TextureRect)
	GameManager.init_game()
	_build_table_overlay()
	_seat_mgr = SeatManagerScript.new().setup(self, _table_overlay, _chairs)
	_seat_mgr.build()
	_chip_mgr = ChipManagerScript.new().setup(self, _table_overlay)
	_chip_mgr.build()
	_dealer_btn = DealerButtonScript.new().setup(self, _table_overlay)
	_dealer_btn.build()
	_table_center = TableCenterScript.new().setup(self, _table_overlay)
	_table_center.build()
	_question_mgr = QuestionPanelManagerScript.new().setup(self)
	_question_mgr.build()
	_control_panel_manager = ControlPanelManagerScript.new().setup(self)
	_control_panel_manager.build(_on_back_to_menu_pressed)
	_connect_control_panel_signals()
	var seats := _seat_mgr.get_seats()
	_layout_editor = LayoutEditorScript.new().setup(self, _table_overlay, _control_panel_manager.layout_btn, _control_panel_manager.control_panel, _on_back_to_menu_pressed, {
		"avatars": seats.map(func(s: RefCounted) -> TextureRect: return s.avatar),
		"chairs": _chairs,
		"bet_labels": seats.map(func(s: RefCounted) -> Label: return s.bet_label),
		"stack_labels": seats.map(func(s: RefCounted) -> Label: return s.stack_label),
		"dealer_button": _dealer_btn.get_button(),
		"pot_display": _table_center.pot_display,
		"street_badge": _table_center.street_badge,
		"community_cards_container": _table_center.community_cards_container,
		"purple_stacks": seats.map(func(s: RefCounted) -> Node2D: return s.purple_stack),
		"black_stacks": seats.map(func(s: RefCounted) -> Node2D: return s.black_stack),
		"green_stacks": seats.map(func(s: RefCounted) -> Node2D: return s.green_stack),
		"red_stacks_1": seats.map(func(s: RefCounted) -> Node2D: return s.red_stack_1),
		"red_stacks_2": seats.map(func(s: RefCounted) -> Node2D: return s.red_stack_2),
		"red_stacks_3": seats.map(func(s: RefCounted) -> Node2D: return s.red_stack_3),
		"white_stacks": seats.map(func(s: RefCounted) -> Node2D: return s.white_stack),
		"player_bet_chips": seats.map(func(s: RefCounted) -> Control: return s.bet_chips_container),
		"ordered_bet_chips": seats.map(func(s: RefCounted) -> Node2D: return s.ordered_bet_chips),
		"pot_chip_area": _chip_mgr.get_pot_chip_area(),
		"chip_record": _chip_mgr.get_chip_record(),
		"action_boxes": seats.map(func(s: RefCounted) -> Label: return s.action_box),
	})
	_layout_editor.build()
	_game_over_mgr = GameOverManagerScript.new().setup(self)
	_action_box_mgr = ActionBoxManagerScript.new().setup(self, seats)
	_ad_dialog_mgr = AdDialogManagerScript.new(self)
	_auth_dialog_mgr = AuthDialogManagerScript.new(self)
	_connect_signals()
	GameManager.load_layout_from_file()
	# Apply persisted display_mode to UI after layout load
	_on_display_mode_changed(GameManager.display_mode)
	_refresh_all()
	if GameManager.pending_layout_mode:
		GameManager.pending_layout_mode = false
		_layout_editor.toggle()
	else:
		if GuestModeManager.is_gate_locked():
			call_deferred("_show_gate_subscribe")



func _build_table_overlay() -> void:
	_table_overlay = Control.new()
	_table_overlay.name = "TableOverlay"
	_table_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_table_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_table_overlay)


func _play_sfx(path: String) -> void:
	var main_node: Node = get_tree().root.get_node_or_null("Main")
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
		GameManager.switch_layout_mode(GameManager.blinds_mode)
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
	GuestModeManager.guest_ad_required.connect(_on_guest_ad_required)
	AdMobManager.rewarded_ad_completed.connect(_on_ad_completed)
	AdMobManager.rewarded_ad_closed.connect(_on_ad_closed)
	AdMobManager.rewarded_ad_loaded.connect(_on_ad_loaded)
	AdMobManager.rewarded_ad_failed_to_load.connect(_on_ad_failed_to_load)
	AdMobManager.rewarded_ad_failed_to_show.connect(_on_ad_failed_to_show)
	SubscriptionManager.purchase_success.connect(_on_purchase_success)
	SubscriptionManager.purchase_failed.connect(_on_purchase_failed)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_pot_changed(_new_pot: int) -> void:
	_table_center.refresh_pot(_chip_mgr.get_pot_chip_area())
	_chip_mgr.refresh_chip_record()

func _on_street_changed(_new_street: String) -> void:
	_table_center.refresh_street()
	_seat_mgr.refresh_all()

func _on_community_cards_changed() -> void:
	_table_center.refresh_community_cards()

func _on_current_player_changed(_index: int) -> void:
	_seat_mgr.refresh_current_player()

func _on_last_action_changed(text: String) -> void:
	_table_center.set_last_action(text)

func _on_dealer_moved(_index: int) -> void:
	_dealer_btn.refresh()

func _on_layout_changed() -> void:
	# Skip heavy refresh during active drag — the drag handler already moves the node directly
	if _layout_editor.is_dragging:
		return
	_refresh_all()
	# Re-apply layout editor visibility after _refresh_all resets everything visible
	if GameManager.layout_mode:
		_layout_editor.apply_all_visibility()
	# Update seat positions and chip scales
	_seat_mgr.update_positions()
	# Update pot chip scale
	_chip_mgr.update_pot_chip_scale()
	# Re-enable drag and refresh preview after chip stacks are rebuilt
	# (fixes stale DragOverlay issue for both chips and preview elements like hole cards)
	if GameManager.layout_mode:
		_layout_editor.rebuild_drag_connections()

func _on_game_reset() -> void:
	_question_mgr.on_game_reset()
	_game_over_mgr.hide()
	_refresh_all()

func _on_question_appeared(question: Dictionary) -> void:
	_question_mgr.on_question_appeared(question)

func _on_question_cleared() -> void:
	_question_mgr.on_question_cleared()
	_seat_mgr.refresh_all()

func _on_answer_result(correct: bool, user_answer: int, expected: int) -> void:
	_question_mgr.on_answer_result(correct, user_answer, expected)

func _on_game_over() -> void:
	_seat_mgr.refresh_all()
	# In game mode, show a prominent overlay so the user knows the hand is done
	if GameManager.config.training_mode == "game":
		_game_over_mgr.show()

func _on_display_mode_changed(_mode: String) -> void:
	_seat_mgr.refresh_all()
	_table_center.refresh_pot(_chip_mgr.get_pot_chip_area())
	_chip_mgr.refresh_chip_record()
	_control_panel_manager._update_display_mode_styles()

func _on_hole_cards_changed() -> void:
	_seat_mgr.refresh_all()

func _on_npc_acted(seat: int, _action: String, _amount: int) -> void:
	_seat_mgr.refresh_all()
	_seat_mgr.refresh_current_player()
	# In game mode, auto-hide the action box after 1 second
	if GameManager.config.training_mode == "game":
		var physical_seat: int = GameManager.get_physical_seat(seat)
		_action_box_mgr.auto_hide(physical_seat)


# =============================================================================
# Guest Mode Ad System
# =============================================================================

func _on_guest_ad_required() -> void:
	if GuestModeManager.is_subscribed():
		return
	_show_gate_subscribe()


func _show_gate_subscribe() -> void:
	_show_subscribe_popup()


func _on_ad_completed() -> void:
	_ad_dialog_mgr.on_ad_completed()


func _on_ad_closed() -> void:
	_ad_dialog_mgr.on_ad_closed()


func _on_ad_loaded() -> void:
	_ad_dialog_mgr.on_ad_loaded()


func _on_ad_failed_to_load(error: String) -> void:
	_ad_dialog_mgr.on_ad_failed_to_load(error)


func _on_ad_failed_to_show(error: String) -> void:
	_ad_dialog_mgr.on_ad_failed_to_show(error)


func _on_purchase_success(_product_id: String) -> void:
	GuestModeManager.unlock_gate()
	_show_purchase_success_dialog()


func _on_purchase_failed(error_msg: String) -> void:
	if "cancel" in error_msg.to_lower() or "cancelled" in error_msg.to_lower():
		return
	_show_purchase_failed_toast(error_msg)


func _show_purchase_success_dialog() -> void:
	DialogQueue.show(func() -> void: _create_purchase_success_dialog())

func _create_purchase_success_dialog() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -180
	panel.offset_bottom = 180
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	ps.border_color = Color(0.90, 0.72, 0.28)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(12)
	ps.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var check_lbl := Label.new()
	check_lbl.text = "✓"
	check_lbl.add_theme_font_size_override("font_size", 72)
	check_lbl.add_theme_color_override("font_color", Color(0.90, 0.72, 0.28))
	check_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(check_lbl)
	check_lbl.scale = Vector2(0.3, 0.3)
	check_lbl.pivot_offset = Vector2(check_lbl.size.x / 2.0, check_lbl.size.y / 2.0)
	var pop_tw := check_lbl.create_tween()
	pop_tw.tween_property(check_lbl, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var title := Label.new()
	title.text = _t("Subscription Activated!", "订阅已激活！")
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var tier_lbl := Label.new()
	tier_lbl.text = "Pot Trainer Pro"
	tier_lbl.add_theme_font_size_override("font_size", 24)
	tier_lbl.add_theme_color_override("font_color", Color(0.90, 0.72, 0.28))
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tier_lbl)

	var expiry_text := ""
	if SubscriptionManager.expires_at > 0.0:
		var dt := Time.get_datetime_dict_from_unix_time(int(SubscriptionManager.expires_at))
		expiry_text = "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	else:
		var dt := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + 30 * 86400)
		expiry_text = "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	var info_lbl := Label.new()
	info_lbl.text = _t("Valid until ", "有效期至 ") + expiry_text
	info_lbl.add_theme_font_size_override("font_size", 22)
	info_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45))
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_lbl)

	var btn := Button.new()
	btn.text = _t("Get Started", "开始使用")
	btn.custom_minimum_size = Vector2(0, 56)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(0.06, 0.05, 0.03))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.90, 0.72, 0.28)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 0.82, 0.38)
	btn_hover.set_corner_radius_all(8)
	btn_hover.set_content_margin_all(10)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_hover)
	btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		overlay.queue_free()
	)
	vbox.add_child(btn)

	add_child(overlay)
	DialogQueue.register(overlay)


func _show_purchase_failed_toast(error_msg: String) -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -120
	panel.offset_bottom = 120
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	ps.border_color = Color(0.85, 0.30, 0.30)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(12)
	ps.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", ps)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var _dragging := false
	var _drag_offset := Vector2.ZERO
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging = true
					_drag_offset = event.position
				else:
					_dragging = false
		elif event is InputEventMouseMotion and _dragging:
			panel.position += event.relative
	)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = _t("Purchase Failed", "购买失败")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg_lbl := Label.new()
	msg_lbl.text = error_msg
	msg_lbl.add_theme_font_size_override("font_size", 20)
	msg_lbl.add_theme_color_override("font_color", Color(0.80, 0.70, 0.50))
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_lbl)

	var close_btn := Button.new()
	close_btn.text = _t("Close", "关闭")
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.15, 0.12, 0.08)
	close_style.border_color = Color(0.50, 0.40, 0.16)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(6)
	close_style.set_content_margin_all(8)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(func() -> void: overlay.queue_free())
	vbox.add_child(close_btn)


func _on_gate_login_pressed() -> void:
	_auth_dialog_mgr.show_auth_dialog(_on_gate_login_success, _show_gate_subscribe)


func _on_gate_login_success() -> void:
	var email := FirebaseAuth.user_email
	_show_login_success_toast(email)
	FirebaseAuth.services_loaded.connect(_on_gate_services_check, CONNECT_ONE_SHOT)
	FirebaseAuth.fetch_services()


func _on_gate_services_check() -> void:
	if GuestModeManager.is_subscribed():
		GuestModeManager.unlock_gate()
		_pending_purchase = false
	elif _pending_purchase:
		_pending_purchase = false
		SubscriptionManager.purchase()
	else:
		_show_gate_subscribe()


func _show_login_success_toast(email: String) -> void:
	var label := Label.new()
	label.text = email + _t(" logged in", " 登录成功")
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 40
	label.offset_bottom = 80
	label.z_index = 520
	add_child(label)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)


# =============================================================================
# Guest Subscribe Popup (广告弹窗关闭时触发)
# =============================================================================

func _show_subscribe_popup() -> void:
	DialogQueue.show(func() -> void: _create_subscribe_popup())


func _create_subscribe_popup() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	panel_style.border_color = Color(0.90, 0.72, 0.28)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 42
	panel_style.content_margin_right = 42
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = _t("Unlock Full Access", "解锁完整功能")
	title.add_theme_font_size_override("font_size", 45)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = _t("Subscribe to unlock unlimited practice\nwith no ads.", "订阅解锁无限练习，无广告。")
	msg.add_theme_font_size_override("font_size", 30)
	msg.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	card_style.border_color = Color(0.90, 0.72, 0.28)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.set_content_margin_all(30)
	card.add_theme_stylebox_override("panel", card_style)
	vbox.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 18)
	card.add_child(card_vbox)

	var name_lbl := Label.new()
	name_lbl.text = _t("Pot Trainer Pro", "Pot Trainer 专业版")
	name_lbl.add_theme_font_size_override("font_size", 39)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.72, 0.28))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "$12.99" + _t("/mo", "/月")
	price_lbl.add_theme_font_size_override("font_size", 48)
	price_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(price_lbl)

	var features_lbl := Label.new()
	features_lbl.text = _t("✓ Unlimited practice\n✓ No ads\n✓ All training modes", "✓ 无限练习\n✓ 无广告\n✓ 全部训练模式")
	features_lbl.add_theme_font_size_override("font_size", 27)
	features_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	features_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	features_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(features_lbl)

	var buy_btn := Button.new()
	buy_btn.text = _t("Subscribe", "订阅")
	buy_btn.custom_minimum_size = Vector2(0, 75)
	buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_btn.add_theme_font_size_override("font_size", 33)
	buy_btn.add_theme_color_override("font_color", Color(0.06, 0.05, 0.03))
	var buy_style := StyleBoxFlat.new()
	buy_style.bg_color = Color(0.90, 0.72, 0.28)
	buy_style.set_corner_radius_all(6)
	buy_style.set_content_margin_all(15)
	buy_btn.add_theme_stylebox_override("normal", buy_style)
	var buy_hover := StyleBoxFlat.new()
	buy_hover.bg_color = Color(0.90, 0.72, 0.28).lightened(0.2)
	buy_hover.set_corner_radius_all(6)
	buy_hover.set_content_margin_all(15)
	buy_btn.add_theme_stylebox_override("hover", buy_hover)
	buy_btn.add_theme_stylebox_override("pressed", buy_hover)
	buy_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		overlay.queue_free()
		if not FirebaseAuth.is_logged_in:
			_pending_purchase = true
			_on_gate_login_pressed()
		else:
			SubscriptionManager.purchase()
	)
	card_vbox.add_child(buy_btn)

	var ad_link := Button.new()
	ad_link.text = _t("▶ Watch Ad to unlock %d questions" % GuestModeManager.GUEST_QUESTIONS_PER_AD, "▶ 看广告解锁 %d 题" % GuestModeManager.GUEST_QUESTIONS_PER_AD)
	ad_link.flat = true
	ad_link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ad_link.add_theme_font_size_override("font_size", 27)
	ad_link.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	ad_link.add_theme_color_override("font_hover_color", Color(0.70, 0.85, 1.0))
	ad_link.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		overlay.queue_free()
		_ad_dialog_mgr.load_and_show_ad()
	)
	vbox.add_child(ad_link)

	if not FirebaseAuth.is_logged_in:
		var login_row := HBoxContainer.new()
		login_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(login_row)
		var login_hint := Label.new()
		login_hint.text = _t("Already have an account?", "已有账号？")
		login_hint.add_theme_font_size_override("font_size", 27)
		login_hint.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
		login_row.add_child(login_hint)
		var login_link := Button.new()
		login_link.text = _t(" Login", " 登录")
		login_link.flat = true
		login_link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		login_link.add_theme_font_size_override("font_size", 27)
		login_link.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
		login_link.add_theme_color_override("font_hover_color", Color(0.70, 0.85, 1.0))
		login_link.pressed.connect(func() -> void:
			_play_sfx("res://assets/music/sounds_effect/button.ogg")
			overlay.queue_free()
			_on_gate_login_pressed()
		)
		login_row.add_child(login_link)

	var menu_btn := Button.new()
	menu_btn.text = _t("← Back to Menu", "← 返回主菜单")
	menu_btn.flat = true
	menu_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_btn.add_theme_font_size_override("font_size", 27)
	menu_btn.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
	menu_btn.add_theme_color_override("font_hover_color", Color(0.80, 0.72, 0.55))
	menu_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		overlay.queue_free()
		_on_back_to_menu_pressed()
	)
	vbox.add_child(menu_btn)

	add_child(overlay)
	DialogQueue.register(overlay)

func _on_start_pressed() -> void:
	_game_over_mgr.hide()
	_control_panel_manager.collapse_config()
	GameManager.start_game()

func _on_pause_pressed() -> void:
	GameManager.pause_game()

func _on_reset_pressed() -> void:
	GameManager.reset_game()
	GameManager.init_game()

func _on_back_to_menu_pressed() -> void:
	var main_node: Node = get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.play_sfx("res://assets/music/sounds_effect/button.ogg")
	# Ensure layout mode is fully exited before leaving
	if GameManager.layout_mode:
		_layout_editor.toggle()
	GameManager.reset_game()
	GameManager.change_state(GameManager.State.MENU)
	if main_node:
		main_node.switch_scene("res://scenes/main_menu/main_menu.tscn")


# =============================================================================
# REFRESH METHODS
# =============================================================================

func _refresh_all() -> void:
	_seat_mgr.refresh_all()
	_table_center.refresh_pot(_chip_mgr.get_pot_chip_area())
	_table_center.refresh_street()
	_dealer_btn.refresh()
	_table_center.refresh_community_cards()
	_seat_mgr.refresh_current_player()
	_chip_mgr.refresh_chip_record()
