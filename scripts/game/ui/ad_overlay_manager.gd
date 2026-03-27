class_name AdOverlayManager
extends RefCounted
## AdOverlayManager — 游客模式广告界面管理器
## 优先使用 AdMob 真实广告，失败时降级到 fallback 倒计时界面

var _parent: Control
var _overlay: Control
var _countdown_label: Label
var _close_btn: Button
var _remaining_time: float = 0.0
var _is_showing: bool = false
var _is_using_fallback: bool = false


func setup(parent: Control) -> RefCounted:
	_parent = parent
	_connect_admob_signals()
	return self


func build() -> void:
	_overlay = Control.new()
	_overlay.name = "AdOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 500
	_overlay.visible = false
	_parent.add_child(_overlay)

	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	_overlay.add_child(bg)

	# Center container
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -300
	center.offset_right = 300
	center.offset_top = -200
	center.offset_bottom = 200
	center.add_theme_constant_override("separation", 30)
	_overlay.add_child(center)

	# Title
	var title := Label.new()
	title.text = Locale.tr_key("ad_title")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.94, 0.80, 0.31))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	# Countdown label
	_countdown_label = Label.new()
	_countdown_label.add_theme_font_size_override("font_size", 28)
	_countdown_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_countdown_label)

	# Login hint
	var hint := Label.new()
	hint.text = Locale.tr_key("ad_login_hint")
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.82, 0.66, 0.26))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(hint)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = Locale.tr_key("ad_close")
	_close_btn.custom_minimum_size = Vector2(200, 60)
	_close_btn.disabled = true
	_close_btn.add_theme_font_size_override("font_size", 24)
	_close_btn.pressed.connect(_on_close_pressed)

	_close_btn.add_theme_stylebox_override("normal", UiFactory.make_stylebox(
		Color(0.08, 0.08, 0.10, 0.82), 6, 12, Color(0.82, 0.66, 0.26), 1))
	_close_btn.add_theme_stylebox_override("disabled", UiFactory.make_stylebox(
		Color(0.08, 0.08, 0.10, 0.60), 6, 12, Color(0.30, 0.25, 0.12), 1))
	_close_btn.add_theme_color_override("font_disabled_color", Color(0.40, 0.35, 0.20))

	center.add_child(_close_btn)


func show_ad() -> void:
	# 优先尝试显示 AdMob 真实广告
	if AdMobManager.is_ad_ready():
		print("[AdOverlay] Showing AdMob interstitial ad")
		AdMobManager.show_interstitial()
		_is_showing = true
		_is_using_fallback = false
	else:
		# AdMob 广告未就绪，降级到 fallback 倒计时界面
		print("[AdOverlay] AdMob ad not ready, using fallback countdown")
		_show_fallback_ad()


func _show_fallback_ad() -> void:
	_remaining_time = randf_range(15.0, 30.0)
	_is_showing = true
	_is_using_fallback = true
	_overlay.visible = true
	_close_btn.disabled = true
	_update_countdown_text()


func process(delta: float) -> void:
	# 只在使用 fallback 界面时才需要倒计时
	if not _is_showing or not _is_using_fallback:
		return

	_remaining_time -= delta
	if _remaining_time <= 0.0:
		_remaining_time = 0.0
		_close_btn.disabled = false

	_update_countdown_text()


func _update_countdown_text() -> void:
	var seconds := int(ceil(_remaining_time))
	if seconds > 0:
		_countdown_label.text = Locale.tr_key("ad_countdown") % seconds
	else:
		_countdown_label.text = Locale.tr_key("ad_can_close")


func _on_close_pressed() -> void:
	_is_showing = false
	_is_using_fallback = false
	_overlay.visible = false


func _connect_admob_signals() -> void:
	AdMobManager.ad_closed.connect(_on_admob_ad_closed)
	AdMobManager.ad_failed_to_show.connect(_on_admob_ad_failed)


func _on_admob_ad_closed() -> void:
	print("[AdOverlay] AdMob ad closed by user")
	_is_showing = false
	_is_using_fallback = false


func _on_admob_ad_failed(error_message: String) -> void:
	print("[AdOverlay] AdMob ad failed to show: ", error_message, " - falling back to countdown")
	_show_fallback_ad()
