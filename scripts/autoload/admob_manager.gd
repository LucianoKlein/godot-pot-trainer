extends Node
## AdMobManager — Google AdMob 插屏广告管理单例

signal ad_loaded()
signal ad_failed_to_load(error_message: String)
signal ad_opened()
signal ad_closed()
signal ad_failed_to_show(error_message: String)

# 测试广告 ID（开发阶段使用，不会产生真实收益）
const TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"  # AdMob 官方测试 App ID
const TEST_AD_UNIT_ID := "ca-app-pub-3940256099942544/1033173712"  # AdMob 官方测试插屏广告 ID

# 正式广告 ID（上架后替换为你在 AdMob 后台创建的 ID）
const PROD_APP_ID := "ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"  # TODO: 替换为正式 App ID
const PROD_AD_UNIT_ID := "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ"  # TODO: 替换为正式广告单元 ID

# 是否使用测试广告（上架前设为 false）
var use_test_ads: bool = true

var _admob_plugin: Object = null
var _is_initialized: bool = false
var _is_ad_loaded: bool = false
var _is_showing: bool = false


func _ready() -> void:
	_initialize_admob()


func _initialize_admob() -> void:
	# 检查 AdMob 插件是否存在
	if Engine.has_singleton("AdMob"):
		_admob_plugin = Engine.get_singleton("AdMob")
		print("[AdMob] Plugin found, initializing...")

		# 连接插件信号
		_admob_plugin.interstitial_loaded.connect(_on_interstitial_loaded)
		_admob_plugin.interstitial_failed_to_load.connect(_on_interstitial_failed_to_load)
		_admob_plugin.interstitial_opened.connect(_on_interstitial_opened)
		_admob_plugin.interstitial_closed.connect(_on_interstitial_closed)
		_admob_plugin.interstitial_failed_to_show.connect(_on_interstitial_failed_to_show)

		# 初始化 AdMob
		var app_id := TEST_APP_ID if use_test_ads else PROD_APP_ID
		_admob_plugin.initialize(app_id)
		_is_initialized = true
		print("[AdMob] Initialized with App ID: ", app_id)

		# 预加载第一个广告
		load_interstitial()
	else:
		print("[AdMob] Plugin not found. Ads will not be shown.")
		print("[AdMob] Make sure the AdMob plugin is installed and enabled in Project Settings.")


func load_interstitial() -> void:
	if not _is_initialized or _admob_plugin == null:
		print("[AdMob] Cannot load ad: plugin not initialized")
		ad_failed_to_load.emit("Plugin not initialized")
		return

	if _is_ad_loaded:
		print("[AdMob] Ad already loaded, skipping")
		return

	var ad_unit_id := TEST_AD_UNIT_ID if use_test_ads else PROD_AD_UNIT_ID
	print("[AdMob] Loading interstitial ad: ", ad_unit_id)
	_admob_plugin.load_interstitial(ad_unit_id)


func show_interstitial() -> void:
	if not _is_initialized or _admob_plugin == null:
		print("[AdMob] Cannot show ad: plugin not initialized")
		ad_failed_to_show.emit("Plugin not initialized")
		return

	if not _is_ad_loaded:
		print("[AdMob] Cannot show ad: ad not loaded yet")
		ad_failed_to_show.emit("Ad not loaded")
		return

	if _is_showing:
		print("[AdMob] Ad already showing, skipping")
		return

	print("[AdMob] Showing interstitial ad")
	_admob_plugin.show_interstitial()


func is_ad_ready() -> bool:
	return _is_initialized and _is_ad_loaded and not _is_showing


# --- AdMob 插件回调 ---

func _on_interstitial_loaded() -> void:
	print("[AdMob] Interstitial ad loaded successfully")
	_is_ad_loaded = true
	ad_loaded.emit()


func _on_interstitial_failed_to_load(error_code: int, error_message: String) -> void:
	print("[AdMob] Failed to load interstitial ad: ", error_message, " (code: ", error_code, ")")
	_is_ad_loaded = false
	ad_failed_to_load.emit(error_message)


func _on_interstitial_opened() -> void:
	print("[AdMob] Interstitial ad opened")
	_is_showing = true
	ad_opened.emit()


func _on_interstitial_closed() -> void:
	print("[AdMob] Interstitial ad closed")
	_is_showing = false
	_is_ad_loaded = false
	ad_closed.emit()
	# 预加载下一个广告
	load_interstitial()


func _on_interstitial_failed_to_show(error_message: String) -> void:
	print("[AdMob] Failed to show interstitial ad: ", error_message)
	_is_showing = false
	_is_ad_loaded = false
	ad_failed_to_show.emit(error_message)
	# 尝试重新加载
	load_interstitial()
