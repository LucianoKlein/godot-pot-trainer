extends Node

## Firebase Authentication REST API wrapper
## Autoload singleton — access via FirebaseAuth

signal login_succeeded(email: String)
signal login_failed(error_msg: String)
signal signup_succeeded(email: String)
signal signup_failed(error_msg: String)
signal logout_completed
signal services_loaded

const API_KEY := "AIzaSyApKIQ66DzjYrs3DxknQLoHJ5r0YnWU7xg"
const AUTH_BASE := "https://identitytoolkit.googleapis.com/v1/accounts"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token"
const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/reg-training-tool/databases/(default)/documents"

# Auth state
var is_logged_in := false
var user_email := ""
var user_id := ""
var id_token := ""
var refresh_token := ""
var _token_expires_at := 0.0

# Service permissions: { "potTrainer": { "expiresAt": unix_seconds }, ... }
var services: Dictionary = {}

# Persistence
const AUTH_SAVE_PATH := "user://auth.json"

var _http_login: HTTPRequest
var _http_signup: HTTPRequest
var _http_refresh: HTTPRequest
var _http_services: HTTPRequest


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


## Sign in with Google OAuth id_token
func login_google(google_id_token: String) -> void:
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


## Logout — clear all state
func logout() -> void:
	is_logged_in = false
	user_email = ""
	user_id = ""
	id_token = ""
	refresh_token = ""
	_token_expires_at = 0.0
	services = {}
	_delete_auth()
	logout_completed.emit()


## Fetch service permissions from Firestore
func fetch_services() -> void:
	if user_id.is_empty() or id_token.is_empty():
		return
	var url := FIRESTORE_BASE + "/user_activation_service/" + user_id + "?key=" + API_KEY
	var headers := ["Authorization: Bearer " + id_token, "Content-Type: application/json"]
	_http_services.request(url, headers, HTTPClient.METHOD_GET)


## Check if potTrainer service is active (not expired)
func has_pot_trainer() -> bool:
	var now := Time.get_unix_time_from_system()
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
	fetch_services()
	signup_succeeded.emit(user_email)


func _on_refresh_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		# Network unavailable — keep cached login & services, just emit so UI updates
		services_loaded.emit()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null or response_code != 200:
		# Token truly revoked server-side — force logout
		logout()
		return
	id_token = data.get("id_token", "")
	refresh_token = data.get("refresh_token", refresh_token)
	var expires_in := float(data.get("expires_in", "3600"))
	_token_expires_at = Time.get_unix_time_from_system() + expires_in
	_save_auth()
	fetch_services()


func _on_services_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# Network/server error — keep cached services as fallback
		services_loaded.emit()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		services_loaded.emit()
		return
	services = {}
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
	_save_auth()
	services_loaded.emit()


# ============================================================================
# Internal
# ============================================================================

func _apply_auth_data(data: Dictionary) -> void:
	is_logged_in = true
	user_email = data.get("email", "")
	user_id = data.get("localId", "")
	id_token = data.get("idToken", "")
	refresh_token = data.get("refreshToken", "")
	var expires_in := float(data.get("expiresIn", "3600"))
	_token_expires_at = Time.get_unix_time_from_system() + expires_in
	services = {}
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
	var saved_services = data.get("services", null)
	if saved_services is Dictionary:
		services = saved_services
	if user_email != "" and refresh_token != "":
		is_logged_in = true
		# Emit cached services immediately so UI can render right away
		services_loaded.emit()
		# Then refresh in background — token expired? refresh it; still valid? just re-fetch services
		if Time.get_unix_time_from_system() >= _token_expires_at - 60.0:
			_refresh_id_token()
		else:
			fetch_services()


func _delete_auth() -> void:
	if FileAccess.file_exists(AUTH_SAVE_PATH):
		DirAccess.remove_absolute(AUTH_SAVE_PATH)


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
