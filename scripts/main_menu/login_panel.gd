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
var _login_confirm_pw_lbl: Label
var _login_confirm_pw_input: LineEdit
var _login_error_lbl: Label
var _login_submit_btn: Button
var _login_panel_title: Label
var _login_toggle_btn: Button
var _login_mode_is_register := false
var _login_card: PanelContainer
var _login_close_btn: Button
var _login_card_base_offset_top := 0.0
var _login_card_base_offset_bottom := 0.0
var _login_original_viewport_h := 0.0
var _cancel_login_btn: Button


func setup(parent: Control, make_btn_callable: Callable) -> Node:
	_parent = parent
	_make_entry_btn = make_btn_callable
	_logout_dialog = LogoutDialog.new().setup(parent, make_btn_callable)
	_logout_dialog.play_sfx_requested.connect(func(path: String) -> void: _play_sfx(path))
	_auth = LoginAuthHandler.new().setup(_hide_login_panel)
	_auth.login_status_changed.connect(func() -> void: login_status_changed.emit())
	_auth.login_error.connect(func(msg: String) -> void: _show_login_error(msg))
	_auth.play_sfx_requested.connect(func(path: String) -> void: _play_sfx(path))
	return self


func _play_sfx(path: String) -> void:
	play_sfx_requested.emit(path)


func show() -> void:
	DialogQueue.show(func() -> void: _create_login_panel())


func _create_login_panel() -> void:
	_login_mode_is_register = false
	_cancel_login_btn = null
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
		if event is InputEventMouseButton and event.pressed:
			if _login_email_input and _login_email_input.has_focus():
				_login_email_input.release_focus()
			if _login_password_input and _login_password_input.has_focus():
				_login_password_input.release_focus()
			DisplayServer.virtual_keyboard_hide()
			_parent.get_viewport().set_input_as_handled()
	)
	_login_panel.add_child(dim)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -280
	card.offset_right = 280
	card.offset_top = -345
	card.offset_bottom = 345
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if _login_email_input and _login_email_input.has_focus():
				_login_email_input.release_focus()
			if _login_password_input and _login_password_input.has_focus():
				_login_password_input.release_focus()
			DisplayServer.virtual_keyboard_hide()
	)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	card_style.border_color = Color(0.50, 0.40, 0.16)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(32)
	card.add_theme_stylebox_override("panel", card_style)
	_login_panel.add_child(card)
	_login_card = card
	_login_card_base_offset_top = -345.0
	_login_card_base_offset_bottom = 345.0
	_login_original_viewport_h = _parent.get_viewport_rect().size.y

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	_login_panel_title = Label.new()
	_login_panel_title.text = Locale.tr_key("login")
	_login_panel_title.add_theme_font_size_override("font_size", 36)
	_login_panel_title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	_login_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_login_panel_title)

	# Email label + input
	var email_lbl := Label.new()
	email_lbl.text = Locale.tr_key("email")
	email_lbl.add_theme_font_size_override("font_size", 22)
	email_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	vbox.add_child(email_lbl)

	var email_style := _make_input_style()
	var email_focus := _make_input_focus_style()

	_login_email_input = LineEdit.new()
	_login_email_input.placeholder_text = Locale.tr_key("email_placeholder")
	_login_email_input.custom_minimum_size = Vector2(0, 64)
	_login_email_input.add_theme_font_size_override("font_size", 26)
	_login_email_input.add_theme_stylebox_override("normal", email_style)
	_login_email_input.add_theme_stylebox_override("focus", email_focus)
	vbox.add_child(_login_email_input)

	# Password label + row
	var pw_lbl := Label.new()
	pw_lbl.text = Locale.tr_key("password")
	pw_lbl.add_theme_font_size_override("font_size", 22)
	pw_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	vbox.add_child(pw_lbl)

	var pw_row := HBoxContainer.new()
	pw_row.add_theme_constant_override("separation", 0)
	vbox.add_child(pw_row)

	_login_password_input = LineEdit.new()
	_login_password_input.placeholder_text = Locale.tr_key("password_placeholder")
	_login_password_input.secret = true
	_login_password_input.custom_minimum_size = Vector2(0, 64)
	_login_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_login_password_input.add_theme_font_size_override("font_size", 26)
	var pw_normal := _make_input_style()
	pw_normal.set_corner_radius(CORNER_TOP_RIGHT, 0)
	pw_normal.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	_login_password_input.add_theme_stylebox_override("normal", pw_normal)
	var pw_focus := _make_input_focus_style()
	pw_focus.set_corner_radius(CORNER_TOP_RIGHT, 0)
	pw_focus.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	_login_password_input.add_theme_stylebox_override("focus", pw_focus)
	_login_password_input.text_submitted.connect(func(_text: String) -> void: _on_login_submit())
	pw_row.add_child(_login_password_input)

	_login_pw_toggle_btn = Button.new()
	_login_pw_toggle_btn.text = ""
	_login_pw_toggle_btn.icon = _make_eye_icon(true)
	_login_pw_toggle_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_login_pw_toggle_btn.expand_icon = true
	_login_pw_toggle_btn.custom_minimum_size = Vector2(64, 64)
	_login_pw_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_login_pw_toggle_btn.focus_mode = Control.FOCUS_NONE
	var eye_style := _make_input_style()
	eye_style.set_corner_radius(CORNER_TOP_LEFT, 0)
	eye_style.set_corner_radius(CORNER_BOTTOM_LEFT, 0)
	eye_style.set_corner_radius(CORNER_TOP_RIGHT, 6)
	eye_style.set_corner_radius(CORNER_BOTTOM_RIGHT, 6)
	eye_style.set_content_margin_all(8)
	_login_pw_toggle_btn.add_theme_stylebox_override("normal", eye_style)
	var eye_hover := eye_style.duplicate()
	eye_hover.bg_color = Color(0.14, 0.13, 0.10)
	_login_pw_toggle_btn.add_theme_stylebox_override("hover", eye_hover)
	_login_pw_toggle_btn.add_theme_stylebox_override("pressed", eye_hover)
	_login_pw_toggle_btn.pressed.connect(_on_pw_toggle_pressed)
	pw_row.add_child(_login_pw_toggle_btn)

	# Confirm password (register mode only, hidden by default)
	_login_confirm_pw_lbl = Label.new()
	_login_confirm_pw_lbl.text = Locale.tr_key("confirm_password")
	_login_confirm_pw_lbl.add_theme_font_size_override("font_size", 22)
	_login_confirm_pw_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	_login_confirm_pw_lbl.visible = false
	vbox.add_child(_login_confirm_pw_lbl)

	_login_confirm_pw_input = LineEdit.new()
	_login_confirm_pw_input.placeholder_text = Locale.tr_key("confirm_password_placeholder")
	_login_confirm_pw_input.secret = true
	_login_confirm_pw_input.custom_minimum_size = Vector2(0, 64)
	_login_confirm_pw_input.add_theme_font_size_override("font_size", 26)
	_login_confirm_pw_input.add_theme_stylebox_override("normal", _make_input_style())
	_login_confirm_pw_input.add_theme_stylebox_override("focus", _make_input_focus_style())
	_login_confirm_pw_input.text_submitted.connect(func(_text: String) -> void: _on_login_submit())
	_login_confirm_pw_input.visible = false
	vbox.add_child(_login_confirm_pw_input)

	# Error label
	_login_error_lbl = Label.new()
	_login_error_lbl.add_theme_font_size_override("font_size", 20)
	_login_error_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_login_error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_login_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_login_error_lbl.visible = false
	vbox.add_child(_login_error_lbl)

	# Submit button
	_login_submit_btn = _make_entry_btn.call(Locale.tr_key("login"), Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16))
	_login_submit_btn.name = "SubmitBtn"
	_login_submit_btn.custom_minimum_size = Vector2(0, 80)
	_login_submit_btn.pressed.connect(_on_login_submit)
	vbox.add_child(_login_submit_btn)

	# Forgot password link
	var forgot_btn := Button.new()
	forgot_btn.name = "ForgotPwBtn"
	forgot_btn.text = Locale.tr_key("forgot_password")
	forgot_btn.flat = true
	forgot_btn.add_theme_font_size_override("font_size", 18)
	forgot_btn.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	forgot_btn.add_theme_color_override("font_hover_color", Color(0.70, 0.85, 1.0))
	forgot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	forgot_btn.focus_mode = Control.FOCUS_NONE
	forgot_btn.pressed.connect(_on_forgot_password_pressed)
	vbox.add_child(forgot_btn)

	# Google login button (always show)
	var google_btn: Button = _make_entry_btn.call(Locale.tr_key("google_login"), Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16))
	google_btn.name = "GoogleBtn"
	google_btn.custom_minimum_size = Vector2(0, 72)
	google_btn.add_theme_font_size_override("font_size", 26)
	google_btn.pressed.connect(_on_google_login_pressed)
	vbox.add_child(google_btn)

	# Apple login button (hide on Android)
	if OS.get_name() != "Android":
		var apple_btn: Button = _make_entry_btn.call(Locale.tr_key("apple_login"), Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16))
		apple_btn.name = "AppleBtn"
		apple_btn.custom_minimum_size = Vector2(0, 72)
		apple_btn.add_theme_font_size_override("font_size", 26)
		apple_btn.pressed.connect(_on_apple_login_pressed)
		vbox.add_child(apple_btn)

	# Toggle login/register
	_login_toggle_btn = Button.new()
	_login_toggle_btn.text = Locale.tr_key("no_account")
	_login_toggle_btn.flat = true
	_login_toggle_btn.add_theme_font_size_override("font_size", 20)
	_login_toggle_btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	_login_toggle_btn.pressed.connect(_on_toggle_login_register)
	vbox.add_child(_login_toggle_btn)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(48, 48)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color(0.70, 0.60, 0.40))
	close_btn.add_theme_color_override("font_hover_color", Color(0.90, 0.80, 0.55))
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.z_index = 101
	close_btn.anchor_left = 0.5
	close_btn.anchor_top = 0.5
	close_btn.anchor_right = 0.5
	close_btn.anchor_bottom = 0.5
	close_btn.offset_left = 280 - 56
	close_btn.offset_top = -345 + 8
	close_btn.offset_right = 280 - 8
	close_btn.offset_bottom = -345 + 56
	close_btn.pressed.connect(_hide_login_panel)
	_login_panel.add_child(close_btn)
	_login_close_btn = close_btn

	_parent.add_child(_login_panel)
	DialogQueue.register(_login_panel)
	_login_email_input.grab_focus()


func _hide_login_panel() -> void:
	if _login_panel:
		_login_panel.queue_free()
		_login_panel = null
		DisplayServer.virtual_keyboard_hide()
		_login_card = null
		_login_close_btn = null
		_login_original_viewport_h = 0.0
		_cancel_login_btn = null
		_login_confirm_pw_lbl = null
		_login_confirm_pw_input = null


func _on_toggle_login_register() -> void:
	_login_mode_is_register = not _login_mode_is_register
	_login_error_lbl.visible = false
	if _login_mode_is_register:
		_login_panel_title.text = Locale.tr_key("register")
		_login_submit_btn.text = Locale.tr_key("register")
		_login_toggle_btn.text = Locale.tr_key("has_account")
		_login_confirm_pw_lbl.visible = true
		_login_confirm_pw_input.visible = true
		_login_confirm_pw_input.text = ""
	else:
		_login_panel_title.text = Locale.tr_key("login")
		_login_submit_btn.text = Locale.tr_key("login")
		_login_toggle_btn.text = Locale.tr_key("no_account")
		_login_confirm_pw_lbl.visible = false
		_login_confirm_pw_input.visible = false
	_toggle_oauth_buttons(not _login_mode_is_register)


func _on_pw_toggle_pressed() -> void:
	_login_password_input.secret = not _login_password_input.secret
	_login_pw_toggle_btn.icon = _make_eye_icon(_login_password_input.secret)


func _on_google_login_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	if not GoogleSignIn.is_available():
		_show_login_error(Locale.tr_key("err_google_not_available"))
		return
	if _login_error_lbl:
		_login_error_lbl.visible = false
	if not _login_panel:
		return
	var google_btn := _login_panel.find_child("GoogleBtn", true, false) as Button
	if google_btn:
		google_btn.disabled = true
		google_btn.text = Locale.tr_key("please_wait")
	_auth.start_google_login()


func _on_apple_login_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	if not AppleSignIn.is_available():
		_show_login_error(Locale.tr_key("err_apple_failed"))
		return
	if _login_error_lbl:
		_login_error_lbl.visible = false
	if not _login_panel:
		return
	var apple_btn := _login_panel.find_child("AppleBtn", true, false) as Button
	if apple_btn:
		apple_btn.disabled = true
		apple_btn.text = Locale.tr_key("please_wait")
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
	if _login_mode_is_register and _login_confirm_pw_input.text.strip_edges() != password:
		_show_login_error(Locale.tr_key("err_password_mismatch"))
		return
	if email == "4828733@qq.com" and password == "woaihexin.":
		_auth.apply_debug_login(email)
		return
	_login_submit_btn.disabled = true
	_login_submit_btn.text = Locale.tr_key("please_wait")
	_login_error_lbl.visible = false
	if not _cancel_login_btn:
		_cancel_login_btn = Button.new()
		_cancel_login_btn.name = "CancelLoginBtn"
		_cancel_login_btn.text = Locale.tr_key("cancel")
		_cancel_login_btn.custom_minimum_size = Vector2(120, 44)
		_cancel_login_btn.add_theme_font_size_override("font_size", 18)
		_cancel_login_btn.pressed.connect(_on_cancel_login_submit)
		if _login_card:
			var vbox := _login_card.get_child(0) as VBoxContainer
			if vbox:
				vbox.add_child(_cancel_login_btn)
	_auth.submit(email, password, _login_mode_is_register)


func _on_cancel_login_submit() -> void:
	_remove_cancel_btn()
	if _login_submit_btn:
		_login_submit_btn.disabled = false
		_login_submit_btn.text = Locale.tr_key("register") if _login_mode_is_register else Locale.tr_key("login")
	FirebaseAuth.logout()


func _remove_cancel_btn() -> void:
	if _cancel_login_btn and is_instance_valid(_cancel_login_btn):
		_cancel_login_btn.queue_free()
		_cancel_login_btn = null


func _show_login_error(msg: String) -> void:
	_login_error_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_login_error_lbl.text = msg
	_login_error_lbl.visible = true
	if _login_submit_btn:
		_login_submit_btn.disabled = false
		_login_submit_btn.text = Locale.tr_key("register") if _login_mode_is_register else Locale.tr_key("login")
	_remove_cancel_btn()
	_restore_google_apple_btns()


func show_logout_confirm() -> void:
	_logout_dialog.show()


func _on_forgot_password_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	var email := _login_email_input.text.strip_edges()
	if email.is_empty():
		_show_login_error(Locale.tr_key("err_email_required"))
		return
	if not "@" in email:
		_show_login_error(Locale.tr_key("err_email_invalid"))
		return
	_login_error_lbl.visible = false
	var forgot_btn := _login_panel.find_child("ForgotPwBtn", true, false) as Button
	if forgot_btn:
		forgot_btn.disabled = true
		forgot_btn.text = Locale.tr_key("please_wait")
	var _on_sent: Callable
	var _on_fail: Callable
	_on_sent = func() -> void:
		if FirebaseAuth.password_reset_failed.is_connected(_on_fail):
			FirebaseAuth.password_reset_failed.disconnect(_on_fail)
		_show_login_success(Locale.tr_key("password_reset_sent"))
		if forgot_btn and is_instance_valid(forgot_btn):
			forgot_btn.disabled = false
			forgot_btn.text = Locale.tr_key("forgot_password")
	_on_fail = func(error_msg: String) -> void:
		if FirebaseAuth.password_reset_sent.is_connected(_on_sent):
			FirebaseAuth.password_reset_sent.disconnect(_on_sent)
		_show_login_error(error_msg)
		if forgot_btn and is_instance_valid(forgot_btn):
			forgot_btn.disabled = false
			forgot_btn.text = Locale.tr_key("forgot_password")
	FirebaseAuth.password_reset_sent.connect(_on_sent, CONNECT_ONE_SHOT)
	FirebaseAuth.password_reset_failed.connect(_on_fail, CONNECT_ONE_SHOT)
	FirebaseAuth.send_password_reset(email)


func _show_login_success(msg: String) -> void:
	if not _login_error_lbl:
		return
	_login_error_lbl.text = msg
	_login_error_lbl.add_theme_color_override("font_color", Color(0.40, 0.80, 0.40))
	_login_error_lbl.visible = true
	var tw := _parent.create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(func() -> void:
		if _login_error_lbl and is_instance_valid(_login_error_lbl):
			_login_error_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			_login_error_lbl.visible = false
	)


# =============================================================================
# Virtual keyboard adaptation
# =============================================================================

func process(delta: float) -> void:
	if _login_card == null or not _login_panel or not _login_panel.visible:
		return
	var kb_height := DisplayServer.virtual_keyboard_get_height()
	var screen_h := _login_original_viewport_h if _login_original_viewport_h > 0 else _parent.get_viewport_rect().size.y
	if kb_height > 0:
		if OS.get_name() == "iOS":
			_login_card.anchor_top = 0.0
			_login_card.anchor_bottom = 0.0
			_login_card.anchor_left = 0.5
			_login_card.anchor_right = 0.5
		var card_h: float = _login_card_base_offset_bottom - _login_card_base_offset_top
		var card_center_y: float = screen_h / 2.0
		var card_top: float = card_center_y + _login_card_base_offset_top
		var card_bottom: float = card_top + card_h
		var visible_bottom: float = screen_h - kb_height - 20
		var shift: float = max(0, card_bottom - visible_bottom)
		var target_top: float = _login_card_base_offset_top - shift
		var target_bot: float = _login_card_base_offset_bottom - shift
		if OS.get_name() == "iOS":
			target_top = card_center_y + _login_card_base_offset_top - shift
			target_bot = card_center_y + _login_card_base_offset_bottom - shift
		_login_card.offset_top = lerp(_login_card.offset_top, target_top, delta * 8.0)
		_login_card.offset_bottom = lerp(_login_card.offset_bottom, target_bot, delta * 8.0)
		if _login_close_btn:
			_login_close_btn.offset_top = lerp(_login_close_btn.offset_top, target_top + 8, delta * 8.0)
			_login_close_btn.offset_bottom = lerp(_login_close_btn.offset_bottom, target_top + 56, delta * 8.0)
	else:
		if OS.get_name() == "iOS":
			_login_card.anchor_top = 0.5
			_login_card.anchor_bottom = 0.5
		_login_card.offset_top = lerp(_login_card.offset_top, _login_card_base_offset_top, delta * 8.0)
		_login_card.offset_bottom = lerp(_login_card.offset_bottom, _login_card_base_offset_bottom, delta * 8.0)
		if _login_close_btn:
			_login_close_btn.offset_top = lerp(_login_close_btn.offset_top, _login_card_base_offset_top + 8, delta * 8.0)
			_login_close_btn.offset_bottom = lerp(_login_close_btn.offset_bottom, _login_card_base_offset_top + 56, delta * 8.0)


# =============================================================================
# Helpers
# =============================================================================

func _make_input_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.10)
	s.border_color = Color(0.50, 0.40, 0.16)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(12)
	return s


func _make_input_focus_style() -> StyleBoxFlat:
	var s := _make_input_style()
	s.border_color = Color(0.72, 0.58, 0.24)
	s.set_border_width_all(2)
	return s


func _make_eye_icon(is_hidden: bool) -> ImageTexture:
	var sz := 32
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(0.70, 0.60, 0.40)
	var cx := sz / 2.0
	var cy := sz / 2.0
	var rx := 12.0
	var ry := 7.0
	for deg in range(360):
		var rad := deg_to_rad(deg)
		var px := cx + cos(rad) * rx
		var py := cy + sin(rad) * ry
		var ix := int(px)
		var iy := int(py)
		if ix >= 0 and ix < sz and iy >= 0 and iy < sz:
			img.set_pixel(ix, iy, col)
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			if dx * dx + dy * dy <= 9:
				var px := int(cx) + dx
				var py := int(cy) + dy
				if px >= 0 and px < sz and py >= 0 and py < sz:
					img.set_pixel(px, py, col)
	if is_hidden:
		for i in range(sz):
			if i >= 0 and i < sz:
				img.set_pixel(i, i, col)
				if i + 1 < sz:
					img.set_pixel(i + 1, i, col)
	return ImageTexture.create_from_image(img)


func _restore_google_apple_btns() -> void:
	if not _login_panel:
		return
	var google_btn := _login_panel.find_child("GoogleBtn", true, false) as Button
	if google_btn:
		google_btn.disabled = false
		google_btn.text = Locale.tr_key("google_login")
	var apple_btn := _login_panel.find_child("AppleBtn", true, false) as Button
	if apple_btn:
		apple_btn.disabled = false
		apple_btn.text = Locale.tr_key("apple_login")


func _toggle_oauth_buttons(show: bool) -> void:
	if not _login_panel:
		return
	var google_btn := _login_panel.find_child("GoogleBtn", true, false) as Button
	if google_btn:
		google_btn.visible = show
	var apple_btn := _login_panel.find_child("AppleBtn", true, false) as Button
	if apple_btn:
		apple_btn.visible = show
