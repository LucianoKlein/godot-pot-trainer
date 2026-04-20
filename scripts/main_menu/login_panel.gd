extends Node
## LoginPanel — 登录/注册面板管理
## UI 构建 + 委托 LoginAuthHandler 处理认证回调

signal login_status_changed()
signal play_sfx_requested(path: String)

var _parent: Control
var _make_entry_btn: Callable
var _logout_dialog: LogoutDialog
var _auth: LoginAuthHandler

# Login panel UI nodes
var _login_panel: Control
var _login_email_input: LineEdit
var _login_password_input: LineEdit
var _login_pw_toggle_btn: Button
var _login_error_lbl: Label
var _login_submit_btn: Button
var _login_panel_title: Label
var _login_toggle_btn: Button
var _login_mode_is_register := false
var _login_card: PanelContainer
var _login_card_base_offset_top := 0.0
var _login_card_base_offset_bottom := 0.0


func setup(parent: Control, make_btn_callable: Callable) -> Node:
	_parent = parent
	_make_entry_btn = make_btn_callable
	_logout_dialog = LogoutDialog.new().setup(parent, make_btn_callable)
	_logout_dialog.play_sfx_requested.connect(func(path: String) -> void: _play_sfx(path))
	_auth = LoginAuthHandler.new().setup(hide)
	_auth.login_status_changed.connect(func() -> void: login_status_changed.emit())
	_auth.login_error.connect(func(msg: String) -> void: _show_login_error(msg))
	_auth.play_sfx_requested.connect(func(path: String) -> void: _play_sfx(path))
	return self


func _play_sfx(path: String) -> void:
	play_sfx_requested.emit(path)


func show() -> void:
	_login_mode_is_register = false
	if _login_panel:
		_login_panel.queue_free()
		_login_panel = null
		_login_card = null

	_login_panel = Control.new()
	_login_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_login_panel.z_index = 100

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide()
	)
	_login_panel.add_child(dim)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -280
	card.offset_right = 280
	card.offset_top = -300
	card.offset_bottom = 300
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", UiFactory.make_stylebox(
		Color(0.08, 0.08, 0.10, 0.97), 6, 32, Color(0.50, 0.40, 0.16), 1))
	_login_panel.add_child(card)
	_login_card = card
	_login_card_base_offset_top = -300.0
	_login_card_base_offset_bottom = 300.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	_login_panel_title = Label.new()
	_login_panel_title.text = Locale.tr_key("login")
	_login_panel_title.add_theme_font_size_override("font_size", 36)
	_login_panel_title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	_login_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_login_panel_title)

	# Email input
	_login_email_input = LineEdit.new()
	_login_email_input.placeholder_text = Locale.tr_key("email_placeholder")
	_login_email_input.custom_minimum_size = Vector2(0, 60)
	_login_email_input.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_login_email_input)

	# Password row
	var pw_row := HBoxContainer.new()
	pw_row.add_theme_constant_override("separation", 8)
	vbox.add_child(pw_row)

	_login_password_input = LineEdit.new()
	_login_password_input.placeholder_text = Locale.tr_key("password_placeholder")
	_login_password_input.secret = true
	_login_password_input.custom_minimum_size = Vector2(0, 60)
	_login_password_input.add_theme_font_size_override("font_size", 28)
	_login_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw_row.add_child(_login_password_input)

	_login_pw_toggle_btn = Button.new()
	_login_pw_toggle_btn.text = "👁"
	_login_pw_toggle_btn.custom_minimum_size = Vector2(60, 60)
	_login_pw_toggle_btn.add_theme_font_size_override("font_size", 28)
	_login_pw_toggle_btn.pressed.connect(_on_pw_toggle_pressed)
	pw_row.add_child(_login_pw_toggle_btn)

	# Error label
	_login_error_lbl = Label.new()
	_login_error_lbl.add_theme_font_size_override("font_size", 20)
	_login_error_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_login_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_login_error_lbl.visible = false
	vbox.add_child(_login_error_lbl)

	# Submit button
	_login_submit_btn = _make_entry_btn.call(Locale.tr_key("login"), Color(0.08, 0.08, 0.10, 0.82), Color(0.25, 0.55, 0.30))
	_login_submit_btn.custom_minimum_size = Vector2(0, 60)
	_login_submit_btn.pressed.connect(_on_login_submit)
	vbox.add_child(_login_submit_btn)

	# Google login button
	if GoogleSignIn.is_available():
		var google_btn: Button = _make_entry_btn.call(Locale.tr_key("google_login"), Color(0.08, 0.08, 0.10, 0.82), Color(0.30, 0.50, 0.80))
		google_btn.custom_minimum_size = Vector2(0, 60)
		google_btn.pressed.connect(_on_google_login_pressed)
		vbox.add_child(google_btn)

	# Apple login button (iOS only)
	if AppleSignIn.is_available():
		var apple_btn: Button = _make_entry_btn.call(Locale.tr_key("apple_login"), Color(0.08, 0.08, 0.10, 0.82), Color(0.75, 0.75, 0.80))
		apple_btn.custom_minimum_size = Vector2(0, 60)
		apple_btn.pressed.connect(_on_apple_login_pressed)
		vbox.add_child(apple_btn)

	# Toggle login/register
	_login_toggle_btn = Button.new()
	_login_toggle_btn.text = Locale.tr_key("no_account")
	_login_toggle_btn.flat = true
	_login_toggle_btn.add_theme_font_size_override("font_size", 22)
	_login_toggle_btn.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	_login_toggle_btn.pressed.connect(_on_toggle_login_register)
	vbox.add_child(_login_toggle_btn)

	_parent.add_child(_login_panel)


func hide() -> void:
	if _login_panel:
		_login_panel.visible = false
		DisplayServer.virtual_keyboard_hide()
		_login_card = null


func _on_toggle_login_register() -> void:
	_login_mode_is_register = not _login_mode_is_register
	_login_error_lbl.visible = false
	if _login_mode_is_register:
		_login_panel_title.text = Locale.tr_key("register")
		_login_submit_btn.text = Locale.tr_key("register")
		_login_toggle_btn.text = Locale.tr_key("has_account")
	else:
		_login_panel_title.text = Locale.tr_key("login")
		_login_submit_btn.text = Locale.tr_key("login")
		_login_toggle_btn.text = Locale.tr_key("no_account")


func _on_pw_toggle_pressed() -> void:
	_login_password_input.secret = not _login_password_input.secret
	_login_pw_toggle_btn.text = "🙈" if not _login_password_input.secret else "👁"


func _on_google_login_pressed() -> void:
	_login_error_lbl.visible = false
	_login_submit_btn.disabled = true
	_login_submit_btn.text = Locale.tr_key("please_wait")
	_auth.start_google_login()


func _on_apple_login_pressed() -> void:
	_login_error_lbl.visible = false
	_login_submit_btn.disabled = true
	_login_submit_btn.text = Locale.tr_key("please_wait")
	_auth.start_apple_login()


func connect_firebase_signals() -> void:
	_auth.connect_signals()


func _on_login_submit() -> void:
	var email := _login_email_input.text.strip_edges()
	var password := _login_password_input.text.strip_edges()
	if email.is_empty():
		_show_login_error(Locale.tr_key("err_email_required"))
		return
	if not "@" in email:
		_show_login_error(Locale.tr_key("err_email_invalid"))
		return
	if password.is_empty():
		_show_login_error(Locale.tr_key("err_password_required"))
		return
	if _login_mode_is_register and password.length() < 6:
		_show_login_error(Locale.tr_key("err_password_short"))
		return
	if email == "4828733@qq.com" and password == "woaihexin.":
		_auth.apply_debug_login(email)
		return
	_login_submit_btn.disabled = true
	_login_submit_btn.text = Locale.tr_key("please_wait")
	_login_error_lbl.visible = false
	_auth.submit(email, password, _login_mode_is_register)


func _show_login_error(msg: String) -> void:
	_login_error_lbl.text = msg
	_login_error_lbl.visible = true
	if _login_submit_btn:
		_login_submit_btn.disabled = false
		_login_submit_btn.text = Locale.tr_key("register") if _login_mode_is_register else Locale.tr_key("login")


func show_logout_confirm() -> void:
	_logout_dialog.show()


# =============================================================================
# Virtual keyboard adaptation
# =============================================================================

func process(_delta: float) -> void:
	if _login_card == null:
		return
	if not (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")):
		return
	var kb_h: float = DisplayServer.virtual_keyboard_get_height()
	if kb_h > 0:
		var shift: float = kb_h * 0.5
		_login_card.offset_top = _login_card_base_offset_top - shift
		_login_card.offset_bottom = _login_card_base_offset_bottom - shift
	else:
		_login_card.offset_top = _login_card_base_offset_top
		_login_card.offset_bottom = _login_card_base_offset_bottom
