class_name LoginAuthHandler
extends RefCounted
## LoginAuthHandler — Firebase 认证回调处理器
## 负责 Firebase 登录/注册/Google 登录的信号连接和回调

signal login_status_changed()
signal login_error(msg: String)
signal play_sfx_requested(path: String)

var _hide_callback: Callable


func setup(hide_cb: Callable) -> RefCounted:
	_hide_callback = hide_cb
	return self


func connect_signals() -> void:
	FirebaseAuth.login_succeeded.connect(_on_login_ok)
	FirebaseAuth.login_failed.connect(_on_login_fail)
	FirebaseAuth.signup_succeeded.connect(_on_signup_ok)
	FirebaseAuth.signup_failed.connect(_on_signup_fail)
	FirebaseAuth.logout_completed.connect(func() -> void: login_status_changed.emit())
	FirebaseAuth.services_loaded.connect(func() -> void: login_status_changed.emit())
	GoogleSignIn.sign_in_success.connect(_on_google_sign_in_success)
	GoogleSignIn.sign_in_failed.connect(_on_google_sign_in_failed)
	GoogleSignIn.sign_in_cancelled.connect(_on_google_sign_in_cancelled)
	AppleSignIn.sign_in_success.connect(_on_apple_sign_in_success)
	AppleSignIn.sign_in_failed.connect(_on_apple_sign_in_failed)
	AppleSignIn.sign_in_cancelled.connect(_on_apple_sign_in_cancelled)


func submit(email: String, password: String, is_register: bool) -> void:
	if is_register:
		FirebaseAuth.signup_email(email, password)
	else:
		FirebaseAuth.login_email(email, password)


func apply_debug_login(email: String) -> void:
	var far_future := Time.get_unix_time_from_system() + 365.0 * 24.0 * 3600.0
	FirebaseAuth.user_email = email
	FirebaseAuth.user_id = "debug_user_001"
	FirebaseAuth.id_token = "debug_token"
	FirebaseAuth.refresh_token = "debug_refresh"
	FirebaseAuth._token_expires_at = far_future
	FirebaseAuth.is_logged_in = true
	play_sfx_requested.emit("res://assets/music/sounds_effect/right.ogg")
	_hide_callback.call()
	login_status_changed.emit()


func start_google_login() -> void:
	if GoogleSignIn.is_available():
		GoogleSignIn.sign_in()
	else:
		login_error.emit(Locale.tr_key("err_google_failed"))


func start_apple_login() -> void:
	if AppleSignIn.is_available():
		AppleSignIn.sign_in()
	else:
		login_error.emit(Locale.tr_key("err_apple_failed"))


func translate_error(code: String) -> String:
	match code:
		"EMAIL_NOT_FOUND": return Locale.tr_key("err_email_not_found")
		"INVALID_PASSWORD": return Locale.tr_key("err_invalid_password")
		"EMAIL_EXISTS": return Locale.tr_key("err_email_exists")
		"WEAK_PASSWORD": return Locale.tr_key("err_weak_password")
		"TOO_MANY_ATTEMPTS": return Locale.tr_key("err_too_many_attempts")
		"Network error": return Locale.tr_key("err_network")
		_: return Locale.tr_key("err_login_failed") + code


func _on_login_ok(_email: String) -> void:
	play_sfx_requested.emit("res://assets/music/sounds_effect/right.ogg")
	_hide_callback.call()
	login_status_changed.emit()


func _on_login_fail(error_msg: String) -> void:
	login_error.emit(translate_error(error_msg))


func _on_signup_ok(_email: String) -> void:
	play_sfx_requested.emit("res://assets/music/sounds_effect/right.ogg")
	_hide_callback.call()
	login_status_changed.emit()


func _on_signup_fail(error_msg: String) -> void:
	login_error.emit(translate_error(error_msg))


func _on_google_sign_in_success(id_token: String) -> void:
	FirebaseAuth.login_google(id_token)


func _on_google_sign_in_failed(error_msg: String) -> void:
	login_error.emit(Locale.tr_key("err_google_failed") + error_msg)


func _on_google_sign_in_cancelled() -> void:
	login_error.emit(Locale.tr_key("err_google_cancelled"))


func _on_apple_sign_in_success(id_token: String) -> void:
	FirebaseAuth.login_apple(id_token)


func _on_apple_sign_in_failed(error_msg: String) -> void:
	login_error.emit(Locale.tr_key("err_apple_failed") + error_msg)


func _on_apple_sign_in_cancelled() -> void:
	login_error.emit(Locale.tr_key("err_apple_cancelled"))
