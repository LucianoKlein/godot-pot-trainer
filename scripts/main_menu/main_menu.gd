extends Control

var _entry_panel: Control
var _entry_vbox: VBoxContainer
var _back_btn: Button
var _settings_btn: Button

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
	_entry_vbox.offset_top = -420
	_entry_vbox.offset_bottom = -60
	_entry_vbox.add_theme_constant_override("separation", 24)
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

		_logout_btn = _make_entry_btn(Locale.tr_key("logout"), Color(0.08, 0.08, 0.10, 0.82), Color(0.68, 0.45, 0.20))
		_logout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_logout_btn.pressed.connect(_on_logout_pressed)
		_entry_vbox.add_child(_logout_btn)
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


func _on_logout_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	_login_panel_mgr.show_logout_confirm()


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
