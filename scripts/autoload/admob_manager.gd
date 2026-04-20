extends Node
## AdMobManager — Google AdMob 激励广告管理单例

signal rewarded_ad_loaded()
signal rewarded_ad_failed_to_load(error_message: String)
signal rewarded_ad_opened()
signal rewarded_ad_closed()
signal rewarded_ad_completed()  # 用户看完广告，发放奖励
signal rewarded_ad_failed_to_show(error_message: String)

# AdMob IDs — TODO: 替换为正式 ID
const ANDROID_REWARDED_AD_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"  # 测试 rewarded ad ID
const IOS_REWARDED_AD_UNIT_ID := "ca-app-pub-3940256099942544/1712485313"  # 测试 rewarded ad ID

var _admob_plugin: Object = null
var _is_initialized: bool = false
var _is_ad_loaded: bool = false
var _is_showing: bool = false


func _ready() -> void:
	if OS.get_name() == "Android":
		_init_android()
	elif OS.get_name() == "iOS":
		_init_ios()
	else:
		print("[AdMob] AdMob not available on this platform")


func _init_android() -> void:
	if Engine.has_singleton("GodotAdMob"):
		_admob_plugin = Engine.get_singleton("GodotAdMob")
		_admob_plugin.initialize()
		_is_initialized = true
		print("[AdMob] Initialized (Android)")
		_connect_signals()
		# 延迟预加载第一个广告
		await get_tree().create_timer(2.0).timeout
		load_rewarded_ad()
	else:
		print("[AdMob] GodotAdMob plugin not found")


func _init_ios() -> void:
	if Engine.has_singleton("GodotAdMob"):
		_admob_plugin = Engine.get_singleton("GodotAdMob")
		_admob_plugin.initialize()
		_is_initialized = true
		print("[AdMob] Initialized (iOS)")
		_connect_signals()
		await get_tree().create_timer(2.0).timeout
		load_rewarded_ad()
	else:
		print("[AdMob] GodotAdMob plugin not found")


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


## Check if AdMob is available
func is_available() -> bool:
	return _admob_plugin != null


## Load a rewarded ad
func load_rewarded_ad() -> void:
	if not _admob_plugin:
		rewarded_ad_failed_to_load.emit("AdMob not available")
		return
	var ad_unit_id := ANDROID_REWARDED_AD_UNIT_ID if OS.get_name() == "Android" else IOS_REWARDED_AD_UNIT_ID
	print("[AdMob] Loading rewarded ad: ", ad_unit_id)
	if _admob_plugin.has_method("load_rewarded_ad"):
		_admob_plugin.load_rewarded_ad(ad_unit_id)
	else:
		rewarded_ad_failed_to_load.emit("Method not found")


## Show the loaded rewarded ad
func show_rewarded_ad() -> void:
	if not _admob_plugin:
		rewarded_ad_failed_to_show.emit("AdMob not available")
		return
	if not _is_ad_loaded:
		rewarded_ad_failed_to_show.emit("Ad not loaded")
		return
	if _is_showing:
		return
	print("[AdMob] Showing rewarded ad")
	if _admob_plugin.has_method("show_rewarded_ad"):
		_admob_plugin.show_rewarded_ad()
		_is_showing = true
	else:
		rewarded_ad_failed_to_show.emit("Method not found")


## Check if ad is ready to show
func is_ad_ready() -> bool:
	return _is_ad_loaded and not _is_showing


# --- AdMob signal handlers ---

func _on_rewarded_ad_loaded() -> void:
	print("[AdMob] Rewarded ad loaded")
	_is_ad_loaded = true
	rewarded_ad_loaded.emit()


func _on_rewarded_ad_failed_to_load(error_code: int, error_msg: String) -> void:
	print("[AdMob] Rewarded ad failed to load: ", error_code, " - ", error_msg)
	_is_ad_loaded = false
	rewarded_ad_failed_to_load.emit(error_msg)


func _on_rewarded_ad_opened() -> void:
	print("[AdMob] Rewarded ad opened")
	rewarded_ad_opened.emit()


func _on_rewarded_ad_closed() -> void:
	print("[AdMob] Rewarded ad closed")
	_is_ad_loaded = false
	_is_showing = false
	rewarded_ad_closed.emit()
	# 预加载下一个广告
	load_rewarded_ad()


func _on_user_earned_reward(reward_type: String, reward_amount: int) -> void:
	print("[AdMob] User earned reward: ", reward_type, " x", reward_amount)
	rewarded_ad_completed.emit()


func _on_rewarded_ad_failed_to_show(error_code: int, error_msg: String) -> void:
	print("[AdMob] Rewarded ad failed to show: ", error_code, " - ", error_msg)
	_is_ad_loaded = false
	_is_showing = false
	rewarded_ad_failed_to_show.emit(error_msg)
	# 尝试重新加载
	load_rewarded_ad()
