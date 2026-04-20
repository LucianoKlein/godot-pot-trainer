extends Node

## Google Sign-In wrapper for Android/iOS
## Autoload singleton — access via GoogleSignIn

signal sign_in_success(id_token: String)
signal sign_in_failed(error_msg: String)
signal sign_in_cancelled

# OAuth 2.0 Web Client ID from Google Cloud Console
const WEB_CLIENT_ID := "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"  # TODO: 替换

var _plugin = null
var _auth_plugin = null  # SwiftGodot GDExtension
var _is_configured := false


func _ready() -> void:
	# 方式1: 原生模块 (Android Kotlin 插件 / 编译进引擎)
	if Engine.has_singleton("GoogleSignIn"):
		_plugin = Engine.get_singleton("GoogleSignIn")
		_plugin.connect("google_sign_in_success", _on_sign_in_success)
		_plugin.connect("google_sign_in_failed", _on_sign_in_failed)
		_plugin.connect("google_sign_in_cancelled", _on_sign_in_cancelled)
		print("[GoogleSignIn] Native plugin loaded")
		return

	# 方式2: SwiftGodot GDExtension (iOS)
	if ClassDB.class_exists("AuthPlugin"):
		_auth_plugin = ClassDB.instantiate("AuthPlugin")
		_auth_plugin.connect("google_sign_in_success", _on_sign_in_success)
		_auth_plugin.connect("google_sign_in_failed", _on_sign_in_failed)
		_auth_plugin.connect("google_sign_in_cancelled", _on_sign_in_cancelled)
		print("[GoogleSignIn] GDExtension plugin loaded")
		return

	print("[GoogleSignIn] Plugin not available (desktop/web build?)")


## Configure Google Sign-In with Web Client ID
func configure() -> void:
	if _plugin == null:
		return
	if _is_configured:
		return
	_plugin.configure(WEB_CLIENT_ID)
	_is_configured = true


## Start Google Sign-In flow
func sign_in() -> void:
	if _plugin:
		if not _is_configured:
			configure()
		_plugin.signIn()
	elif _auth_plugin:
		_auth_plugin.googleSignIn(WEB_CLIENT_ID)
	else:
		sign_in_failed.emit("Google Sign-In not available on this platform")


## Sign out from Google
func sign_out() -> void:
	if _plugin:
		_plugin.signOut()
	elif _auth_plugin:
		_auth_plugin.googleSignOut()


## Check if plugin is available
func is_available() -> bool:
	return _plugin != null or _auth_plugin != null


# ============================================================================
# Plugin signal handlers
# ============================================================================

func _on_sign_in_success(id_token: String) -> void:
	print("[GoogleSignIn] Success, got ID token")
	sign_in_success.emit(id_token)


func _on_sign_in_failed(error_msg: String) -> void:
	print("[GoogleSignIn] Failed: ", error_msg)
	sign_in_failed.emit(error_msg)


func _on_sign_in_cancelled() -> void:
	print("[GoogleSignIn] User cancelled")
	sign_in_cancelled.emit()
