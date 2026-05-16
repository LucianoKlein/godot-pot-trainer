extends Control

var _entry_panel: Control
var _entry_vbox: VBoxContainer
var _back_btn: Button
var _settings_btn: Button
var _subscription_panel: Control
var _pending_purchase := false

# Delegated managers
var _login_panel_mgr: Node
var _settings_panel_mgr: Node
var _login_status_area: HBoxContainer
var _login_status_lbl: Label
var _logout_btn: Button

# Debug backdoor
var _debug_click_count := 0
var _debug_click_timer := 0.0
const DEBUG_CLICK_THRESHOLD := 20
const DEBUG_CLICK_TIMEOUT := 3.0


func _ready() -> void:
	var login_script := load("res://scripts/main_menu/login_panel.gd")
	var login_node := Node.new()
	login_node.set_script(login_script)
	_login_panel_mgr = login_node
	_login_panel_mgr.setup(self, _make_entry_btn)
	_login_panel_mgr.login_status_changed.connect(_on_login_status_changed)
	_login_panel_mgr.play_sfx_requested.connect(_play_sfx)
	_login_panel_mgr.connect_firebase_signals()
	_build_ui()
	GameManager.language_changed.connect(_on_language_changed)
	FirebaseAuth.services_loaded.connect(_on_services_loaded)
	SubscriptionManager.subscription_changed.connect(_on_subscription_changed)
	SubscriptionManager.purchase_success.connect(_on_purchase_success)
	SubscriptionManager.purchase_failed.connect(_on_purchase_failed_ui)
	if FirebaseAuth.is_logged_in:
		_try_use_cached_permissions()
	if GameManager.open_subscription_on_menu:
		GameManager.open_subscription_on_menu = false
		_entry_panel.visible = false
		_subscription_panel.visible = true
		_back_btn.visible = true


func _process(delta: float) -> void:
	if _debug_click_timer > 0.0:
		_debug_click_timer -= delta
		if _debug_click_timer <= 0.0:
			_debug_click_count = 0
	_login_panel_mgr.process(delta)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not FirebaseAuth.is_logged_in:
			_debug_click_count += 1
			_debug_click_timer = DEBUG_CLICK_TIMEOUT
			if _debug_click_count >= DEBUG_CLICK_THRESHOLD:
				_debug_click_count = 0
				_activate_debug_mode()


func _build_ui() -> void:
	# Background image
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var bg_tex := load("res://assets/ui/bg/main_bg.jpg")
	if bg_tex:
		bg.texture = bg_tex
	else:
		var fallback := ColorRect.new()
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.color = Color(0.05, 0.08, 0.05)
		add_child(fallback)
	add_child(bg)

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.30)
	add_child(overlay)

	# Title
	var title := Label.new()
	title.text = Locale.tr_key("title")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.94, 0.80, 0.31))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 28
	title.offset_bottom = 80
	add_child(title)

	# --- Entry panel ---
	_entry_panel = Control.new()
	_entry_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_entry_panel.offset_top = 100
	add_child(_entry_panel)

	_entry_vbox = VBoxContainer.new()
	# Anchor to bottom-left
	_entry_vbox.anchor_left = 0.0
	_entry_vbox.anchor_top = 1.0
	_entry_vbox.anchor_right = 0.0
	_entry_vbox.anchor_bottom = 1.0
	_entry_vbox.offset_left = 60
	_entry_vbox.offset_right = 500
	_entry_vbox.offset_top = -560
	_entry_vbox.offset_bottom = -40
	_entry_vbox.add_theme_constant_override("separation", 16)
	_entry_panel.add_child(_entry_vbox)

	# Spacer to push content to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_vbox.add_child(spacer)

	# Login status area
	_login_status_area = HBoxContainer.new()
	_login_status_area.add_theme_constant_override("separation", 10)
	_login_status_area.alignment = BoxContainer.ALIGNMENT_BEGIN
	_login_status_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_vbox.add_child(_login_status_area)

	_build_login_status()

	# --- Settings panel (delegated to SettingsPanel) ---
	var settings_script := load("res://scripts/main_menu/settings_panel.gd")
	var settings_node := Node.new()
	settings_node.set_script(settings_script)
	_settings_panel_mgr = settings_node
	_settings_panel_mgr.setup(self, _make_entry_btn)
	_settings_panel_mgr.layout_pressed.connect(_on_layout_pressed)
	_settings_panel_mgr.build()

	# --- Subscription panel (hidden initially) ---
	_subscription_panel = Control.new()
	_subscription_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_subscription_panel.offset_top = 80
	_subscription_panel.visible = false
	add_child(_subscription_panel)
	_build_subscription_panel()

	# Back button — top-left
	_back_btn = _make_toolbar_btn(Locale.tr_key("back"), Color(0.08, 0.08, 0.10, 0.82), Color(0.55, 0.25, 0.15))
	_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_btn.offset_top = 16
	_back_btn.offset_left = 16
	_back_btn.offset_bottom = 72
	_back_btn.offset_right = 200
	_back_btn.visible = false
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)


# =============================================================================
# Callbacks
# =============================================================================

func _play_sfx(path: String) -> void:
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.play_sfx(path)


func _on_new_game_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	GameManager.is_guest_mode = false
	GameManager.change_state(GameManager.State.PLAYING)
	get_tree().root.get_node("Main").switch_scene("res://scenes/game/game_table.tscn")


func _on_guest_mode_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	GameManager.is_guest_mode = true
	GameManager.change_state(GameManager.State.PLAYING)
	get_tree().root.get_node("Main").switch_scene("res://scenes/game/game_table.tscn")


func _on_settings_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	_entry_panel.visible = false
	_settings_panel_mgr.panel.visible = true
	_back_btn.visible = true


func _on_back_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	_settings_panel_mgr.panel.visible = false
	_subscription_panel.visible = false
	_back_btn.visible = false
	_entry_panel.visible = true


func _on_layout_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	GameManager.pending_layout_mode = true
	GameManager.change_state(GameManager.State.PLAYING)
	get_tree().root.get_node("Main").switch_scene("res://scenes/game/game_table.tscn")


# =============================================================================
# Login status & panel
# =============================================================================

func _build_login_status() -> void:
	for c in _login_status_area.get_children():
		_login_status_area.remove_child(c)
		c.queue_free()
	for c in _entry_vbox.get_children():
		if c != _login_status_area and c.size_flags_vertical != Control.SIZE_EXPAND_FILL:
			_entry_vbox.remove_child(c)
			c.queue_free()
	if _logout_btn and is_instance_valid(_logout_btn):
		_logout_btn.queue_free()
		_logout_btn = null

	if FirebaseAuth.is_logged_in:
		_login_status_lbl = Label.new()
		if not FirebaseAuth.user_display_name.is_empty():
			_login_status_lbl.text = FirebaseAuth.user_display_name
		else:
			_login_status_lbl.text = FirebaseAuth.user_email
		_login_status_lbl.add_theme_font_size_override("font_size", 24)
		_login_status_lbl.add_theme_color_override("font_color", Color(0.88, 0.74, 0.30))
		_login_status_lbl.clip_text = true
		_login_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_login_status_area.add_child(_login_status_lbl)

		var new_game_btn := _make_entry_btn(Locale.tr_key("start_game"), Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
		new_game_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_game_btn.pressed.connect(_on_new_game_pressed)
		_entry_vbox.add_child(new_game_btn)

		_settings_btn = _make_entry_btn(Locale.tr_key("settings"), Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
		_settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_settings_btn.pressed.connect(_on_settings_pressed)
		_entry_vbox.add_child(_settings_btn)

		if not SubscriptionManager.is_subscribed():
			var sub_btn := _make_entry_btn(_t("Subscribe", "订阅"), Color(0.08, 0.08, 0.10, 0.82), Color(0.90, 0.72, 0.28))
			sub_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sub_btn.pressed.connect(_on_subscribe_pressed)
			_entry_vbox.add_child(sub_btn)

		_logout_btn = _make_entry_btn(Locale.tr_key("logout"), Color(0.08, 0.08, 0.10, 0.82), Color(0.68, 0.45, 0.20))
		_logout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_logout_btn.pressed.connect(_on_logout_pressed)
		_entry_vbox.add_child(_logout_btn)

		var quit_btn := _make_entry_btn(Locale.tr_key("quit"), Color(0.08, 0.08, 0.10, 0.82), Color(0.55, 0.25, 0.15))
		quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quit_btn.pressed.connect(_on_quit_pressed)
		_entry_vbox.add_child(quit_btn)
	else:
		var login_btn := _make_entry_btn(Locale.tr_key("login"), Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
		login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		login_btn.pressed.connect(func() -> void:
			_play_sfx("res://assets/music/sounds_effect/button.ogg")
			_login_panel_mgr.show()
		)
		_entry_vbox.add_child(login_btn)

		var guest_btn := _make_entry_btn(Locale.tr_key("guest_mode"), Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
		guest_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		guest_btn.pressed.connect(_on_guest_mode_pressed)
		_entry_vbox.add_child(guest_btn)

		_settings_btn = _make_entry_btn(Locale.tr_key("settings"), Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
		_settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_settings_btn.pressed.connect(_on_settings_pressed)
		_entry_vbox.add_child(_settings_btn)

		var sub_btn2 := _make_entry_btn(_t("Subscribe", "订阅"), Color(0.08, 0.08, 0.10, 0.82), Color(0.90, 0.72, 0.28))
		sub_btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_btn2.pressed.connect(_on_subscribe_pressed)
		_entry_vbox.add_child(sub_btn2)

		var quit_btn2 := _make_entry_btn(Locale.tr_key("quit"), Color(0.08, 0.08, 0.10, 0.82), Color(0.55, 0.25, 0.15))
		quit_btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quit_btn2.pressed.connect(_on_quit_pressed)
		_entry_vbox.add_child(quit_btn2)


func _on_logout_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	_login_panel_mgr.show_logout_confirm()


func _on_quit_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	get_tree().quit()


func _on_login_status_changed() -> void:
	_build_login_status()


func _activate_debug_mode() -> void:
	print("Debug mode activated - New Game unlocked")
	_play_sfx("res://assets/music/sounds_effect/button.ogg")


func _on_language_changed() -> void:
	# Rebuild the entire UI to apply new language
	for c in get_children():
		c.queue_free()
	_build_ui()
	_build_login_status()


# =============================================================================
# Button helpers
# =============================================================================

func _make_entry_btn(text: String, bg: Color, border: Color) -> Button:
	return _make_menu_btn(text, bg, border, Vector2(340, 80), 28, 14)


func _make_toolbar_btn(text: String, bg: Color, border: Color) -> Button:
	return _make_menu_btn(text, bg, border, Vector2(180, 56), 22, 12)


func _make_menu_btn(text: String, bg: Color, border: Color, min_size: Vector2, font_size: int, margin: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	var s := UiFactory.make_stylebox(bg, 6, margin, border, 1)
	btn.add_theme_stylebox_override("normal", s)
	var h := UiFactory.make_stylebox(Color(0.14, 0.13, 0.10, 0.85), 6, margin, Color(border.r + 0.15, border.g + 0.12, border.b + 0.05), 1)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus", s)
	return btn


func _t(en: String, zh: String) -> String:
	return zh if GameManager.language == "zh" else en


# =============================================================================
# Subscription
# =============================================================================

func _on_subscribe_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	_entry_panel.visible = false
	_subscription_panel.visible = true
	_back_btn.visible = true


func _build_subscription_panel() -> void:
	if SubscriptionManager.is_subscribed():
		var active_lbl := Label.new()
		active_lbl.text = _t("You are subscribed — Pot Trainer Pro!", "您已订阅 — Pot Trainer 专业版！")
		active_lbl.add_theme_font_size_override("font_size", 32)
		active_lbl.add_theme_color_override("font_color", Color(0.90, 0.72, 0.28))
		active_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		active_lbl.set_anchors_preset(Control.PRESET_CENTER)
		active_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		active_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
		_subscription_panel.add_child(active_lbl)
		return

	var title := Label.new()
	title.text = _t("Unlock Full Access", "解锁完整功能")
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.32))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10
	title.offset_bottom = 50
	_subscription_panel.add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 60
	center.offset_bottom = -80
	_subscription_panel.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.04, 0.95)
	style.border_color = Color(0.54, 0.43, 0.17, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "Pot Trainer Pro"
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.45))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text = SubscriptionManager.get_price_display() + _t("/mo", "/月")
	price_lbl.add_theme_font_size_override("font_size", 36)
	price_lbl.add_theme_color_override("font_color", Color(0.90, 0.72, 0.28))
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(price_lbl)

	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vbox.add_child(sep)

	var features_lbl := Label.new()
	features_lbl.text = _t(
		"Unlimited practice questions\nNo ads interruptions\nAll training modes\nFull pot-limit training",
		"无限练习题目\n无广告打断\n全部训练模式\n完整底池限注训练"
	)
	features_lbl.add_theme_font_size_override("font_size", 20)
	features_lbl.add_theme_color_override("font_color", Color(0.82, 0.72, 0.40))
	features_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(features_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var buy_btn := Button.new()
	buy_btn.text = _t("Subscribe", "订阅")
	buy_btn.custom_minimum_size = Vector2(0, 60)
	buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_btn.add_theme_font_size_override("font_size", 24)
	buy_btn.add_theme_color_override("font_color", Color(0.06, 0.05, 0.03))
	buy_btn.add_theme_color_override("font_hover_color", Color(0.04, 0.03, 0.02))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.90, 0.72, 0.28)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(10)
	buy_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 0.82, 0.38)
	btn_hover.set_corner_radius_all(8)
	btn_hover.set_content_margin_all(10)
	buy_btn.add_theme_stylebox_override("hover", btn_hover)
	buy_btn.add_theme_stylebox_override("pressed", btn_hover)
	buy_btn.pressed.connect(_on_tier_purchase)
	vbox.add_child(buy_btn)

	var restore_btn := Button.new()
	restore_btn.text = _t("Restore Purchases", "恢复购买")
	restore_btn.flat = true
	restore_btn.add_theme_font_size_override("font_size", 20)
	restore_btn.add_theme_color_override("font_color", Color(0.70, 0.58, 0.24))
	restore_btn.add_theme_color_override("font_hover_color", Color(0.90, 0.76, 0.30))
	restore_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	restore_btn.offset_top = -50
	restore_btn.offset_bottom = -10
	restore_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	restore_btn.pressed.connect(_on_restore_pressed)
	_subscription_panel.add_child(restore_btn)


func _on_tier_purchase() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	if not FirebaseAuth.is_logged_in:
		_pending_purchase = true
		_login_panel_mgr.show()
		return
	if SubscriptionManager.is_subscribed():
		_refresh_subscription_panel()
		return
	SubscriptionManager.purchase()


func _on_restore_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	SubscriptionManager.restore_purchases()


func _refresh_subscription_panel() -> void:
	if _subscription_panel == null:
		return
	for c in _subscription_panel.get_children():
		_subscription_panel.remove_child(c)
		c.queue_free()
	_build_subscription_panel()


func _on_services_loaded() -> void:
	if not FirebaseAuth.is_logged_in:
		return
	_build_login_status()
	_refresh_subscription_panel()
	if _pending_purchase:
		_pending_purchase = false
		if SubscriptionManager.is_subscribed():
			_refresh_subscription_panel()
		else:
			SubscriptionManager.purchase()


## 尝试使用本地缓存的权限（App启动时有缓存直接用，后台静默刷新）
func _try_use_cached_permissions() -> void:
	var cache = FirebaseAuth.load_permissions_cache()
	if cache == null:
		SubscriptionManager._dlog("MENU _try_use_cached_permissions → no valid cache")
		return
	SubscriptionManager._dlog("MENU _try_use_cached_permissions → applying cache")
	FirebaseAuth.apply_permissions_cache(cache)
	_build_login_status()
	_refresh_subscription_panel()
	FirebaseAuth.resolve_permissions()


func _on_subscription_changed(_is_active: bool) -> void:
	_refresh_subscription_panel()
	_build_login_status()


func _on_purchase_success(_product_id: String) -> void:
	_refresh_subscription_panel()
	_build_login_status()
	DialogQueue.show(func() -> void: _create_menu_purchase_success_dialog())


func _on_purchase_failed_ui(error_msg: String) -> void:
	if "cancel" in error_msg.to_lower() or "cancelled" in error_msg.to_lower():
		return
	var toast := Label.new()
	toast.text = _t("Purchase failed: ", "购买失败：") + error_msg
	toast.add_theme_font_size_override("font_size", 22)
	toast.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_top = -80
	toast.offset_bottom = -40
	toast.z_index = 200
	add_child(toast)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)


func _create_menu_purchase_success_dialog() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -180
	panel.offset_bottom = 180
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	ps.border_color = Color(0.90, 0.72, 0.28)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(12)
	ps.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var check := Label.new()
	check.text = "✓"
	check.add_theme_font_size_override("font_size", 64)
	check.add_theme_color_override("font_color", Color(0.90, 0.72, 0.28))
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(check)

	var title := Label.new()
	title.text = _t("Subscription Activated!", "订阅已激活！")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var tier_lbl := Label.new()
	tier_lbl.text = "Pot Trainer Pro"
	tier_lbl.add_theme_font_size_override("font_size", 24)
	tier_lbl.add_theme_color_override("font_color", Color(0.90, 0.72, 0.28))
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tier_lbl)

	var ok_btn := Button.new()
	ok_btn.text = _t("Get Started", "开始使用")
	ok_btn.custom_minimum_size = Vector2(0, 56)
	ok_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ok_btn.add_theme_font_size_override("font_size", 24)
	ok_btn.add_theme_color_override("font_color", Color(0.06, 0.05, 0.03))
	var ok_style := StyleBoxFlat.new()
	ok_style.bg_color = Color(0.90, 0.72, 0.28)
	ok_style.set_corner_radius_all(8)
	ok_style.set_content_margin_all(10)
	ok_btn.add_theme_stylebox_override("normal", ok_style)
	var ok_hover := StyleBoxFlat.new()
	ok_hover.bg_color = Color(1.0, 0.82, 0.38)
	ok_hover.set_corner_radius_all(8)
	ok_hover.set_content_margin_all(10)
	ok_btn.add_theme_stylebox_override("hover", ok_hover)
	ok_btn.add_theme_stylebox_override("pressed", ok_hover)
	ok_btn.pressed.connect(func() -> void:
		overlay.queue_free()
	)
	vbox.add_child(ok_btn)
	DialogQueue.register(overlay)
