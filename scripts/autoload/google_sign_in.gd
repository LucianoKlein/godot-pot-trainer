extends Node

## Google Sign-In wrapper for Android/iOS
## Autoload singleton — access via GoogleSignIn

signal sign_in_success(id_token: String)
signal sign_in_failed(error_msg: String)
signal sign_in_cancelled

const WEB_CLIENT_ID := "525819571029-u15gh7tqq4dsikopbh64g2ul2jbsnth1.apps.googleusercontent.com"
const IOS_CLIENT_ID := "525819571029-annmo16git9ksimi2g3epmgjiop6b7k0.apps.googleusercontent.com"

var _plugin = null
var _is_configured := false
var _is_ios := false


func _ready() -> void:
	# Android: Kotlin 插件
	if Engine.has_singleton("GoogleSignIn"):
		_plugin = Engine.get_singleton("GoogleSignIn")
		_plugin.connect("google_sign_in_success", _on_sign_in_success)
		_plugin.connect("google_sign_in_failed", _on_sign_in_failed)
		_plugin.connect("google_sign_in_cancelled", _on_sign_in_cancelled)
		print("[GoogleSignIn] Native plugin loaded (Android)")
		return

	# iOS: NativePlugin GDExtension
	if ClassDB.class_exists("NativePlugin"):
		_plugin = ClassDB.instantiate("NativePlugin")
		_plugin.connect("google_sign_in_success", _on_sign_in_success)
		_plugin.connect("google_sign_in_failed", _on_sign_in_failed)
		_plugin.connect("google_sign_in_cancelled", _on_sign_in_cancelled)
		_is_ios = true
		print("[GoogleSignIn] NativePlugin loaded (iOS)")
		return

	print("[GoogleSignIn] Plugin not available (platform=%s)" % OS.get_name())


func configure() -> void:
	if _plugin == null:
		return
	if _is_configured:
		return
	if not _is_ios:
		_plugin.configure(WEB_CLIENT_ID)
	_is_configured = true


func sign_in() -> void:
	if _plugin:
		if _is_ios:
			_plugin.googleSignIn(IOS_CLIENT_ID, WEB_CLIENT_ID)
		else:
			if not _is_configured:
				configure()
			_plugin.signIn()
	else:
		sign_in_failed.emit("Google Sign-In not available on this platform")


func sign_out() -> void:
	if _plugin:
		if _is_ios:
			_plugin.googleSignOut()
		else:
			_plugin.signOut()


func is_available() -> bool:
	return _plugin != null


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
