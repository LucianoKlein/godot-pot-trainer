extends Node

## SubscriptionManager — RevenueCat 订阅管理单例
## 单一套餐 $12.99/月，解锁无广告无限答题

signal subscription_changed(is_active: bool)
signal purchase_success(product_id: String)
signal purchase_failed(error_msg: String)
signal restore_completed(is_active: bool)

# --- Product ID (must match RevenueCat / Store config) ---
const PRODUCT_ID := "pot_trainer_monthly"
const PRODUCT_PRICE := "$12.99"
const PRODUCT_PRICE_ZH := "$12.99"

# --- RevenueCat API Keys ---
const RC_API_KEY_ANDROID := "goog_OLNdDDEObSjfsgokvLPSnIampaL"
const RC_API_KEY_IOS := "appl_DeawsyDgODHDpysQjiSokdqXOCX"

# --- State ---
var is_active := false
var expires_at: float = 0.0
var _plugin = null
var _initialized := false
var _purchase_pending := false
var _purchase_timeout_timer: SceneTreeTimer = null
var _sync_loading_overlay: Control = null

# --- Debug Panel ---
const DEBUG_PURCHASE := true
var _debug_panel: PanelContainer = null
var _debug_label: RichTextLabel = null
var _debug_lines: Array[String] = []
const DEBUG_MAX_LINES := 40
var _dragging := false
var _drag_offset: Vector2 = Vector2.ZERO

const SAVE_PATH := "user://subscription.json"


func _ready() -> void:
	_load_cache()
	if DEBUG_PURCHASE:
		_build_debug_panel()
	_init_plugin()
	FirebaseAuth.logout_completed.connect(func() -> void:
		is_active = false
		expires_at = 0.0
		_save_cache()
		subscription_changed.emit(is_active)
		rc_logout()
	)
	FirebaseAuth.login_succeeded.connect(_on_firebase_login_succeeded)


# ============================================================================
# Public API
# ============================================================================

## Check if user has active subscription
func is_subscribed() -> bool:
	if FirebaseAuth.is_legacy_user():
		return true
	return is_active


## Get price display string
func get_price_display() -> String:
	if GameManager.language == "zh":
		return PRODUCT_PRICE_ZH
	return PRODUCT_PRICE


## Initialize RevenueCat with user ID (call after Firebase login)
func login(user_id: String) -> void:
	if _plugin == null:
		return
	if OS.get_name() == "iOS":
		_plugin.login(user_id)
	else:
		_plugin.call("login", user_id)


## Logout from RevenueCat (call on Firebase logout)
func rc_logout() -> void:
	if _plugin == null:
		return
	if OS.get_name() == "iOS":
		_plugin.logout()
	else:
		_plugin.call("logout")
	is_active = false
	expires_at = 0.0
	_save_cache()
	subscription_changed.emit(is_active)


## Purchase subscription
func purchase() -> void:
	_dlog("purchase() plugin=%s init=%s" % [str(_plugin != null), str(_initialized)])
	if _plugin == null:
		purchase_failed.emit("Plugin not available")
		return
	if not _initialized:
		_dlog("purchase ABORT: plugin not yet configured")
		purchase_failed.emit("Store not ready, please try again")
		return
	_purchase_pending = true
	_dlog("purchase: calling plugin.purchase('%s')" % PRODUCT_ID)
	if OS.get_name() == "iOS":
		_plugin.purchase(PRODUCT_ID)
	else:
		_plugin.call("purchase", PRODUCT_ID)
	_purchase_timeout_timer = get_tree().create_timer(30.0)
	_purchase_timeout_timer.timeout.connect(_on_purchase_timeout)


## Restore previous purchases (required by Apple)
func restore_purchases() -> void:
	if _plugin == null:
		restore_completed.emit(is_active)
		return
	if OS.get_name() == "iOS":
		_plugin.restorePurchases()
	else:
		_plugin.call("restore_purchases")


## Refresh subscription status from RevenueCat
func refresh_status() -> void:
	if _plugin == null:
		return
	if OS.get_name() == "iOS":
		_plugin.getCustomerInfo()
	else:
		_plugin.call("get_customer_info")


## Update from Firebase services (server-side authority)
func update_from_services(services: Dictionary) -> void:
	var old_active := is_active
	var now := Time.get_unix_time_from_system()
	var found := false
	if services.has("subscription"):
		var sub = services["subscription"]
		if sub.get("tier", "") == "pot_trainer" and float(sub.get("expiresAt", 0.0)) > now:
			is_active = true
			expires_at = float(sub.get("expiresAt", 0.0))
			found = true
	if not found and services.has("potTrainer"):
		var svc_expires := float(services["potTrainer"].get("expiresAt", 0.0))
		if svc_expires > now:
			is_active = true
			expires_at = svc_expires
			found = true
	if not found:
		is_active = false
		expires_at = 0.0
	_save_cache()
	if is_active != old_active:
		subscription_changed.emit(is_active)


## Check if cached subscription is still valid (not expired)
func is_cache_valid() -> bool:
	if not is_active:
		return true
	if expires_at <= 0.0:
		return false
	return Time.get_unix_time_from_system() < expires_at


# ============================================================================
# Native plugin init + signal handling
# ============================================================================

func _init_plugin() -> void:
	var api_key := ""
	_dlog("_init_plugin() OS=%s" % OS.get_name())
	if OS.get_name() == "Android":
		var has_it := Engine.has_singleton("GodotRevenueCat")
		_dlog("Android: has_singleton(GodotRevenueCat)=%s" % str(has_it))
		if has_it:
			_plugin = Engine.get_singleton("GodotRevenueCat")
			api_key = RC_API_KEY_ANDROID
		else:
			push_warning("SubscriptionManager: GodotRevenueCat Android plugin not found")
			_dlog("FAIL: Android plugin not found")
			return
	elif OS.get_name() == "iOS":
		var has_it := ClassDB.class_exists("NativePlugin")
		_dlog("iOS: ClassDB.class_exists(NativePlugin)=%s" % str(has_it))
		if has_it:
			_plugin = ClassDB.instantiate("NativePlugin")
			api_key = RC_API_KEY_IOS
		else:
			push_warning("SubscriptionManager: NativePlugin not found (iOS)")
			_dlog("FAIL: iOS NativePlugin not found")
			return
	else:
		_dlog("Desktop/editor — no plugin")
		return

	_plugin.connect("configured", _on_configured)
	if OS.get_name() == "iOS":
		_plugin.connect("offerings_loaded", _on_offerings_received)
	else:
		_plugin.connect("offerings_received", _on_offerings_received)
	_plugin.connect("purchase_completed", _on_purchase_completed)
	_plugin.connect("purchase_failed", _on_purchase_failed)
	_plugin.connect("customer_info_updated", _on_customer_info_updated)
	_plugin.connect("restore_completed", _on_restore_completed)

	_dlog("calling configure() key=%s...%s" % [api_key.left(8), api_key.right(4)])
	if OS.get_name() == "iOS":
		_plugin.initializeRevenueCat(api_key)
	else:
		_plugin.call("configure", api_key)


func _on_configured() -> void:
	_initialized = true
	_dlog("_on_configured OK! logged_in=%s uid=%s" % [str(FirebaseAuth.is_logged_in), FirebaseAuth.user_id.left(12)])
	if FirebaseAuth.is_logged_in and not FirebaseAuth.user_id.is_empty():
		login(FirebaseAuth.user_id)
	fetch_offerings()


func _on_firebase_login_succeeded(_email: String) -> void:
	if _initialized and not FirebaseAuth.user_id.is_empty():
		_dlog("Firebase login → RC login uid=%s" % FirebaseAuth.user_id.left(12))
		login(FirebaseAuth.user_id)


func fetch_offerings() -> void:
	_dlog("fetch_offerings() plugin=%s" % str(_plugin != null))
	if _plugin == null:
		return
	if OS.get_name() == "iOS":
		_plugin.fetchOfferings()
	else:
		_plugin.call("get_offerings")


func _on_offerings_received(data: String) -> void:
	var parsed = JSON.parse_string(data)
	var pkg_count := 0
	if parsed is Dictionary and parsed.has("packages"):
		pkg_count = parsed["packages"].size() if parsed["packages"] is Array else 0
	_dlog("_on_offerings_received: packages=%d raw_len=%d" % [pkg_count, data.length()])


func _on_purchase_completed(product_id: String) -> void:
	_cancel_purchase_timeout()
	_dlog("_on_purchase_completed: product=%s" % product_id)
	if product_id == PRODUCT_ID:
		is_active = true
		expires_at = Time.get_unix_time_from_system() + 30.0 * 86400.0
		_save_cache()
		subscription_changed.emit(is_active)
		_show_sync_loading()
		FirebaseAuth.update_subscription("pot_trainer", expires_at, product_id)
		FirebaseAuth.subscription_write_completed.connect(_on_sync_done, CONNECT_ONE_SHOT)
		var timeout := get_tree().create_timer(10.0)
		timeout.timeout.connect(func() -> void:
			if _sync_loading_overlay != null:
				_on_sync_done(false)
				if FirebaseAuth.subscription_write_completed.is_connected(_on_sync_done):
					FirebaseAuth.subscription_write_completed.disconnect(_on_sync_done)
		)
	else:
		purchase_success.emit(product_id)


func _on_sync_done(_success: bool) -> void:
	_remove_sync_loading()
	_dlog("sync done, success=%s, emitting purchase_success" % str(_success))
	purchase_success.emit(PRODUCT_ID)
	FirebaseAuth.fetch_services()


func _on_purchase_failed(error_code: int, error_msg: String) -> void:
	_cancel_purchase_timeout()
	_dlog("_on_purchase_failed: code=%d msg=%s" % [error_code, error_msg])
	purchase_failed.emit(error_msg)


func _on_purchase_timeout() -> void:
	if not _purchase_pending:
		return
	_purchase_pending = false
	_dlog("_on_purchase_timeout: no response from plugin in 30s")
	purchase_failed.emit("Purchase timeout — no response from store (30s)")


func _cancel_purchase_timeout() -> void:
	_purchase_pending = false
	if _purchase_timeout_timer != null:
		if _purchase_timeout_timer.timeout.is_connected(_on_purchase_timeout):
			_purchase_timeout_timer.timeout.disconnect(_on_purchase_timeout)
		_purchase_timeout_timer = null


func _on_customer_info_updated(data: String) -> void:
	var parsed = JSON.parse_string(data)
	if not parsed is Dictionary:
		return
	var entitlements = parsed.get("entitlements", {})
	var old_active := is_active
	is_active = false
	expires_at = 0.0
	if entitlements.has("pot_trainer") and entitlements["pot_trainer"].get("isActive", false):
		is_active = true
		expires_at = _parse_entitlement_expiry(entitlements["pot_trainer"])
	_save_cache()
	if is_active != old_active:
		subscription_changed.emit(is_active)
	if is_active:
		FirebaseAuth.update_subscription("pot_trainer", expires_at, PRODUCT_ID)


func _on_restore_completed(data: String) -> void:
	_on_customer_info_updated(data)
	restore_completed.emit(is_active)


## Parse expiration date from RevenueCat entitlement data
func _parse_entitlement_expiry(entitlement: Dictionary) -> float:
	var exp_str = entitlement.get("expirationDate", "")
	if exp_str is String and not exp_str.is_empty():
		return FirebaseAuth._parse_iso8601(exp_str)
	var exp_ms = entitlement.get("expirationDateMillis", 0)
	if exp_ms > 0:
		return float(exp_ms) / 1000.0
	return 0.0


# ============================================================================
# Local cache
# ============================================================================

func _save_cache() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"is_active": is_active, "expires_at": expires_at}))
	f.close()


func _load_cache() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		is_active = bool(data.get("is_active", false))
		expires_at = float(data.get("expires_at", 0.0))
		if is_active and expires_at > 0.0 and Time.get_unix_time_from_system() >= expires_at:
			is_active = false
			expires_at = 0.0
			_save_cache()


func _t(en: String, zh: String) -> String:
	return zh if GameManager.language == "zh" else en


# ============================================================================
# Sync loading overlay
# ============================================================================

func _show_sync_loading() -> void:
	if _sync_loading_overlay != null:
		return
	var root := get_tree().root
	var overlay := ColorRect.new()
	overlay.name = "SyncLoadingOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	ps.border_color = Color(0.82, 0.66, 0.26)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(12)
	ps.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = _t("Syncing...", "同步中...")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = _t("Saving subscription data, please wait...", "正在保存订阅数据，请稍候...")
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	root.add_child(overlay)
	_sync_loading_overlay = overlay


func _remove_sync_loading() -> void:
	if _sync_loading_overlay != null and is_instance_valid(_sync_loading_overlay):
		_sync_loading_overlay.queue_free()
	_sync_loading_overlay = null


# ============================================================================
# Debug Panel
# ============================================================================

func _build_debug_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)

	_debug_panel = PanelContainer.new()
	_debug_panel.position = Vector2(10, 650)
	_debug_panel.custom_minimum_size = Vector2(500, 40)
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	_debug_panel.add_theme_stylebox_override("panel", style)
	_debug_panel.gui_input.connect(_on_debug_panel_input)
	canvas.add_child(_debug_panel)

	var vbox := VBoxContainer.new()
	_debug_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "[RC Debug] (drag to move)"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var toggle_btn := Button.new()
	toggle_btn.text = "+"
	toggle_btn.flat = true
	toggle_btn.add_theme_font_size_override("font_size", 22)
	toggle_btn.pressed.connect(func() -> void:
		_debug_label.visible = not _debug_label.visible
		toggle_btn.text = "—" if _debug_label.visible else "+"
		if _debug_label.visible:
			_debug_panel.custom_minimum_size = Vector2(500, 350)
		else:
			_debug_panel.custom_minimum_size = Vector2(500, 40)
	)
	header.add_child(toggle_btn)

	_debug_label = RichTextLabel.new()
	_debug_label.bbcode_enabled = true
	_debug_label.fit_content = false
	_debug_label.scroll_following = true
	_debug_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debug_label.custom_minimum_size = Vector2(0, 300)
	_debug_label.add_theme_font_size_override("normal_font_size", 20)
	_debug_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	_debug_label.visible = false
	vbox.add_child(_debug_label)

	_dlog("panel ready, OS=%s" % OS.get_name())


func _on_debug_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = event.position
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_debug_panel.position += event.relative


func _dlog(msg: String) -> void:
	var ts := Time.get_time_string_from_system().substr(0, 8)
	var line := "[%s] %s" % [ts, msg]
	print("[RC] " + line)
	if not DEBUG_PURCHASE:
		return
	_debug_lines.append(line)
	if _debug_lines.size() > DEBUG_MAX_LINES:
		_debug_lines = _debug_lines.slice(-DEBUG_MAX_LINES)
	if _debug_label and is_instance_valid(_debug_label):
		_debug_label.text = "\n".join(_debug_lines)
