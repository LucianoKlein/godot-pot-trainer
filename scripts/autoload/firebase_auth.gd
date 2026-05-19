extends Node

## Firebase Authentication REST API wrapper
## Autoload singleton — access via FirebaseAuth

signal login_succeeded(email: String)
signal login_failed(error_msg: String)
signal signup_succeeded(email: String)
signal signup_failed(error_msg: String)
signal logout_completed
signal services_loaded
signal password_reset_sent
signal password_reset_failed(error_msg: String)
signal subscription_write_completed(success: bool)

const API_KEY := "AIzaSyB4kkW803TKH8EttKiqW-OvIFRgm26pljA"
const AUTH_BASE := "https://identitytoolkit.googleapis.com/v1/accounts"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token"
const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/pot-limit-trainer/databases/(default)/documents"

# 老库 (reg-training-tool) — 先查这里
const OLD_API_KEY := "AIzaSyApKIQ66DzjYrs3DxknQLoHJ5r0YnWU7xg"
const OLD_FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/reg-training-tool/databases/(default)/documents"

# Auth state
var is_logged_in := false
var user_email := ""
var user_display_name := ""
var user_id := ""
var id_token := ""
var refresh_token := ""
var _token_expires_at := 0.0

# OAuth provider sub (Google/Apple account unique ID, same across Firebase projects)
var _oauth_sub := ""

# User role from Firestore (e.g. "admin", "user")
var user_role := ""
# Service permissions: { "potTrainer": { "expiresAt": unix_seconds }, ... }
var services: Dictionary = {}

# 并发查询竞态控制
var _services_resolved := false
var _old_db_done := false
var _new_db_done := false
var _old_db_services: Dictionary = {}
var _old_db_role := ""
var _new_db_services: Dictionary = {}
var _new_db_role := ""
var _is_old_db_legacy := false

# Permission resolution state
var _resolving_permissions := false
var _resolve_timeout_timer: SceneTreeTimer = null

# Permissions cache
const PERMISSIONS_CACHE_PATH := "user://permissions_cache.json"

# Persistence
const AUTH_SAVE_PATH := "user://auth.json"

var _http_login: HTTPRequest
var _http_signup: HTTPRequest
var _http_refresh: HTTPRequest
var _http_services: HTTPRequest
var _http_services_old: HTTPRequest
var _http_old_activation: HTTPRequest
var _http_create_user: HTTPRequest
var _http_update_sub: HTTPRequest
var _http_update_profile: HTTPRequest
var _http_reset_pw: HTTPRequest

# Pending subscription write (deferred until token refresh completes)
var _pending_sub_tier := ""
var _pending_sub_expires := 0.0
var _pending_sub_product := ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if is_logged_in and not refresh_token.is_empty():
			_save_auth()


func _ready() -> void:
	_http_login = HTTPRequest.new()
	_http_login.name = "HttpLogin"
	_http_login.request_completed.connect(_on_login_completed)
	add_child(_http_login)

	_http_signup = HTTPRequest.new()
	_http_signup.name = "HttpSignup"
	_http_signup.request_completed.connect(_on_signup_completed)
	add_child(_http_signup)

	_http_refresh = HTTPRequest.new()
	_http_refresh.name = "HttpRefresh"
	_http_refresh.request_completed.connect(_on_refresh_completed)
	add_child(_http_refresh)

	_http_services = HTTPRequest.new()
	_http_services.name = "HttpServices"
	_http_services.request_completed.connect(_on_services_completed)
	add_child(_http_services)

	_http_services_old = HTTPRequest.new()
	_http_services_old.name = "HttpServicesOld"
	_http_services_old.request_completed.connect(_on_old_services_completed)
	add_child(_http_services_old)

	_http_old_activation = HTTPRequest.new()
	_http_old_activation.name = "HttpOldActivation"
	_http_old_activation.request_completed.connect(_on_old_activation_completed)
	add_child(_http_old_activation)

	_http_create_user = HTTPRequest.new()
	_http_create_user.name = "HttpCreateUser"
	_http_create_user.request_completed.connect(_on_create_user_completed)
	add_child(_http_create_user)

	_http_update_sub = HTTPRequest.new()
	_http_update_sub.name = "HttpUpdateSub"
	_http_update_sub.request_completed.connect(_on_update_sub_completed)
	add_child(_http_update_sub)

	_http_update_profile = HTTPRequest.new()
	_http_update_profile.name = "HttpUpdateProfile"
	_http_update_profile.request_completed.connect(_on_update_profile_completed)
	add_child(_http_update_profile)

	_http_reset_pw = HTTPRequest.new()
	_http_reset_pw.name = "HttpResetPw"
	_http_reset_pw.request_completed.connect(_on_reset_pw_completed)
	add_child(_http_reset_pw)

	_load_auth()


# ============================================================================
# Public API
# ============================================================================

## Email/password sign in
func login_email(email: String, password: String) -> void:
	SubscriptionManager._dlog("AUTH email_login → %s" % email)
	_cancel_if_busy(_http_login)
	var url := AUTH_BASE + ":signInWithPassword?key=" + API_KEY
	var body := JSON.stringify({
		"email": email,
		"password": password,
		"returnSecureToken": true,
	})
	var headers := ["Content-Type: application/json"]
	_http_login.request(url, headers, HTTPClient.METHOD_POST, body)


## Email/password sign up
func signup_email(email: String, password: String) -> void:
	_cancel_if_busy(_http_signup)
	var url := AUTH_BASE + ":signUp?key=" + API_KEY
	var body := JSON.stringify({
		"email": email,
		"password": password,
		"returnSecureToken": true,
	})
	var headers := ["Content-Type: application/json"]
	_http_signup.request(url, headers, HTTPClient.METHOD_POST, body)


## Send password reset email
func send_password_reset(email: String) -> void:
	_cancel_if_busy(_http_reset_pw)
	var url := AUTH_BASE + ":sendOobCode?key=" + API_KEY
	var body := JSON.stringify({
		"requestType": "PASSWORD_RESET",
		"email": email,
	})
	var headers := ["Content-Type: application/json"]
	_http_reset_pw.request(url, headers, HTTPClient.METHOD_POST, body)


## Sign in with Google OAuth id_token
func login_google(google_id_token: String) -> void:
	SubscriptionManager._dlog("AUTH google_login → token=%s...(%d)" % [google_id_token.left(12), google_id_token.length()])
	_oauth_sub = _extract_jwt_sub(google_id_token)
	var jwt_email := _extract_jwt_email(google_id_token)
	if not jwt_email.is_empty():
		user_email = jwt_email
	_cancel_if_busy(_http_login)
	var url := AUTH_BASE + ":signInWithIdp?key=" + API_KEY
	var body := JSON.stringify({
		"postBody": "id_token=" + google_id_token + "&providerId=google.com",
		"requestUri": "http://localhost",
		"returnIdpCredential": true,
		"returnSecureToken": true,
	})
	var headers := ["Content-Type: application/json"]
	_http_login.request(url, headers, HTTPClient.METHOD_POST, body)


## Sign in with Apple OAuth id_token
func login_apple(apple_id_token: String, apple_display_name: String = "") -> void:
	SubscriptionManager._dlog("AUTH apple_login → token=%s...(%d) name=%s" % [apple_id_token.left(12), apple_id_token.length(), apple_display_name])
	_oauth_sub = _extract_jwt_sub(apple_id_token)
	var jwt_email := _extract_jwt_email(apple_id_token)
	if not jwt_email.is_empty():
		user_email = jwt_email
	if not apple_display_name.is_empty():
		user_display_name = apple_display_name
		_save_auth()
	_cancel_if_busy(_http_login)
	var url := AUTH_BASE + ":signInWithIdp?key=" + API_KEY
	var body := JSON.stringify({
		"postBody": "id_token=" + apple_id_token + "&providerId=apple.com",
		"requestUri": "http://localhost",
		"returnIdpCredential": true,
		"returnSecureToken": true,
	})
	var headers := ["Content-Type: application/json"]
	_http_login.request(url, headers, HTTPClient.METHOD_POST, body)


## Logout — clear all state and disconnect OAuth providers
func logout() -> void:
	SubscriptionManager._dlog("AUTH logout → clearing state")
	GoogleSignIn.sign_out()
	AppleSignIn.sign_out()
	is_logged_in = false
	user_email = ""
	user_display_name = ""
	user_id = ""
	id_token = ""
	refresh_token = ""
	_token_expires_at = 0.0
	user_role = ""
	services = {}
	_oauth_sub = ""
	_resolving_permissions = false
	_delete_auth()
	_delete_permissions_cache()
	logout_completed.emit()


## Fetch user document from Firestore
## 新流程：通过 resolve_permissions() 编排，不再直接调用
func fetch_services() -> void:
	if user_id.is_empty() or id_token.is_empty():
		SubscriptionManager._dlog("AUTH fetch_services → skip (no uid/token)")
		return
	if is_legacy_user() and services.has("potTrainer"):
		SubscriptionManager._dlog("AUTH fetch_services → cached legacy user")
		SubscriptionManager.update_from_services(services)
		services_loaded.emit()
		return
	SubscriptionManager._dlog("AUTH fetch_services → delegating to resolve_permissions()")
	resolve_permissions()


## Check if user is admin
func is_admin() -> bool:
	return user_role == "admin"


## Check if potTrainer service is active (not expired)
func has_pot_trainer() -> bool:
	if is_admin():
		return true
	var now := Time.get_unix_time_from_system()
	if services.has("subscription"):
		var sub = services["subscription"]
		if sub.get("tier", "") == "pot_trainer" and float(sub.get("expiresAt", 0.0)) > now:
			return true
	if services.has("potTrainer"):
		var exp = services["potTrainer"].get("expiresAt", 0.0)
		if float(exp) > now:
			return true
	return false


## Check if token needs refresh (call before API requests)
func ensure_token_valid() -> void:
	if not is_logged_in or refresh_token.is_empty():
		return
	if Time.get_unix_time_from_system() >= _token_expires_at - 60.0:
		_refresh_id_token()


# ============================================================================
# HTTP callbacks
# ============================================================================

func _on_login_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		SubscriptionManager._dlog("AUTH login=FAIL network_err result=%d" % result)
		login_failed.emit("Network error")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		SubscriptionManager._dlog("AUTH login=FAIL invalid_response")
		login_failed.emit("Invalid response")
		return
	if response_code != 200:
		var msg := _parse_firebase_error(data)
		SubscriptionManager._dlog("AUTH login=FAIL http=%d err=%s" % [response_code, msg])
		login_failed.emit(msg)
		return
	_apply_auth_data(data)
	SubscriptionManager._dlog("AUTH login=OK uid=%s email=%s" % [user_id.left(8), user_email])
	if not _oauth_sub.is_empty():
		_create_new_user()
	login_succeeded.emit(user_email)
	resolve_permissions()


func _on_signup_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		SubscriptionManager._dlog("AUTH signup=FAIL network_err result=%d" % result)
		signup_failed.emit("Network error")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		SubscriptionManager._dlog("AUTH signup=FAIL invalid_response")
		signup_failed.emit("Invalid response")
		return
	if response_code != 200:
		var msg := _parse_firebase_error(data)
		SubscriptionManager._dlog("AUTH signup=FAIL http=%d err=%s" % [response_code, msg])
		signup_failed.emit(msg)
		return
	_apply_auth_data(data)
	SubscriptionManager._dlog("AUTH signup=OK uid=%s email=%s" % [user_id.left(8), user_email])
	_create_new_user()
	signup_succeeded.emit(user_email)
	resolve_permissions()


func _on_reset_pw_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		password_reset_failed.emit("Network error")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		password_reset_failed.emit("Invalid response")
		return
	if response_code != 200:
		var msg := _parse_firebase_error(data)
		password_reset_failed.emit(msg)
		return
	password_reset_sent.emit()


func _on_refresh_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		SubscriptionManager._dlog("AUTH refresh=FAIL network_err")
		_clear_pending_sub_write()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null or response_code != 200:
		SubscriptionManager._dlog("AUTH refresh=FAIL http=%d → logout" % response_code)
		_clear_pending_sub_write()
		logout()
		return
	id_token = data.get("id_token", "")
	refresh_token = data.get("refresh_token", refresh_token)
	var expires_in := float(data.get("expires_in", "3600"))
	_token_expires_at = Time.get_unix_time_from_system() + expires_in
	SubscriptionManager._dlog("AUTH refresh=OK expires_in=%ds" % int(expires_in))
	_save_auth()
	if not _pending_sub_tier.is_empty():
		var tier := _pending_sub_tier
		var exp := _pending_sub_expires
		var prod := _pending_sub_product
		_pending_sub_tier = ""
		_pending_sub_expires = 0.0
		_pending_sub_product = ""
		SubscriptionManager._dlog("AUTH refresh done → retrying update_sub")
		update_subscription(tier, exp, prod)
		return
	resolve_permissions()


func _on_old_services_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[FirebaseAuth] Old DB query failed or empty")
		_old_db_done = true
		_old_db_services = {}
		_old_db_role = ""
		_is_old_db_legacy = false
		_check_both_done()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Array:
		print("[FirebaseAuth] Old DB response not an array")
		_old_db_done = true
		_old_db_services = {}
		_old_db_role = ""
		_is_old_db_legacy = false
		_check_both_done()
		return
	for item in data:
		if item is Dictionary and item.has("document"):
			var doc: Dictionary = item["document"]
			var doc_name: String = doc.get("name", "")
			var old_uid := doc_name.get_slice("/", doc_name.get_slice_count("/") - 1)
			print("[FirebaseAuth] User found in old DB, uid: ", old_uid)
			var fields = doc.get("fields", {})
			var role_raw = fields.get("role", {})
			if role_raw.has("stringValue"):
				_old_db_role = role_raw["stringValue"]
			_is_old_db_legacy = true
			if _old_db_role == "admin":
				print("[FirebaseAuth] Old DB user is admin, granting full access")
				_old_db_done = true
				_old_db_services = {"_legacy_user": true}
				_check_both_done()
				return
			_fetch_old_activation(old_uid)
			return
	print("[FirebaseAuth] Old DB no matching user")
	_old_db_done = true
	_old_db_services = {}
	_old_db_role = ""
	_is_old_db_legacy = false
	_check_both_done()


func _fetch_old_activation(old_uid: String) -> void:
	_cancel_if_busy(_http_old_activation)
	var url := OLD_FIRESTORE_BASE + "/user_activation_service/" + old_uid + "?key=" + OLD_API_KEY
	_http_old_activation.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_GET)


func _on_old_activation_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_old_db_done = true
	_old_db_services = {"_legacy_user": true}
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary:
			var fields = data.get("fields", {})
			var svc_map = fields.get("services", {}).get("mapValue", {}).get("fields", {})
			for svc_name in svc_map:
				var svc_fields = svc_map[svc_name].get("mapValue", {}).get("fields", {})
				var expires_raw = svc_fields.get("expiresAt", {})
				var expires_unix := 0.0
				if expires_raw.has("timestampValue"):
					expires_unix = _parse_iso8601(expires_raw["timestampValue"])
				elif expires_raw.has("integerValue"):
					expires_unix = float(expires_raw["integerValue"])
				elif expires_raw.has("doubleValue"):
					expires_unix = float(expires_raw["doubleValue"])
				_old_db_services[svc_name] = {"expiresAt": expires_unix}
			print("[FirebaseAuth] Old DB activation services loaded: ", _old_db_services.keys())
			_check_both_done()
			return
	print("[FirebaseAuth] Old DB activation query failed")
	_check_both_done()


func _on_services_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_new_db_done = true
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[FirebaseAuth] User not found in new DB")
		_new_db_services = {}
		_new_db_role = ""
		_check_both_done()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		_new_db_services = {}
		_new_db_role = ""
		_check_both_done()
		return
	print("[FirebaseAuth] User found in new DB (pot-limit-trainer)")
	var fields = data.get("fields", {})
	var role_raw = fields.get("role", {})
	if role_raw.has("stringValue"):
		_new_db_role = role_raw["stringValue"]
	if user_display_name.is_empty():
		var dn_raw = fields.get("displayName", {})
		if dn_raw.has("stringValue") and not dn_raw["stringValue"].is_empty():
			user_display_name = dn_raw["stringValue"]
			_save_auth()
	_new_db_services = {}
	var svc_map = fields.get("services", {}).get("mapValue", {}).get("fields", {})
	for svc_name in svc_map:
		var svc_fields = svc_map[svc_name].get("mapValue", {}).get("fields", {})
		var expires_raw = svc_fields.get("expiresAt", {})
		var expires_unix := 0.0
		if expires_raw.has("timestampValue"):
			expires_unix = _parse_iso8601(expires_raw["timestampValue"])
		elif expires_raw.has("integerValue"):
			expires_unix = float(expires_raw["integerValue"])
		elif expires_raw.has("doubleValue"):
			expires_unix = float(expires_raw["doubleValue"])
		_new_db_services[svc_name] = {"expiresAt": expires_unix}
	var sub_raw = fields.get("subscription", {}).get("mapValue", {}).get("fields", {})
	if not sub_raw.is_empty():
		var tier_val = sub_raw.get("tier", {}).get("stringValue", "")
		var exp_val = sub_raw.get("expiresAt", {})
		var exp_unix := 0.0
		if exp_val.has("timestampValue"):
			exp_unix = _parse_iso8601(exp_val["timestampValue"])
		elif exp_val.has("doubleValue"):
			exp_unix = float(exp_val["doubleValue"])
		elif exp_val.has("integerValue"):
			exp_unix = float(exp_val["integerValue"])
		if not tier_val.is_empty():
			_new_db_services["subscription"] = {"tier": tier_val, "expiresAt": exp_unix}
	_check_both_done()


# ============================================================================
# Internal
# ============================================================================

## 两路都完成后，比较结果并确定最终权限
func _check_both_done() -> void:
	if _services_resolved:
		return
	if not (_old_db_done and _new_db_done):
		return
	_compare_and_resolve()


## 比较老表和新表结果，确定最终权限
func _compare_and_resolve() -> void:
	if _services_resolved:
		return
	_services_resolved = true
	SubscriptionManager._dlog("AUTH _compare_and_resolve: old_keys=%s new_keys=%s old_role=%s new_role=%s" % [
		str(_old_db_services.keys()), str(_new_db_services.keys()), _old_db_role, _new_db_role])

	if _old_db_role == "admin":
		user_role = "admin"
		services = _old_db_services.duplicate()
		_finalize_permissions("old_db")
		return

	if _new_db_role == "admin":
		user_role = "admin"
		services = _new_db_services.duplicate()
		_finalize_permissions("new_db")
		return

	var old_has_data := _old_db_services.size() > 0 and (_old_db_services.size() > 1 or not _old_db_services.has("_legacy_user"))
	var new_has_data := _new_db_services.size() > 0

	if old_has_data and not new_has_data:
		user_role = _old_db_role
		services = _old_db_services.duplicate()
		_finalize_permissions("old_db")
		return
	if new_has_data and not old_has_data:
		user_role = _new_db_role
		services = _new_db_services.duplicate()
		if _is_old_db_legacy:
			services["_legacy_user"] = true
		_finalize_permissions("new_db")
		return

	if old_has_data and new_has_data:
		user_role = _old_db_role if not _old_db_role.is_empty() else _new_db_role
		services = _new_db_services.duplicate()
		for key in _old_db_services:
			if key == "_legacy_user":
				services["_legacy_user"] = true
				continue
			if not services.has(key):
				services[key] = _old_db_services[key]
			else:
				var old_exp: float = float(_old_db_services[key].get("expiresAt", 0.0))
				var new_exp: float = float(services[key].get("expiresAt", 0.0))
				if old_exp > new_exp:
					services[key] = _old_db_services[key]
		if _is_old_db_legacy:
			services["_legacy_user"] = true
		_finalize_permissions("merged")
		return

	services = {}
	user_role = _new_db_role if not _new_db_role.is_empty() else _old_db_role
	if _is_old_db_legacy:
		services["_legacy_user"] = true
	_finalize_permissions("none")


## 最终确定权限：保存 + 缓存 + 发信号
func _finalize_permissions(source: String) -> void:
	if not is_logged_in:
		return
	SubscriptionManager._dlog("AUTH _finalize_permissions source=%s keys=%s" % [source, str(services.keys())])
	_save_auth()
	_save_permissions_cache(source)
	SubscriptionManager.update_from_services(services)
	_resolving_permissions = false
	if _resolve_timeout_timer != null:
		if _resolve_timeout_timer.timeout.is_connected(_on_resolve_timeout):
			_resolve_timeout_timer.timeout.disconnect(_on_resolve_timeout)
		_resolve_timeout_timer = null
	services_loaded.emit()


## Query old DB (reg-training-tool) by email using Firestore runQuery (no auth needed, uses API key)
func _query_old_db_by_email(email: String) -> void:
	_cancel_if_busy(_http_services_old)
	var url := OLD_FIRESTORE_BASE + ":runQuery?key=" + OLD_API_KEY
	var body := JSON.stringify({
		"structuredQuery": {
			"from": [{"collectionId": "users"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "email"},
					"op": "EQUAL",
					"value": {"stringValue": email}
				}
			},
			"limit": 1
		}
	})
	var headers := ["Content-Type: application/json"]
	_http_services_old.request(url, headers, HTTPClient.METHOD_POST, body)


func _apply_auth_data(data: Dictionary) -> void:
	is_logged_in = true
	var response_email: String = data.get("email", "")
	if not response_email.is_empty():
		user_email = response_email
	user_id = data.get("localId", "")
	id_token = data.get("idToken", "")
	refresh_token = data.get("refreshToken", "")
	var expires_in := float(data.get("expiresIn", "3600"))
	_token_expires_at = Time.get_unix_time_from_system() + expires_in
	var fb_display_name: String = data.get("displayName", "")
	if not fb_display_name.is_empty() and user_display_name.is_empty():
		user_display_name = fb_display_name
	services = {}
	user_role = ""
	_save_auth()


func _cancel_if_busy(http: HTTPRequest) -> void:
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http.cancel_request()


func _refresh_id_token() -> void:
	_cancel_if_busy(_http_refresh)
	var url := TOKEN_URL + "?key=" + API_KEY
	var body := "grant_type=refresh_token&refresh_token=" + refresh_token
	var headers := ["Content-Type: application/x-www-form-urlencoded"]
	_http_refresh.request(url, headers, HTTPClient.METHOD_POST, body)


func _parse_firebase_error(data) -> String:
	if data is Dictionary and data.has("error"):
		var err = data["error"]
		if err is Dictionary:
			var code: String = err.get("message", "UNKNOWN_ERROR")
			match code:
				"EMAIL_NOT_FOUND":
					return "EMAIL_NOT_FOUND"
				"INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS":
					return "INVALID_PASSWORD"
				"EMAIL_EXISTS":
					return "EMAIL_EXISTS"
				"WEAK_PASSWORD : Password should be at least 6 characters":
					return "WEAK_PASSWORD"
				"TOO_MANY_ATTEMPTS_TRY_LATER":
					return "TOO_MANY_ATTEMPTS"
				_:
					if code.begins_with("WEAK_PASSWORD"):
						return "WEAK_PASSWORD"
					return code
	return "UNKNOWN_ERROR"


## Parse Firestore user document into services + user_role (kept for backward compat)
func _parse_services_data(_data: Dictionary) -> void:
	pass


func _save_auth() -> void:
	var f := FileAccess.open(AUTH_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"email": user_email,
		"display_name": user_display_name,
		"user_id": user_id,
		"id_token": id_token,
		"refresh_token": refresh_token,
		"expires_at": _token_expires_at,
		"role": user_role,
		"services": services,
	}))
	f.close()


func _load_auth() -> void:
	if not FileAccess.file_exists(AUTH_SAVE_PATH):
		return
	var f := FileAccess.open(AUTH_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary:
		return
	user_email = data.get("email", "")
	user_display_name = data.get("display_name", "")
	user_id = data.get("user_id", "")
	id_token = data.get("id_token", "")
	refresh_token = data.get("refresh_token", "")
	_token_expires_at = float(data.get("expires_at", 0.0))
	user_role = data.get("role", "")
	var saved_services = data.get("services", null)
	if saved_services is Dictionary:
		services = saved_services
	if refresh_token != "" and (user_email != "" or user_id != ""):
		is_logged_in = true
		if Time.get_unix_time_from_system() >= _token_expires_at - 60.0:
			_refresh_id_token()
		else:
			if user_display_name.is_empty():
				call_deferred("resolve_permissions")
			else:
				call_deferred("_deferred_load_auth_complete")


func _delete_auth() -> void:
	if FileAccess.file_exists(AUTH_SAVE_PATH):
		DirAccess.remove_absolute(AUTH_SAVE_PATH)


func _deferred_load_auth_complete() -> void:
	SubscriptionManager.update_from_services(services)
	services_loaded.emit()


## Load cached services from local storage (deprecated, use load_permissions_cache)
func _load_cached_services() -> Dictionary:
	return {}


## Parse ISO 8601 timestamp string to Unix seconds
func _parse_iso8601(ts: String) -> float:
	var dt := {}
	var base := ts.replace("Z", "").replace("z", "")
	var t_parts := base.split("T")
	if t_parts.size() < 2:
		return 0.0
	var date_parts := t_parts[0].split("-")
	var time_str := t_parts[1].split(".")[0]
	var time_parts := time_str.split(":")
	if date_parts.size() < 3 or time_parts.size() < 3:
		return 0.0
	dt["year"] = int(date_parts[0])
	dt["month"] = int(date_parts[1])
	dt["day"] = int(date_parts[2])
	dt["hour"] = int(time_parts[0])
	dt["minute"] = int(time_parts[1])
	dt["second"] = int(time_parts[2])
	return float(Time.get_unix_time_from_datetime_dict(dt))


## Fetch user document from new Firestore (pot-limit-trainer)
func _fetch_services_new() -> void:
	if user_id.is_empty() or id_token.is_empty():
		_new_db_done = true
		_new_db_services = {}
		_new_db_role = ""
		_check_both_done()
		return
	_cancel_if_busy(_http_services)
	var url := FIRESTORE_BASE + "/users/" + user_id + "?key=" + API_KEY
	var headers := ["Authorization: Bearer " + id_token, "Content-Type: application/json"]
	_http_services.request(url, headers, HTTPClient.METHOD_GET)


## Create user document in new Firestore (pot-limit-trainer) after registration
func _create_new_user() -> void:
	if user_id.is_empty() or id_token.is_empty():
		return
	_cancel_if_busy(_http_create_user)
	var url := FIRESTORE_BASE + "/users?documentId=" + user_id + "&key=" + API_KEY
	var body := JSON.stringify({
		"fields": {
			"email": {"stringValue": user_email},
			"displayName": {"stringValue": user_display_name},
			"role": {"stringValue": "user"},
			"services": {"mapValue": {"fields": {}}},
		}
	})
	var headers := ["Authorization: Bearer " + id_token, "Content-Type: application/json"]
	_http_create_user.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_create_user_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("[FirebaseAuth] New user document created in new DB")
	else:
		print("[FirebaseAuth] Failed to create user in new DB: ", response_code)
		if response_code == 409:
			_update_user_profile()


## Write subscription info to new Firestore (pot-limit-trainer)
## Uses PATCH with updateMask — only updates subscription field
func update_subscription(tier: String, expires_at: float, product_id: String) -> void:
	if user_id.is_empty() or id_token.is_empty():
		SubscriptionManager._dlog("AUTH update_sub → skip (no uid/token)")
		subscription_write_completed.emit(false)
		return
	if Time.get_unix_time_from_system() >= _token_expires_at - 60.0:
		SubscriptionManager._dlog("AUTH update_sub → token expired, refreshing first")
		_pending_sub_tier = tier
		_pending_sub_expires = expires_at
		_pending_sub_product = product_id
		_refresh_id_token()
		return
	_cancel_if_busy(_http_update_sub)
	var url := FIRESTORE_BASE + "/users/" + user_id + "?updateMask.fieldPaths=subscription&key=" + API_KEY
	var body := JSON.stringify({
		"fields": {
			"subscription": {"mapValue": {"fields": {
				"tier": {"stringValue": tier},
				"expiresAt": {"doubleValue": expires_at},
				"productId": {"stringValue": product_id},
			}}},
		}
	})
	var headers := ["Authorization: Bearer " + id_token, "Content-Type: application/json"]
	SubscriptionManager._dlog("AUTH update_sub → PATCH tier=%s product=%s" % [tier, product_id])
	_http_update_sub.request(url, headers, HTTPClient.METHOD_PATCH, body)


func _on_update_sub_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		SubscriptionManager._dlog("AUTH update_sub → OK")
		subscription_write_completed.emit(true)
		_save_permissions_cache("purchase")
	else:
		var err_body := body.get_string_from_utf8().left(200)
		SubscriptionManager._dlog("AUTH update_sub → FAIL http=%d body=%s" % [response_code, err_body])
		subscription_write_completed.emit(false)


## Check if current user is a legacy user (found in old DB reg-training-tool)
func is_legacy_user() -> bool:
	return services.has("_legacy_user") and services["_legacy_user"] == true


## Extract 'sub' claim from JWT id_token (base64url-decoded payload)
func _extract_jwt_sub(jwt: String) -> String:
	var parts := jwt.split(".")
	if parts.size() < 2:
		return ""
	var payload_b64 := parts[1]
	payload_b64 = payload_b64.replace("-", "+").replace("_", "/")
	while payload_b64.length() % 4 != 0:
		payload_b64 += "="
	var decoded := Marshalls.base64_to_utf8(payload_b64)
	if decoded.is_empty():
		return ""
	var data = JSON.parse_string(decoded)
	if data is Dictionary:
		return data.get("sub", "")
	return ""


func _extract_jwt_email(jwt: String) -> String:
	var parts := jwt.split(".")
	if parts.size() < 2:
		return ""
	var payload_b64 := parts[1]
	payload_b64 = payload_b64.replace("-", "+").replace("_", "/")
	while payload_b64.length() % 4 != 0:
		payload_b64 += "="
	var decoded := Marshalls.base64_to_utf8(payload_b64)
	if decoded.is_empty():
		return ""
	var data = JSON.parse_string(decoded)
	if data is Dictionary:
		return data.get("email", "")
	return ""


func _clear_pending_sub_write() -> void:
	if not _pending_sub_tier.is_empty():
		_pending_sub_tier = ""
		_pending_sub_expires = 0.0
		_pending_sub_product = ""
		subscription_write_completed.emit(false)


## Update displayName/email on existing user document (used when _create_new_user gets 409)
func _update_user_profile() -> void:
	if user_id.is_empty() or id_token.is_empty():
		return
	var fields := {}
	var mask_parts: PackedStringArray = []
	if not user_display_name.is_empty():
		fields["displayName"] = {"stringValue": user_display_name}
		mask_parts.append("updateMask.fieldPaths=displayName")
	if not user_email.is_empty():
		fields["email"] = {"stringValue": user_email}
		mask_parts.append("updateMask.fieldPaths=email")
	if fields.is_empty():
		return
	_cancel_if_busy(_http_update_profile)
	var mask_query := "&".join(mask_parts)
	var url := FIRESTORE_BASE + "/users/" + user_id + "?" + mask_query + "&key=" + API_KEY
	var body_str := JSON.stringify({"fields": fields})
	var headers := ["Authorization: Bearer " + id_token, "Content-Type: application/json"]
	_http_update_profile.request(url, headers, HTTPClient.METHOD_PATCH, body_str)


func _on_update_profile_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		SubscriptionManager._dlog("AUTH update_profile → OK")
	else:
		SubscriptionManager._dlog("AUTH update_profile → FAIL http=%d" % response_code)


# ============================================================================
# Permission Resolution (核心编排)
# ============================================================================

## 主编排函数：登录成功后调用，按优先级查询权限
## 流程：RevenueCat(5s) → 两张Firestore表(10s) → 比较 → 确定权限
func resolve_permissions() -> void:
	if _resolving_permissions:
		SubscriptionManager._dlog("AUTH resolve_permissions → already in progress, skip")
		return
	_resolving_permissions = true
	SubscriptionManager._dlog("AUTH resolve_permissions → starting...")

	_resolve_timeout_timer = get_tree().create_timer(15.0)
	_resolve_timeout_timer.timeout.connect(_on_resolve_timeout)

	# 第一步：查 RevenueCat（5秒超时）
	SubscriptionManager._dlog("AUTH resolve_permissions → step 1: check RevenueCat")
	SubscriptionManager.check_revenuecat_active()
	var rc_has_active: bool = await SubscriptionManager.revenuecat_check_completed

	# 如果已经超时被强制结束了，不继续
	if not _resolving_permissions:
		return

	if rc_has_active:
		SubscriptionManager._dlog("AUTH resolve_permissions → RC has active subscription, done!")
		_resolving_permissions = false
		if _resolve_timeout_timer != null:
			if _resolve_timeout_timer.timeout.is_connected(_on_resolve_timeout):
				_resolve_timeout_timer.timeout.disconnect(_on_resolve_timeout)
			_resolve_timeout_timer = null
		_save_permissions_cache("revenuecat")
		services_loaded.emit()
		return

	# 第二步：同时查两张 Firestore 表
	SubscriptionManager._dlog("AUTH resolve_permissions → step 2: query both DBs")
	_services_resolved = false
	_old_db_done = false
	_new_db_done = false
	_old_db_services = {}
	_old_db_role = ""
	_new_db_services = {}
	_new_db_role = ""
	_is_old_db_legacy = false

	if not user_email.is_empty():
		_query_old_db_by_email(user_email)
	else:
		_old_db_done = true
		_old_db_services = {}
		_old_db_role = ""
	_fetch_services_new()


## 整体超时处理（15秒）
func _on_resolve_timeout() -> void:
	if not _resolving_permissions:
		return
	SubscriptionManager._dlog("AUTH _on_resolve_timeout: 15s elapsed, forcing resolution")
	_resolving_permissions = false
	_resolve_timeout_timer = null

	if not _services_resolved:
		_services_resolved = true
		if _old_db_done and _old_db_services.size() > 0:
			services = _old_db_services.duplicate()
			user_role = _old_db_role
		elif _new_db_done and _new_db_services.size() > 0:
			services = _new_db_services.duplicate()
			user_role = _new_db_role
		_save_auth()
		_save_permissions_cache("timeout")
		SubscriptionManager.update_from_services(services)
		services_loaded.emit()


# ============================================================================
# Permissions Cache (本地权限缓存)
# ============================================================================

func _save_permissions_cache(source: String) -> void:
	var cache := {
		"services": services,
		"role": user_role,
		"is_legacy_user": is_legacy_user(),
		"source": source,
		"cached_at": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(PERMISSIONS_CACHE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(cache))
	f.close()
	SubscriptionManager._dlog("AUTH _save_permissions_cache → OK source=%s" % source)


func load_permissions_cache() -> Variant:
	if not FileAccess.file_exists(PERMISSIONS_CACHE_PATH):
		return null
	var f := FileAccess.open(PERMISSIONS_CACHE_PATH, FileAccess.READ)
	if f == null:
		return null
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary:
		return null
	var cached_at: float = float(data.get("cached_at", 0.0))
	var now := Time.get_unix_time_from_system()
	if now - cached_at > 86400.0:
		SubscriptionManager._dlog("AUTH load_permissions_cache → expired (>24h)")
		return null
	return data


func apply_permissions_cache(cache: Dictionary) -> void:
	var cached_services = cache.get("services", null)
	if cached_services is Dictionary:
		services = cached_services
	user_role = cache.get("role", "")
	SubscriptionManager.update_from_services(services)
	SubscriptionManager._dlog("AUTH apply_permissions_cache → role=%s" % user_role)


func _delete_permissions_cache() -> void:
	if FileAccess.file_exists(PERMISSIONS_CACHE_PATH):
		DirAccess.remove_absolute(PERMISSIONS_CACHE_PATH)
