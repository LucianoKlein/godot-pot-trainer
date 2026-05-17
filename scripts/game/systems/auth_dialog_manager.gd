extends RefCounted
class_name AuthDialogManager

var _parent: Control
var _overlay: Control = null
var _email_input: LineEdit
var _password_input: LineEdit
var _pw_toggle_btn: Button
var _error_lbl: Label
var _submit_btn: Button
var _title_lbl: Label
var _toggle_btn: Button
var _is_register := false
var _on_success_callback: Callable
var _on_dismiss_callback: Callable
var _panel: PanelContainer
var _original_viewport_h := 0.0
var _panel_base_offset_top := -280.0
var _panel_base_offset_bottom := 280.0

func _t(en: String, zh: String) -> String:
	return zh if GameManager.language == "zh" else en

func _play_sfx(path: String) -> void:
	var main_node := _parent.get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.call("play_sfx", path)

func _init(parent: Control) -> void:
	_parent = parent

func show_auth_dialog(on_success: Callable, on_dismiss: Callable = Callable()) -> void:
	_on_success_callback = on_success
	_on_dismiss_callback = on_dismiss
	_is_register = false
	_build_dialog()
	FirebaseAuth.login_succeeded.connect(_on_login_ok)
	FirebaseAuth.login_failed.connect(_on_login_fail)
	FirebaseAuth.signup_succeeded.connect(_on_signup_ok)
	FirebaseAuth.signup_failed.connect(_on_signup_fail)
	GoogleSignIn.sign_in_success.connect(_on_google_ok)
	GoogleSignIn.sign_in_failed.connect(_on_google_fail)
	GoogleSignIn.sign_in_cancelled.connect(_on_google_cancel)
	AppleSignIn.sign_in_success.connect(_on_apple_ok)
	AppleSignIn.sign_in_failed.connect(_on_apple_fail)
	AppleSignIn.sign_in_cancelled.connect(_on_apple_cancel)

func _disconnect_signals() -> void:
	if FirebaseAuth.login_succeeded.is_connected(_on_login_ok):
		FirebaseAuth.login_succeeded.disconnect(_on_login_ok)
	if FirebaseAuth.login_failed.is_connected(_on_login_fail):
		FirebaseAuth.login_failed.disconnect(_on_login_fail)
	if FirebaseAuth.signup_succeeded.is_connected(_on_signup_ok):
		FirebaseAuth.signup_succeeded.disconnect(_on_signup_ok)
	if FirebaseAuth.signup_failed.is_connected(_on_signup_fail):
		FirebaseAuth.signup_failed.disconnect(_on_signup_fail)
	if GoogleSignIn.sign_in_success.is_connected(_on_google_ok):
		GoogleSignIn.sign_in_success.disconnect(_on_google_ok)
	if GoogleSignIn.sign_in_failed.is_connected(_on_google_fail):
		GoogleSignIn.sign_in_failed.disconnect(_on_google_fail)
	if GoogleSignIn.sign_in_cancelled.is_connected(_on_google_cancel):
		GoogleSignIn.sign_in_cancelled.disconnect(_on_google_cancel)
	if AppleSignIn.sign_in_success.is_connected(_on_apple_ok):
		AppleSignIn.sign_in_success.disconnect(_on_apple_ok)
	if AppleSignIn.sign_in_failed.is_connected(_on_apple_fail):
		AppleSignIn.sign_in_failed.disconnect(_on_apple_fail)
	if AppleSignIn.sign_in_cancelled.is_connected(_on_apple_cancel):
		AppleSignIn.sign_in_cancelled.disconnect(_on_apple_cancel)

func _close_dialog() -> void:
	_disconnect_signals()
	if _parent and _parent.get_tree() and _parent.get_tree().process_frame.is_connected(_on_process_frame):
		_parent.get_tree().process_frame.disconnect(_on_process_frame)
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	_panel = null

func _build_dialog() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 510

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if _email_input and _email_input.has_focus():
				_email_input.release_focus()
			if _password_input and _password_input.has_focus():
				_password_input.release_focus()
			DisplayServer.virtual_keyboard_hide()
	)
	_overlay.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -260
	_panel.offset_right = 260
	_panel.offset_top = _panel_base_offset_top
	_panel.offset_bottom = _panel_base_offset_bottom
	_panel.custom_minimum_size = Vector2(500, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	ps.border_color = Color(0.82, 0.66, 0.26)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(12)
	ps.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", ps)
	_overlay.add_child(_panel)

	_original_viewport_h = _parent.get_viewport_rect().size.y
	_parent.get_tree().process_frame.connect(_on_process_frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(close_row)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color(0.70, 0.60, 0.35))
	close_btn.add_theme_color_override("font_hover_color", Color(0.95, 0.85, 0.55))
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		var cb := _on_dismiss_callback
		_close_dialog()
		if cb.is_valid():
			cb.call()
	)
	close_row.add_child(close_btn)

	_title_lbl = Label.new()
	_title_lbl.text = _t("Login", "登录")
	_title_lbl.add_theme_font_size_override("font_size", 30)
	_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_lbl)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.08, 0.08, 0.10)
	input_style.border_color = Color(0.50, 0.40, 0.16)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(6)
	input_style.set_content_margin_all(10)
	var focus_style := input_style.duplicate()
	focus_style.border_color = Color(0.72, 0.58, 0.24)
	focus_style.set_border_width_all(2)

	_email_input = LineEdit.new()
	_email_input.placeholder_text = _t("Email", "邮箱")
	_email_input.custom_minimum_size = Vector2(0, 56)
	_email_input.add_theme_font_size_override("font_size", 24)
	_email_input.add_theme_stylebox_override("normal", input_style)
	_email_input.add_theme_stylebox_override("focus", focus_style)
	vbox.add_child(_email_input)

	var pw_row := HBoxContainer.new()
	pw_row.add_theme_constant_override("separation", 0)
	vbox.add_child(pw_row)

	_password_input = LineEdit.new()
	_password_input.placeholder_text = _t("Password", "密码")
	_password_input.secret = true
	_password_input.custom_minimum_size = Vector2(0, 56)
	_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_password_input.add_theme_font_size_override("font_size", 24)
	var pw_style := input_style.duplicate()
	pw_style.set_corner_radius(CORNER_TOP_RIGHT, 0)
	pw_style.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	_password_input.add_theme_stylebox_override("normal", pw_style)
	var pw_focus := focus_style.duplicate()
	pw_focus.set_corner_radius(CORNER_TOP_RIGHT, 0)
	pw_focus.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	_password_input.add_theme_stylebox_override("focus", pw_focus)
	_password_input.text_submitted.connect(func(_text: String) -> void: _on_submit())
	pw_row.add_child(_password_input)

	_pw_toggle_btn = Button.new()
	_pw_toggle_btn.text = ""
	_pw_toggle_btn.icon = _make_eye_icon(true)
	_pw_toggle_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pw_toggle_btn.expand_icon = true
	_pw_toggle_btn.custom_minimum_size = Vector2(56, 56)
	_pw_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_pw_toggle_btn.focus_mode = Control.FOCUS_NONE
	var eye_style := StyleBoxFlat.new()
	eye_style.bg_color = Color(0.08, 0.08, 0.10)
	eye_style.border_color = Color(0.50, 0.40, 0.16)
	eye_style.set_border_width_all(1)
	eye_style.set_corner_radius(CORNER_TOP_LEFT, 0)
	eye_style.set_corner_radius(CORNER_BOTTOM_LEFT, 0)
	eye_style.set_corner_radius(CORNER_TOP_RIGHT, 6)
	eye_style.set_corner_radius(CORNER_BOTTOM_RIGHT, 6)
	eye_style.set_content_margin_all(8)
	_pw_toggle_btn.add_theme_stylebox_override("normal", eye_style)
	var eye_hover := eye_style.duplicate()
	eye_hover.bg_color = Color(0.14, 0.13, 0.10)
	_pw_toggle_btn.add_theme_stylebox_override("hover", eye_hover)
	_pw_toggle_btn.add_theme_stylebox_override("pressed", eye_hover)
	_pw_toggle_btn.pressed.connect(func() -> void:
		_password_input.secret = not _password_input.secret
		_pw_toggle_btn.icon = _make_eye_icon(_password_input.secret)
	)
	pw_row.add_child(_pw_toggle_btn)

	_error_lbl = Label.new()
	_error_lbl.add_theme_font_size_override("font_size", 18)
	_error_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_lbl.visible = false
	vbox.add_child(_error_lbl)

	var btn_s := StyleBoxFlat.new()
	btn_s.bg_color = Color(0.08, 0.08, 0.10, 0.82)
	btn_s.border_color = Color(0.50, 0.40, 0.16)
	btn_s.set_border_width_all(2)
	btn_s.set_corner_radius_all(8)
	btn_s.set_content_margin_all(10)

	_submit_btn = Button.new()
	_submit_btn.text = _t("Login", "登录")
	_submit_btn.custom_minimum_size = Vector2(0, 56)
	_submit_btn.add_theme_font_size_override("font_size", 24)
	_submit_btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	_submit_btn.add_theme_stylebox_override("normal", btn_s)
	_submit_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		_on_submit()
	)
	vbox.add_child(_submit_btn)

	var forgot_btn := Button.new()
	forgot_btn.name = "ForgotPwBtn"
	forgot_btn.text = _t("Forgot password?", "忘记密码？")
	forgot_btn.flat = true
	forgot_btn.add_theme_font_size_override("font_size", 16)
	forgot_btn.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	forgot_btn.add_theme_color_override("font_hover_color", Color(0.70, 0.85, 1.0))
	forgot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	forgot_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		_on_forgot_password(forgot_btn)
	)
	vbox.add_child(forgot_btn)

	var google_btn := Button.new()
	google_btn.name = "GoogleBtn"
	google_btn.text = _t("G  Sign in with Google", "G  使用 Google 登录")
	google_btn.custom_minimum_size = Vector2(0, 56)
	google_btn.add_theme_font_size_override("font_size", 22)
	google_btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	google_btn.add_theme_stylebox_override("normal", btn_s.duplicate())
	google_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		_on_google_pressed()
	)
	vbox.add_child(google_btn)

	if OS.get_name() != "Android":
		var apple_btn := Button.new()
		apple_btn.name = "AppleBtn"
		apple_btn.text = _t("  Sign in with Apple", "  使用 Apple 登录")
		apple_btn.custom_minimum_size = Vector2(0, 56)
		apple_btn.add_theme_font_size_override("font_size", 22)
		apple_btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
		apple_btn.add_theme_stylebox_override("normal", btn_s.duplicate())
		apple_btn.pressed.connect(func() -> void:
			_play_sfx("res://assets/music/sounds_effect/button.ogg")
			_on_apple_pressed()
		)
		vbox.add_child(apple_btn)

	_toggle_btn = Button.new()
	_toggle_btn.text = _t("No account? Register", "没有账号？注册")
	_toggle_btn.flat = true
	_toggle_btn.add_theme_font_size_override("font_size", 18)
	_toggle_btn.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	_toggle_btn.pressed.connect(func() -> void:
		_is_register = not _is_register
		_error_lbl.visible = false
		if _is_register:
			_title_lbl.text = _t("Register", "注册")
			_submit_btn.text = _t("Register", "注册")
			_toggle_btn.text = _t("Have account? Login", "已有账号？登录")
		else:
			_title_lbl.text = _t("Login", "登录")
			_submit_btn.text = _t("Login", "登录")
			_toggle_btn.text = _t("No account? Register", "没有账号？注册")
	)
	vbox.add_child(_toggle_btn)

	_parent.add_child(_overlay)
	DialogQueue.register(_overlay)


func _on_submit() -> void:
	var email := _email_input.text.strip_edges()
	var password := _password_input.text.strip_edges()
	if email.is_empty():
		_show_error(_t("Please enter email", "请输入邮箱"))
		return
	if not "@" in email:
		_show_error(_t("Invalid email format", "邮箱格式不正确"))
		return
	if password.is_empty():
		_show_error(_t("Please enter password", "请输入密码"))
		return
	if _is_register and password.length() < 6:
		_show_error(_t("Password must be at least 6 characters", "密码至少6位"))
		return
	_submit_btn.disabled = true
	_submit_btn.text = _t("Please wait...", "请稍候...")
	_error_lbl.visible = false
	if _is_register:
		FirebaseAuth.signup_email(email, password)
	else:
		FirebaseAuth.login_email(email, password)


func _on_google_pressed() -> void:
	if not GoogleSignIn.is_available():
		_show_error(_t("Google Sign-In not available", "此平台不支持 Google 登录"))
		return
	_error_lbl.visible = false
	GoogleSignIn.sign_in()


func _show_error(msg: String) -> void:
	_error_lbl.text = msg
	_error_lbl.visible = true
	_submit_btn.disabled = false
	_submit_btn.text = _t("Register", "注册") if _is_register else _t("Login", "登录")


func _on_login_ok(_email: String) -> void:
	var cb := _on_success_callback
	_close_dialog()
	if cb.is_valid():
		cb.call()


func _on_login_fail(error_msg: String) -> void:
	_show_error(_translate_error(error_msg))


func _on_signup_ok(_email: String) -> void:
	var cb := _on_success_callback
	_close_dialog()
	if cb.is_valid():
		cb.call()


func _on_signup_fail(error_msg: String) -> void:
	_show_error(_translate_error(error_msg))


func _on_google_ok(id_token: String) -> void:
	FirebaseAuth.login_google(id_token)


func _on_google_fail(error_msg: String) -> void:
	_show_error(_t("Google sign-in failed: ", "Google 登录失败：") + error_msg)


func _on_google_cancel() -> void:
	_show_error(_t("Sign-in cancelled", "登录已取消"))


func _on_apple_pressed() -> void:
	if not AppleSignIn.is_available():
		_show_error(_t("Apple Sign-In not available", "此平台不支持 Apple 登录"))
		return
	_error_lbl.visible = false
	AppleSignIn.sign_in()


func _on_apple_ok(id_token: String, _display_name: String = "") -> void:
	FirebaseAuth.login_apple(id_token, _display_name)


func _on_apple_fail(error_msg: String) -> void:
	_show_error(_t("Apple sign-in failed: ", "Apple 登录失败：") + error_msg)


func _on_apple_cancel() -> void:
	_show_error(_t("Sign-in cancelled", "登录已取消"))


func _on_forgot_password(forgot_btn: Button) -> void:
	var email := _email_input.text.strip_edges()
	if email.is_empty():
		_show_error(_t("Please enter your email first", "请先输入邮箱"))
		return
	if not "@" in email:
		_show_error(_t("Invalid email format", "邮箱格式不正确"))
		return
	_error_lbl.visible = false
	forgot_btn.disabled = true
	forgot_btn.text = _t("Sending...", "发送中...")
	var _on_sent: Callable
	var _on_fail: Callable
	_on_sent = func() -> void:
		if FirebaseAuth.password_reset_failed.is_connected(_on_fail):
			FirebaseAuth.password_reset_failed.disconnect(_on_fail)
		_error_lbl.text = _t("Reset email sent!", "重置邮件已发送！")
		_error_lbl.add_theme_color_override("font_color", Color(0.40, 0.80, 0.40))
		_error_lbl.visible = true
		if is_instance_valid(forgot_btn):
			forgot_btn.disabled = false
			forgot_btn.text = _t("Forgot password?", "忘记密码？")
		if _parent and _parent.get_tree():
			await _parent.get_tree().create_timer(4.0).timeout
			if _error_lbl and is_instance_valid(_error_lbl):
				_error_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				_error_lbl.visible = false
	_on_fail = func(error_msg: String) -> void:
		if FirebaseAuth.password_reset_sent.is_connected(_on_sent):
			FirebaseAuth.password_reset_sent.disconnect(_on_sent)
		var msg: String
		match error_msg:
			"EMAIL_NOT_FOUND":
				msg = _t("Email not registered", "该邮箱未注册")
			"TOO_MANY_ATTEMPTS":
				msg = _t("Too many attempts, try later", "尝试次数过多，请稍后再试")
			_:
				msg = _t("Failed to send: " + error_msg, "发送失败：" + error_msg)
		_show_error(msg)
		if is_instance_valid(forgot_btn):
			forgot_btn.disabled = false
			forgot_btn.text = _t("Forgot password?", "忘记密码？")
	FirebaseAuth.password_reset_sent.connect(_on_sent, CONNECT_ONE_SHOT)
	FirebaseAuth.password_reset_failed.connect(_on_fail, CONNECT_ONE_SHOT)
	FirebaseAuth.send_password_reset(email)


func _translate_error(code: String) -> String:
	match code:
		"EMAIL_NOT_FOUND":
			return _t("Email not found", "邮箱未注册")
		"INVALID_PASSWORD":
			return _t("Wrong password", "密码错误")
		"EMAIL_EXISTS":
			return _t("Email already registered", "邮箱已注册")
		"WEAK_PASSWORD":
			return _t("Password too weak (min 6 chars)", "密码太弱（至少6位）")
		"TOO_MANY_ATTEMPTS":
			return _t("Too many attempts, try later", "尝试次数过多，请稍后再试")
		_:
			return _t("Login failed: " + code, "登录失败：" + code)


func _on_process_frame() -> void:
	if not _panel or not is_instance_valid(_panel):
		return
	var kb_height := DisplayServer.virtual_keyboard_get_height()
	var screen_h: float = _original_viewport_h if _original_viewport_h > 0.0 else _parent.get_viewport_rect().size.y
	var delta := _parent.get_process_delta_time()
	if kb_height > 0:
		if OS.get_name() == "iOS":
			_panel.anchor_top = 0.0
			_panel.anchor_bottom = 0.0
			_panel.anchor_left = 0.5
			_panel.anchor_right = 0.5
		var panel_h: float = _panel_base_offset_bottom - _panel_base_offset_top
		var center_y: float = screen_h / 2.0
		var panel_top: float = center_y + _panel_base_offset_top
		var panel_bottom: float = panel_top + panel_h
		var visible_bottom: float = screen_h - kb_height - 20
		var shift: float = max(0, panel_bottom - visible_bottom)
		var target_top: float = _panel_base_offset_top - shift
		var target_bot: float = _panel_base_offset_bottom - shift
		if OS.get_name() == "iOS":
			target_top = center_y + _panel_base_offset_top - shift
			target_bot = center_y + _panel_base_offset_bottom - shift
		_panel.offset_top = lerp(_panel.offset_top, target_top, delta * 8.0)
		_panel.offset_bottom = lerp(_panel.offset_bottom, target_bot, delta * 8.0)
	else:
		if OS.get_name() == "iOS":
			_panel.anchor_top = 0.5
			_panel.anchor_bottom = 0.5
		_panel.offset_top = lerp(_panel.offset_top, _panel_base_offset_top, delta * 8.0)
		_panel.offset_bottom = lerp(_panel.offset_bottom, _panel_base_offset_bottom, delta * 8.0)


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
