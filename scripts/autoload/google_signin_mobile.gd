extends Node
## GoogleSignInMobile — 移动端 Google 登录管理器
## 支持 Android 和 iOS 平台

signal google_signin_completed(id_token: String, email: String)
signal google_signin_failed(error: String)
signal google_signin_cancelled()

# Google OAuth Client IDs
const ANDROID_CLIENT_ID := "YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com"
const IOS_CLIENT_ID := "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com"
const WEB_CLIENT_ID := "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"  # Firebase 项目的 Web Client ID

var _is_android := false
var _is_ios := false
var _google_signin_plugin = null


func _ready() -> void:
	_is_android = OS.has_feature("android")
	_is_ios = OS.has_feature("ios")

	if _is_android:
		_init_android_plugin()
	elif _is_ios:
		_init_ios_plugin()


# =============================================================================
# 公共 API
# =============================================================================

## 启动 Google 登录
func start_signin() -> void:
	if _is_android:
		_signin_android()
	elif _is_ios:
		_signin_ios()
	else:
		google_signin_failed.emit("Platform not supported")


## 检查是否支持 Google 登录
func is_available() -> bool:
	if _is_android:
		return _google_signin_plugin != null
	elif _is_ios:
		return _google_signin_plugin != null
	return false


# =============================================================================
# Android 实现
# =============================================================================

func _init_android_plugin() -> void:
	# 检查是否有 Google Sign-In 插件
	if Engine.has_singleton("GodotGoogleSignIn"):
		_google_signin_plugin = Engine.get_singleton("GodotGoogleSignIn")
		print("[GoogleSignIn] Android plugin loaded")

		# 初始化插件
		if _google_signin_plugin.has_method("initialize"):
			_google_signin_plugin.initialize(WEB_CLIENT_ID)
	else:
		print("[GoogleSignIn] Android plugin not found")


func _signin_android() -> void:
	if not _google_signin_plugin:
		google_signin_failed.emit("Google Sign-In plugin not available")
		return

	if _google_signin_plugin.has_method("signIn"):
		_google_signin_plugin.signIn()
		# 插件会通过信号返回结果
		if not _google_signin_plugin.is_connected("sign_in_success", _on_android_signin_success):
			_google_signin_plugin.connect("sign_in_success", _on_android_signin_success)
		if not _google_signin_plugin.is_connected("sign_in_failed", _on_android_signin_failed):
			_google_signin_plugin.connect("sign_in_failed", _on_android_signin_failed)
		if not _google_signin_plugin.is_connected("sign_in_cancelled", _on_android_signin_cancelled):
			_google_signin_plugin.connect("sign_in_cancelled", _on_android_signin_cancelled)
	else:
		google_signin_failed.emit("Sign-in method not available")


func _on_android_signin_success(id_token: String, email: String) -> void:
	print("[GoogleSignIn] Android sign-in success: ", email)
	google_signin_completed.emit(id_token, email)


func _on_android_signin_failed(error: String) -> void:
	print("[GoogleSignIn] Android sign-in failed: ", error)
	google_signin_failed.emit(error)


func _on_android_signin_cancelled() -> void:
	print("[GoogleSignIn] Android sign-in cancelled")
	google_signin_cancelled.emit()


# =============================================================================
# iOS 实现
# =============================================================================

func _init_ios_plugin() -> void:
	# 检查是否有 Google Sign-In 插件
	if Engine.has_singleton("GodotGoogleSignIn"):
		_google_signin_plugin = Engine.get_singleton("GodotGoogleSignIn")
		print("[GoogleSignIn] iOS plugin loaded")

		# 初始化插件
		if _google_signin_plugin.has_method("initialize"):
			_google_signin_plugin.initialize(IOS_CLIENT_ID)
	else:
		print("[GoogleSignIn] iOS plugin not found")


func _signin_ios() -> void:
	if not _google_signin_plugin:
		google_signin_failed.emit("Google Sign-In plugin not available")
		return

	if _google_signin_plugin.has_method("signIn"):
		_google_signin_plugin.signIn()
		# 插件会通过信号返回结果
		if not _google_signin_plugin.is_connected("sign_in_success", _on_ios_signin_success):
			_google_signin_plugin.connect("sign_in_success", _on_ios_signin_success)
		if not _google_signin_plugin.is_connected("sign_in_failed", _on_ios_signin_failed):
			_google_signin_plugin.connect("sign_in_failed", _on_ios_signin_failed)
		if not _google_signin_plugin.is_connected("sign_in_cancelled", _on_ios_signin_cancelled):
			_google_signin_plugin.connect("sign_in_cancelled", _on_ios_signin_cancelled)
	else:
		google_signin_failed.emit("Sign-in method not available")


func _on_ios_signin_success(id_token: String, email: String) -> void:
	print("[GoogleSignIn] iOS sign-in success: ", email)
	google_signin_completed.emit(id_token, email)


func _on_ios_signin_failed(error: String) -> void:
	print("[GoogleSignIn] iOS sign-in failed: ", error)
	google_signin_failed.emit(error)


func _on_ios_signin_cancelled() -> void:
	print("[GoogleSignIn] iOS sign-in cancelled")
	google_signin_cancelled.emit()
