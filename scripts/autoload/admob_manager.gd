extends Node

## AdMobManager — Google AdMob rewarded ad singleton
## Autoload singleton — access via AdMobManager

signal rewarded_ad_loaded
signal rewarded_ad_failed_to_load(error: String)
signal rewarded_ad_opened
signal rewarded_ad_closed
signal rewarded_ad_completed
signal rewarded_ad_failed_to_show(error: String)

# AdMob IDs
const ANDROID_REWARDED_AD_UNIT_ID := "ca-app-pub-6026501864639451/7092183262"
const IOS_REWARDED_AD_UNIT_ID := "ca-app-pub-3940256099942544/1712485313"  # TODO: 替换为正式 iOS 广告单元 ID

var _admob_plugin = null
var _is_ad_loaded := false
var _is_ad_showing := false
var last_error := ""
var _retry_count := 0
const MAX_RETRY := 5
const RETRY_DELAYS := [5.0, 15.0, 30.0, 60.0, 120.0]


func _ready() -> void:
	if OS.get_name() == "Android":
		_init_android_admob()
	elif OS.get_name() == "iOS":
		_init_ios_admob()
	else:
		print("[AdMobManager] AdMob not available on this platform")


func _init_android_admob() -> void:
	if Engine.has_singleton("GodotAdMob"):
		_admob_plugin = Engine.get_singleton("GodotAdMob")
		_admob_plugin.initialize()
		print("[AdMobManager] AdMob initialized (Android)")
		_connect_signals()
		await get_tree().create_timer(2.0).timeout
		load_rewarded_ad()
	else:
		print("[AdMobManager] ERROR: GodotAdMob plugin not found!")


func _init_ios_admob() -> void:
	if ClassDB.class_exists("NativePlugin"):
		_admob_plugin = ClassDB.instantiate("NativePlugin")
		_admob_plugin.initializeAds()
		print("[AdMobManager] AdMob initialized (iOS/NativePlugin)")
		_connect_signals()
		if _admob_plugin.has_signal("att_authorization_completed"):
			_admob_plugin.att_authorization_completed.connect(_on_att_completed, CONNECT_ONE_SHOT)
			await get_tree().create_timer(1.0).timeout
			_admob_plugin.requestTrackingAuthorization()
		else:
			await get_tree().create_timer(2.0).timeout
			load_rewarded_ad()
	else:
		print("[AdMobManager] NativePlugin not found!")


func _connect_signals() -> void:
	if not _admob_plugin:
		return
	if _admob_plugin.has_signal("rewarded_ad_loaded"):
		_admob_plugin.rewarded_ad_loaded.connect(_on_rewarded_ad_loaded)
	if _admob_plugin.has_signal("rewarded_ad_failed_to_load"):
		_admob_plugin.rewarded_ad_failed_to_load.connect(_on_rewarded_ad_failed_to_load)
	if _admob_plugin.has_signal("rewarded_ad_opened"):
		_admob_plugin.rewarded_ad_opened.connect(_on_rewarded_ad_opened)
	if _admob_plugin.has_signal("rewarded_ad_closed"):
		_admob_plugin.rewarded_ad_closed.connect(_on_rewarded_ad_closed)
	if _admob_plugin.has_signal("user_earned_reward"):
		_admob_plugin.user_earned_reward.connect(_on_user_earned_reward)
	if _admob_plugin.has_signal("rewarded_ad_failed_to_show"):
		_admob_plugin.rewarded_ad_failed_to_show.connect(_on_rewarded_ad_failed_to_show)


func is_available() -> bool:
	return _admob_plugin != null


func load_rewarded_ad() -> void:
	if not _admob_plugin:
		rewarded_ad_failed_to_load.emit("AdMob not available")
		return
	var ad_unit_id := ANDROID_REWARDED_AD_UNIT_ID if OS.get_name() == "Android" else IOS_REWARDED_AD_UNIT_ID
	print("[AdMobManager] Loading rewarded ad: ", ad_unit_id)
	if OS.get_name() == "Android":
		_admob_plugin.call("load_rewarded_ad", ad_unit_id)
	else:
		_admob_plugin.loadRewardedAd(ad_unit_id)


func show_rewarded_ad() -> void:
	if not _admob_plugin:
		rewarded_ad_failed_to_show.emit("AdMob not available")
		return
	if not _is_ad_loaded:
		rewarded_ad_failed_to_show.emit("Ad not loaded")
		return
	if _is_ad_showing:
		return
	print("[AdMobManager] Showing rewarded ad")
	if OS.get_name() == "Android":
		_admob_plugin.call("show_rewarded_ad")
	else:
		_admob_plugin.showRewardedAd()
	_is_ad_showing = true


func is_ad_ready() -> bool:
	return _is_ad_loaded and not _is_ad_showing


# ============================================================================
# AdMob signal handlers
# ============================================================================

func _on_rewarded_ad_loaded() -> void:
	print("[AdMobManager] Rewarded ad loaded")
	_is_ad_loaded = true
	_retry_count = 0
	rewarded_ad_loaded.emit()


func _on_rewarded_ad_failed_to_load(error_code: int, error_msg: String) -> void:
	print("[AdMobManager] Ad failed to load: ", error_code, " - ", error_msg)
	_is_ad_loaded = false
	last_error = str(error_code) + ": " + error_msg
	rewarded_ad_failed_to_load.emit(error_msg)
	if _retry_count < MAX_RETRY:
		var delay: float = RETRY_DELAYS[_retry_count]
		_retry_count += 1
		await get_tree().create_timer(delay).timeout
		load_rewarded_ad()


func _on_rewarded_ad_opened() -> void:
	print("[AdMobManager] Rewarded ad opened")
	rewarded_ad_opened.emit()


func _on_rewarded_ad_closed() -> void:
	print("[AdMobManager] Rewarded ad closed")
	_is_ad_loaded = false
	_is_ad_showing = false
	rewarded_ad_closed.emit()
	await get_tree().create_timer(1.0).timeout
	load_rewarded_ad()


func _on_user_earned_reward(reward_type: String, reward_amount: int) -> void:
	print("[AdMobManager] User earned reward: ", reward_type, " x", reward_amount)
	rewarded_ad_completed.emit()


func _on_rewarded_ad_failed_to_show(error_code: int, error_msg: String) -> void:
	print("[AdMobManager] Ad failed to show: ", error_code, " - ", error_msg)
	_is_ad_loaded = false
	_is_ad_showing = false
	last_error = "show:" + str(error_code) + ": " + error_msg
	rewarded_ad_failed_to_show.emit(error_msg)


func _on_att_completed(status: int) -> void:
	print("[AdMobManager] ATT status=%d" % status)
	await get_tree().create_timer(1.0).timeout
	load_rewarded_ad()
