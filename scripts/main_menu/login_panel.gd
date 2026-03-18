extends Node
## LoginPanel — 登录/注册/登出面板管理
## 从 main_menu.gd 提取，负责所有认证相关 UI 和逻辑

signal login_status_changed()
signal play_sfx_requested(path: String)

var _parent: Control
var _make_entry_btn: Callable

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

# Logout confirm dialog
var _logout_confirm_dialog: Control


func setup(parent: Control, make_btn_callable: Callable) -> Node:
	_parent = parent
	_make_entry_btn = make_btn_callable
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
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	card_style.border_color = Color(0.50, 0.40, 0.16)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(32)
	card.add_theme_stylebox_override("panel", card_style)
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

	var email_lbl := Label.new()
	email_lbl.text = Locale.tr_key("email")
	email_lbl.add_theme_font_size_override("font_size", 22)
	email_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	vbox.add_child(email_lbl)

	var email_style := StyleBoxFlat.new()
	email_style.bg_color = Color(0.08, 0.08, 0.10)
	email_style.border_color = Color(0.50, 0.40, 0.16)
	email_style.set_border_width_all(1)
	email_style.set_corner_radius_all(6)
	email_style.set_content_margin_all(12)
	var email_focus := email_style.duplicate()
	email_focus.border_color = Color(0.72, 0.58, 0.24)
	email_focus.set_border_width_all(2)

	_login_email_input = LineEdit.new()
	_login_email_input.placeholder_text = Locale.tr_key("email_placeholder")
	_login_email_input.custom_minimum_size = Vector2(0, 64)
	_login_email_input.add_theme_font_size_override("font_size", 26)
	_login_email_input.add_theme_stylebox_override("normal", email_style)
	_login_email_input.add_theme_stylebox_override("focus", email_focus)
	vbox.add_child(_login_email_input)

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
	var pw_normal_style := email_style.duplicate()
	pw_normal_style.set_corner_radius(CORNER_TOP_RIGHT, 0)
	pw_normal_style.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	_login_password_input.add_theme_stylebox_override("normal", pw_normal_style)
	var pw_focus := email_style.duplicate()
	pw_focus.border_color = Color(0.72, 0.58, 0.24)
	pw_focus.set_border_width_all(2)
	pw_focus.set_corner_radius(CORNER_TOP_RIGHT, 0)
	pw_focus.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	_login_password_input.add_theme_stylebox_override("focus", pw_focus)
	_login_password_input.text_submitted.connect(func(_text: String) -> void: _on_login_submit())
	pw_row.add_child(_login_password_input)

	_login_pw_toggle_btn = Button.new()
	_login_pw_toggle_btn.text = "👁"
	_login_pw_toggle_btn.custom_minimum_size = Vector2(64, 64)
	_login_pw_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_login_pw_toggle_btn.focus_mode = Control.FOCUS_NONE
	var eye_style := StyleBoxFlat.new()
	eye_style.bg_color = Color(0.08, 0.08, 0.10)
	eye_style.border_color = Color(0.50, 0.40, 0.16)
	eye_style.set_border_width_all(1)
	eye_style.set_corner_radius(CORNER_TOP_LEFT, 0)
	eye_style.set_corner_radius(CORNER_BOTTOM_LEFT, 0)
	eye_style.set_corner_radius(CORNER_TOP_RIGHT, 6)
	eye_style.set_corner_radius(CORNER_BOTTOM_RIGHT, 6)
	eye_style.set_content_margin_all(0)
	_login_pw_toggle_btn.add_theme_stylebox_override("normal", eye_style)
	var eye_hover := eye_style.duplicate()
	eye_hover.bg_color = Color(0.14, 0.13, 0.10)
	_login_pw_toggle_btn.add_theme_stylebox_override("hover", eye_hover)
	_login_pw_toggle_btn.add_theme_stylebox_override("pressed", eye_hover)
	_login_pw_toggle_btn.add_theme_font_size_override("font_size", 22)
	_login_pw_toggle_btn.pressed.connect(_on_pw_toggle_pressed)
	pw_row.add_child(_login_pw_toggle_btn)

	_login_error_lbl = Label.new()
	_login_error_lbl.add_theme_font_size_override("font_size", 20)
	_login_error_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_login_error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_login_error_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_login_error_lbl.visible = false
	vbox.add_child(_login_error_lbl)

	_login_submit_btn = _make_entry_btn.call(Locale.tr_key("login"), Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16)) as Button
	_login_submit_btn.name = "SubmitBtn"
	_login_submit_btn.custom_minimum_size = Vector2(0, 80)
	_login_submit_btn.pressed.connect(_on_login_submit)
	vbox.add_child(_login_submit_btn)

	var google_btn: Button = _make_entry_btn.call(Locale.tr_key("google_login"), Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16))
	google_btn.custom_minimum_size = Vector2(0, 72)
	google_btn.add_theme_font_size_override("font_size", 26)
	google_btn.pressed.connect(_on_google_login_pressed)
	vbox.add_child(google_btn)

	_login_toggle_btn = Button.new()
	_login_toggle_btn.text = Locale.tr_key("no_account")
	_login_toggle_btn.flat = true
	_login_toggle_btn.add_theme_font_size_override("font_size", 20)
	_login_toggle_btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	_login_toggle_btn.pressed.connect(_on_toggle_login_register)
	vbox.add_child(_login_toggle_btn)

	_parent.add_child(_login_panel)
	_login_email_input.grab_focus()


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
	_show_login_error(Locale.tr_key("google_login_soon"))


# =============================================================================
# Login submit & Firebase callbacks
# =============================================================================

func connect_firebase_signals() -> void:
	FirebaseAuth.login_succeeded.connect(_on_firebase_login_ok)
	FirebaseAuth.login_failed.connect(_on_firebase_login_fail)
	FirebaseAuth.signup_succeeded.connect(_on_firebase_signup_ok)
	FirebaseAuth.signup_failed.connect(_on_firebase_signup_fail)
	FirebaseAuth.logout_completed.connect(_on_firebase_logout)
	FirebaseAuth.services_loaded.connect(_on_services_loaded)


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
	# Debug backdoor
	if email == "4828733@qq.com" and password == "woaihexin.":
		_apply_debug_login(email)
		return
	_login_submit_btn.disabled = true
	_login_submit_btn.text = Locale.tr_key("please_wait")
	_login_error_lbl.visible = false
	if _login_mode_is_register:
		FirebaseAuth.signup_email(email, password)
	else:
		FirebaseAuth.login_email(email, password)


func _show_login_error(msg: String) -> void:
	_login_error_lbl.text = msg
	_login_error_lbl.visible = true
	if _login_submit_btn:
		_login_submit_btn.disabled = false
		_login_submit_btn.text = Locale.tr_key("register") if _login_mode_is_register else Locale.tr_key("login")


func _on_firebase_login_ok(_email: String) -> void:
	_play_sfx("res://assets/music/sounds_effect/right.ogg")
	hide()
	login_status_changed.emit()


func _on_firebase_login_fail(error_msg: String) -> void:
	_show_login_error(_translate_firebase_error(error_msg))


func _on_firebase_signup_ok(_email: String) -> void:
	_play_sfx("res://assets/music/sounds_effect/right.ogg")
	hide()
	login_status_changed.emit()


func _on_firebase_signup_fail(error_msg: String) -> void:
	_show_login_error(_translate_firebase_error(error_msg))


func _on_firebase_logout() -> void:
	login_status_changed.emit()


func _on_services_loaded() -> void:
	login_status_changed.emit()


func _translate_firebase_error(code: String) -> String:
	match code:
		"EMAIL_NOT_FOUND":
			return Locale.tr_key("err_email_not_found")
		"INVALID_PASSWORD":
			return Locale.tr_key("err_invalid_password")
		"EMAIL_EXISTS":
			return Locale.tr_key("err_email_exists")
		"WEAK_PASSWORD":
			return Locale.tr_key("err_weak_password")
		"TOO_MANY_ATTEMPTS":
			return Locale.tr_key("err_too_many_attempts")
		"Network error":
			return Locale.tr_key("err_network")
		_:
			return Locale.tr_key("err_login_failed") + code


func _apply_debug_login(email: String) -> void:
	var far_future := Time.get_unix_time_from_system() + 365.0 * 24.0 * 3600.0
	FirebaseAuth.is_logged_in = true
	FirebaseAuth.user_email = email
	FirebaseAuth.user_id = "debug_user"
	FirebaseAuth.id_token = "debug_token"
	FirebaseAuth.refresh_token = ""
	FirebaseAuth._token_expires_at = far_future
	FirebaseAuth.services = {
		"potTrainer": {"expiresAt": far_future},
	}
	FirebaseAuth._save_auth()
	FirebaseAuth.login_succeeded.emit(email)
	FirebaseAuth.services_loaded.emit()
	print("[DEBUG] Backdoor login: ", email)


# =============================================================================
# Logout
# =============================================================================

func show_logout_confirm() -> void:
	if _logout_confirm_dialog != null:
		_logout_confirm_dialog.queue_free()
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_parent.add_child(overlay)
	_logout_confirm_dialog = overlay

	var dialog := PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.offset_left = -200
	dialog.offset_right = 200
	dialog.offset_top = -90
	dialog.offset_bottom = 90
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	panel_style.border_color = Color(0.50, 0.40, 0.16)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 20)
	margin.add_child(inner)

	var msg := Label.new()
	msg.text = Locale.tr_key("confirm_logout")
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color(0.92, 0.80, 0.55))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(btn_row)

	var cancel_btn: Button = _make_entry_btn.call(Locale.tr_key("cancel"), Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16))
	cancel_btn.custom_minimum_size = Vector2(130, 52)
	cancel_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		_logout_confirm_dialog.queue_free()
		_logout_confirm_dialog = null)
	btn_row.add_child(cancel_btn)

	var confirm_btn: Button = _make_entry_btn.call(Locale.tr_key("logout"), Color(0.08, 0.08, 0.10, 0.82), Color(0.55, 0.25, 0.15))
	confirm_btn.custom_minimum_size = Vector2(130, 52)
	confirm_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		_logout_confirm_dialog.queue_free()
		_logout_confirm_dialog = null
		FirebaseAuth.logout())
	btn_row.add_child(confirm_btn)


# =============================================================================
# Virtual keyboard adaptation
# =============================================================================

func process(delta: float) -> void:
	if _login_card and _login_panel and _login_panel.visible:
		var kb_height := DisplayServer.virtual_keyboard_get_height()
		if kb_height > 0:
			var screen_h := _parent.get_viewport_rect().size.y
			var card_bottom := _login_card.position.y + _login_card.size.y
			var target_bottom := screen_h - kb_height - 20
			var shift: float = max(0, card_bottom - target_bottom)
			_login_card.offset_top = lerp(_login_card.offset_top, _login_card_base_offset_top - shift, delta * 8.0)
			_login_card.offset_bottom = lerp(_login_card.offset_bottom, _login_card_base_offset_bottom - shift, delta * 8.0)
		else:
			_login_card.offset_top = lerp(_login_card.offset_top, _login_card_base_offset_top, delta * 8.0)
			_login_card.offset_bottom = lerp(_login_card.offset_bottom, _login_card_base_offset_bottom, delta * 8.0)
