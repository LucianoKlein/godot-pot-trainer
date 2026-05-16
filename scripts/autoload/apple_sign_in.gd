extends Node

## Apple Sign-In wrapper for iOS
## Autoload singleton — access via AppleSignIn

signal sign_in_success(id_token: String, display_name: String)
signal sign_in_failed(error_msg: String)
signal sign_in_cancelled

var _plugin = null


func _ready() -> void:
	if ClassDB.class_exists("NativePlugin"):
		_plugin = ClassDB.instantiate("NativePlugin")
		_plugin.connect("apple_sign_in_success", _on_sign_in_success)
		_plugin.connect("apple_sign_in_failed", _on_sign_in_failed)
		_plugin.connect("apple_sign_in_cancelled", _on_sign_in_cancelled)
		print("[AppleSignIn] NativePlugin loaded")
		return
	print("[AppleSignIn] Plugin not available (platform=%s)" % OS.get_name())


func sign_in() -> void:
	if _plugin:
		_plugin.appleSignIn()
	else:
		sign_in_failed.emit("Apple Sign-In not available on this platform")


func sign_out() -> void:
	if _plugin:
		_plugin.appleSignOut()


func is_available() -> bool:
	return _plugin != null


# ============================================================================
# Plugin signal handlers
# ============================================================================

func _on_sign_in_success(id_token: String, display_name: String) -> void:
	print("[AppleSignIn] Success, got ID token")
	sign_in_success.emit(id_token, display_name)


func _on_sign_in_failed(error_msg: String) -> void:
	print("[AppleSignIn] Failed: ", error_msg)
	sign_in_failed.emit(error_msg)


func _on_sign_in_cancelled() -> void:
	print("[AppleSignIn] User cancelled")
	sign_in_cancelled.emit()
