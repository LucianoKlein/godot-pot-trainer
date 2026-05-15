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
var _http_reset_pw: HTTPRequest


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
	_oauth_sub = _extract_jwt_sub(google_id_token)
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
func login_apple(apple_id_token: String) -> void:
	_oauth_sub = _extract_jwt_sub(apple_id_token)
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
	GoogleSignIn.sign_out()
	AppleSignIn.sign_out()
	is_logged_in = false
	user_email = ""
	user_id = ""
	id_token = ""
	refresh_token = ""
	_token_expires_at = 0.0
	user_role = ""
	services = {}
	_oauth_sub = ""
	_delete_auth()
	logout_completed.emit()


## Fetch user document from Firestore
## 并发查老库和新库，先到先用
func fetch_services() -> void:
	if user_id.is_empty() or id_token.is_empty():
		return
	# 已确认是 legacy 用户，直接用缓存，不重复查老库
	if is_legacy_user() and services.has("potTrainer"):
		SubscriptionManager.update_from_services(services)
		services_loaded.emit()
		return
	_services_resolved = false
	_old_db_done = false
	_new_db_done = false
	# 两路并发：老库 + 新库同时查
	if not user_email.is_empty():
		_query_old_db_by_email(user_email)
	else:
		_old_db_done = true
	_fetch_services_new()


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
		login_failed.emit("Network error")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		login_failed.emit("Invalid response")
		return
	if response_code != 200:
		var msg := _parse_firebase_error(data)
		login_failed.emit(msg)
		return
	_apply_auth_data(data)
	fetch_services()
	login_succeeded.emit(user_email)


func _on_signup_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		signup_failed.emit("Network error")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		signup_failed.emit("Invalid response")
		return
	if response_code != 200:
		var msg := _parse_firebase_error(data)
		signup_failed.emit(msg)
		return
	_apply_auth_data(data)
	_create_new_user()
	fetch_services()
	signup_succeeded.emit(user_email)


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
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null or response_code != 200:
		logout()
		return
	id_token = data.get("id_token", "")
	refresh_token = data.get("refresh_token", refresh_token)
	var expires_in := float(data.get("expires_in", "3600"))
	_token_expires_at = Time.get_unix_time_from_system() + expires_in
	_save_auth()


func _on_old_services_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# 老库查询回调：并发模式，不再 fallback 到新库（新库已经在并发查了）
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[FirebaseAuth] Old DB query failed or empty")
		_old_db_done = true
		_check_both_done_no_result()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Array:
		print("[FirebaseAuth] Old DB response not an array")
		_old_db_done = true
		_check_both_done_no_result()
		return
	for item in data:
		if item is Dictionary and item.has("document"):
			var doc: Dictionary = item["document"]
			var doc_name: String = doc.get("name", "")
			var old_uid := doc_name.get_slice("/", doc_name.get_slice_count("/") - 1)
			print("[FirebaseAuth] User found in old DB, uid: ", old_uid)
			_parse_services_data(doc)
			services["_legacy_user"] = true
			# role=admin 直接全权限，不需要查 user_activation_service
			if user_role == "admin":
				print("[FirebaseAuth] Old DB user is admin, granting full access")
				_old_db_done = true
				_resolve_services()
				return
			_fetch_old_activation(old_uid)
			return
	print("[FirebaseAuth] Old DB no matching user")
	_old_db_done = true
	_check_both_done_no_result()


func _fetch_old_activation(old_uid: String) -> void:
	_cancel_if_busy(_http_old_activation)
	var url := OLD_FIRESTORE_BASE + "/user_activation_service/" + old_uid + "?key=" + OLD_API_KEY
	_http_old_activation.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_GET)


func _on_old_activation_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_old_db_done = true
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
				services[svc_name] = {"expiresAt": expires_unix}
			print("[FirebaseAuth] Old DB activation services loaded: ", services.keys())
			_resolve_services()
			return
	print("[FirebaseAuth] Old DB activation query failed")
	_check_both_done_no_result()


func _on_services_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# 新库查询回调 (pot-limit-trainer)
	_new_db_done = true
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[FirebaseAuth] User not found in new DB")
		_check_both_done_no_result()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		_check_both_done_no_result()
		return
	print("[FirebaseAuth] User found in new DB (pot-limit-trainer)")
	_parse_services_data(data)
	_resolve_services()


# ============================================================================
# Internal
# ============================================================================

## 并发竞态：第一个成功返回有效权限的路线胜出
func _resolve_services() -> void:
	if _services_resolved:
		return
	_services_resolved = true
	_save_auth()
	SubscriptionManager.update_from_services(services)
	services_loaded.emit()


## 两路都完成但都没有有效权限时，emit 无权限结果
func _check_both_done_no_result() -> void:
	if _services_resolved:
		return
	if _old_db_done and _new_db_done:
		_services_resolved = true
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
	user_email = data.get("email", "")
	user_id = data.get("localId", "")
	id_token = data.get("idToken", "")
	refresh_token = data.get("refreshToken", "")
	var expires_in := float(data.get("expiresIn", "3600"))
	_token_expires_at = Time.get_unix_time_from_system() + expires_in
	services = {}
	user_role = ""
	_save_auth()


func _cancel_if_busy(http: HTTPRequest) -> void:
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http.cancel_request()


func _refresh_id_token() -> void:
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


## Parse Firestore user document into services + user_role
func _parse_services_data(data: Dictionary) -> void:
	services = {}
	user_role = ""
	var fields = data.get("fields", {})
	var role_raw = fields.get("role", {})
	if role_raw.has("stringValue"):
		user_role = role_raw["stringValue"]
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
		services[svc_name] = {"expiresAt": expires_unix}
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
			services["subscription"] = {"tier": tier_val, "expiresAt": exp_unix}


func _save_auth() -> void:
	var f := FileAccess.open(AUTH_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"email": user_email,
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
	user_id = data.get("user_id", "")
	id_token = data.get("id_token", "")
	refresh_token = data.get("refresh_token", "")
	_token_expires_at = float(data.get("expires_at", 0.0))
	user_role = data.get("role", "")
	var saved_services = data.get("services", null)
	if saved_services is Dictionary:
		services = saved_services
	if user_email != "" and refresh_token != "":
		is_logged_in = true
		if Time.get_unix_time_from_system() >= _token_expires_at - 60.0:
			_refresh_id_token()
		else:
			SubscriptionManager.update_from_services(services)
			services_loaded.emit()


func _delete_auth() -> void:
	if FileAccess.file_exists(AUTH_SAVE_PATH):
		DirAccess.remove_absolute(AUTH_SAVE_PATH)


## Load cached services from local storage (fallback when network fails)
func _load_cached_services() -> Dictionary:
	if not FileAccess.file_exists(AUTH_SAVE_PATH):
		return {}
	var f := FileAccess.open(AUTH_SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		var saved_services = data.get("services", null)
		if saved_services is Dictionary:
			return saved_services
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
		_check_both_done_no_result()
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
			"role": {"stringValue": "user"},
			"services": {"mapValue": {"fields": {}}},
		}
	})
	var headers := ["Authorization: Bearer " + id_token, "Content-Type: application/json"]
	_http_create_user.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_create_user_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("[FirebaseAuth] New user document created in new DB")
	else:
		print("[FirebaseAuth] Failed to create user in new DB: ", response_code)


## Write subscription info to new Firestore (pot-limit-trainer)
## Uses PATCH with upsert — creates document if it doesn't exist
func update_subscription(tier: String, expires_at: float, product_id: String) -> void:
	if user_id.is_empty() or id_token.is_empty():
		return
	_cancel_if_busy(_http_update_sub)
	var url := FIRESTORE_BASE + "/users/" + user_id + "?key=" + API_KEY
	var body := JSON.stringify({
		"fields": {
			"email": {"stringValue": user_email},
			"role": {"stringValue": user_role if not user_role.is_empty() else "user"},
			"subscription": {"mapValue": {"fields": {
				"tier": {"stringValue": tier},
				"expiresAt": {"doubleValue": expires_at},
				"productId": {"stringValue": product_id},
			}}},
		}
	})
	var headers := ["Authorization: Bearer " + id_token, "Content-Type: application/json"]
	_http_update_sub.request(url, headers, HTTPClient.METHOD_PATCH, body)


func _on_update_sub_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("[FirebaseAuth] Subscription written to new DB")
		subscription_write_completed.emit(true)
	else:
		print("[FirebaseAuth] Failed to write subscription: ", response_code)
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
