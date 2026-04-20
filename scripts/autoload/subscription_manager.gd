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
const RC_API_KEY_ANDROID := "YOUR_REVENUECAT_ANDROID_API_KEY"  # TODO: 替换
const RC_API_KEY_IOS := "YOUR_REVENUECAT_IOS_API_KEY"  # TODO: 替换

# --- State ---
var is_active := false
var _plugin = null
var _initialized := false

const SAVE_PATH := "user://subscription.json"


func _ready() -> void:
	_load_cache()
	_init_plugin()
	# 监听 Firebase services 加载完成，同步订阅状态
	FirebaseAuth.services_loaded.connect(func() -> void:
		update_from_services(FirebaseAuth.services)
	)
	FirebaseAuth.logout_completed.connect(func() -> void:
		is_active = false
		_save_cache()
		subscription_changed.emit(is_active)
		rc_logout()
	)


# ============================================================================
# Public API
# ============================================================================

## Check if user has active subscription
func is_subscribed() -> bool:
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
	_plugin.call("login", user_id)


## Logout from RevenueCat (call on Firebase logout)
func rc_logout() -> void:
	if _plugin == null:
		return
	_plugin.call("logout")
	is_active = false
	_save_cache()
	subscription_changed.emit(is_active)


## Purchase subscription
func purchase() -> void:
	if _plugin == null:
		purchase_failed.emit("Plugin not available")
		return
	_plugin.call("purchase", PRODUCT_ID)


## Restore previous purchases (required by Apple)
func restore_purchases() -> void:
	if _plugin == null:
		restore_completed.emit(is_active)
		return
	_plugin.call("restore_purchases")


## Refresh subscription status from RevenueCat
func refresh_status() -> void:
	if _plugin == null:
		return
	_plugin.call("get_customer_info")


## Update from Firebase services (server-side authority)
func update_from_services(services: Dictionary) -> void:
	var old_active := is_active
	if services.has("potTrainer"):
		var exp = services["potTrainer"].get("expiresAt", 0.0)
		is_active = float(exp) > Time.get_unix_time_from_system()
	else:
		is_active = false
	_save_cache()
	if is_active != old_active:
		subscription_changed.emit(is_active)


# ============================================================================
# Native plugin init + signal handling
# ============================================================================

func _init_plugin() -> void:
	var api_key := ""
	if OS.get_name() == "Android":
		if Engine.has_singleton("GodotRevenueCat"):
			_plugin = Engine.get_singleton("GodotRevenueCat")
			api_key = RC_API_KEY_ANDROID
		else:
			push_warning("SubscriptionManager: GodotRevenueCat Android plugin not found")
			return
	elif OS.get_name() == "iOS":
		if Engine.has_singleton("RevenueCatPlugin"):
			_plugin = Engine.get_singleton("RevenueCatPlugin")
			api_key = RC_API_KEY_IOS
		else:
			push_warning("SubscriptionManager: RevenueCatPlugin iOS plugin not found")
			return
	else:
		return

	_plugin.connect("configured", _on_configured)
	_plugin.connect("purchase_completed", _on_purchase_completed)
	_plugin.connect("purchase_failed", _on_purchase_failed)
	_plugin.connect("customer_info_updated", _on_customer_info_updated)
	_plugin.connect("restore_completed", _on_restore_completed)

	_plugin.call("configure", api_key)


func _on_configured() -> void:
	_initialized = true
	if FirebaseAuth.is_logged_in and not FirebaseAuth.user_id.is_empty():
		login(FirebaseAuth.user_id)


func _on_purchase_completed(product_id: String) -> void:
	if product_id == PRODUCT_ID:
		is_active = true
		_save_cache()
		subscription_changed.emit(is_active)
	purchase_success.emit(product_id)
	FirebaseAuth.fetch_services()


func _on_purchase_failed(error_code: int, error_msg: String) -> void:
	purchase_failed.emit(error_msg)


func _on_customer_info_updated(data: String) -> void:
	var parsed = JSON.parse_string(data)
	if not parsed is Dictionary:
		return
	var entitlements = parsed.get("entitlements", {})
	var old_active := is_active
	is_active = entitlements.has("pot_trainer") and entitlements["pot_trainer"].get("isActive", false)
	_save_cache()
	if is_active != old_active:
		subscription_changed.emit(is_active)


func _on_restore_completed(data: String) -> void:
	_on_customer_info_updated(data)
	restore_completed.emit(is_active)


# ============================================================================
# Local cache
# ============================================================================

func _save_cache() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"is_active": is_active}))
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
