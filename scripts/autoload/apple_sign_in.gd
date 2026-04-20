extends Node

## Apple Sign-In wrapper for iOS
## Autoload singleton — access via AppleSignIn

signal sign_in_success(id_token: String)
signal sign_in_failed(error_msg: String)
signal sign_in_cancelled

var _plugin = null
var _auth_plugin = null  # SwiftGodot GDExtension


func _ready() -> void:
	# 方式1: 原生模块 (编译进引擎)
	if Engine.has_singleton("AppleSignIn"):
		_plugin = Engine.get_singleton("AppleSignIn")
		_plugin.connect("apple_sign_in_success", _on_sign_in_success)
		_plugin.connect("apple_sign_in_failed", _on_sign_in_failed)
		_plugin.connect("apple_sign_in_cancelled", _on_sign_in_cancelled)
		print("[AppleSignIn] Native plugin loaded")
		return

	# 方式2: SwiftGodot GDExtension
	if ClassDB.class_exists("AuthPlugin"):
		_auth_plugin = ClassDB.instantiate("AuthPlugin")
		_auth_plugin.connect("apple_sign_in_success", _on_sign_in_success)
		_auth_plugin.connect("apple_sign_in_failed", _on_sign_in_failed)
		_auth_plugin.connect("apple_sign_in_cancelled", _on_sign_in_cancelled)
		print("[AppleSignIn] GDExtension plugin loaded")
		return

	print("[AppleSignIn] Plugin not available (desktop/web build?)")


## Start Apple Sign-In flow
func sign_in() -> void:
	if _plugin:
		_plugin.signIn()
	elif _auth_plugin:
		_auth_plugin.appleSignIn()
	else:
		sign_in_failed.emit("Apple Sign-In not available on this platform")


## Sign out from Apple
func sign_out() -> void:
	if _plugin:
		_plugin.signOut()


## Check if plugin is available
func is_available() -> bool:
	return _plugin != null or _auth_plugin != null


# ============================================================================
# Plugin signal handlers
# ============================================================================

func _on_sign_in_success(id_token: String) -> void:
	print("[AppleSignIn] Success, got ID token")
	sign_in_success.emit(id_token)


func _on_sign_in_failed(error_msg: String) -> void:
	print("[AppleSignIn] Failed: ", error_msg)
	sign_in_failed.emit(error_msg)


func _on_sign_in_cancelled() -> void:
	print("[AppleSignIn] User cancelled")
	sign_in_cancelled.emit()
