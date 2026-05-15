extends RefCounted
class_name AdDialogManager

# 广告弹窗管理器 / Ad Dialog Manager
# 完全照抄 BoardAnalysis，负责所有广告相关的 UI 弹窗逻辑

func _t(en: String, zh: String) -> String:
	return zh if GameManager.language == "zh" else en

func _play_sfx(path: String) -> void:
	var main_node := _parent.get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.call("play_sfx", path)

# 引用
var _parent: Control
var _loading_overlay: Control = null
var _waiting_for_ad := false
var on_gate_dismissed: Callable
var on_ad_unavailable_callback: Callable
var _ad_reward_granted := false

# 构造函数
func _init(parent: Control) -> void:
	_parent = parent

# 加载并显示广告
func load_and_show_ad() -> void:
	if not AdMobManager.is_available():
		show_ad_unavailable_dialog("AdMob not available on " + OS.get_name())
		return
	if AdMobManager.is_ad_ready():
		_waiting_for_ad = false
		AdMobManager.show_rewarded_ad()
		return
	_waiting_for_ad = true
	show_loading_ad_dialog()
	AdMobManager.load_rewarded_ad()

# 显示加载中弹窗
func show_loading_ad_dialog() -> void:
	var overlay := ColorRect.new()
	overlay.name = "AdLoadingOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500

	var label := Label.new()
	label.text = _t("Loading ad...", "广告加载中...")
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -150
	label.offset_right = 150
	label.offset_top = -20
	label.offset_bottom = 20
	overlay.add_child(label)

	_parent.add_child(overlay)
	_loading_overlay = overlay

# 移除加载中遮罩
func remove_loading_overlay() -> void:
	if _loading_overlay:
		_loading_overlay.queue_free()
		_loading_overlay = null

# 显示广告不可用弹窗
func show_ad_unavailable_dialog(error: String = "") -> void:
	DialogQueue.show(func() -> void: _create_ad_unavailable_dialog(error))

func _create_ad_unavailable_dialog(error: String = "") -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -200
	panel.offset_bottom = 200
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	panel_style.border_color = Color(0.82, 0.66, 0.26)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var msg := Label.new()
	msg.text = _t("Ad not available.\nPlease try again later.", "广告暂不可用。\n请稍后再试。")
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color(0.88, 0.74, 0.30))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var debug_info := ""
	if error != "":
		debug_info += "Error: " + error + "\n"
	debug_info += "Platform: " + OS.get_name() + "\n"
	debug_info += "has_singleton: " + str(Engine.has_singleton("GodotAdMob")) + "\n"
	debug_info += "is_available: " + str(AdMobManager.is_available()) + "\n"
	debug_info += "last_error: " + AdMobManager.last_error + "\n"
	var debug_lbl := Label.new()
	debug_lbl.text = debug_info
	debug_lbl.add_theme_font_size_override("font_size", 16)
	debug_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	debug_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(debug_lbl)

	var ok_btn := Button.new()
	ok_btn.text = _t("OK", "确定")
	ok_btn.custom_minimum_size = Vector2(0, 50)
	ok_btn.add_theme_font_size_override("font_size", 24)
	ok_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		overlay.queue_free()
	)
	vbox.add_child(ok_btn)

	_parent.add_child(overlay)
	DialogQueue.register(overlay)

# 显示广告奖励弹窗
func show_ad_reward_dialog() -> void:
	DialogQueue.show(_create_ad_reward_dialog)

func _create_ad_reward_dialog() -> void:
	var overlay := Control.new()
	overlay.name = "AdRewardOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200

	var dimming := ColorRect.new()
	dimming.color = Color(0, 0, 0, 0.7)
	dimming.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dimming)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.10, 0.98)
	ps.set_corner_radius_all(6)
	ps.set_content_margin_all(0)
	ps.border_color = Color(0.50, 0.40, 0.16)
	ps.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	var banner := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.08, 0.08, 0.10, 1.0)
	bs.set_corner_radius_all(0)
	bs.corner_radius_top_left = 6
	bs.corner_radius_top_right = 6
	bs.set_content_margin_all(12)
	banner.add_theme_stylebox_override("panel", bs)
	vbox.add_child(banner)

	var banner_lbl := Label.new()
	banner_lbl.text = _t("✓ Reward Unlocked!  3 questions added", "✓ 奖励已解锁！  已解锁 3 题")
	banner_lbl.add_theme_font_size_override("font_size", 28)
	banner_lbl.add_theme_color_override("font_color", Color(0.25, 0.75, 0.40))
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_lbl)

	var btn_margin := MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_left", 16)
	btn_margin.add_theme_constant_override("margin_right", 16)
	btn_margin.add_theme_constant_override("margin_top", 6)
	btn_margin.add_theme_constant_override("margin_bottom", 12)
	vbox.add_child(btn_margin)

	var btn := Button.new()
	btn.text = _t("→ Continue", "→ 继续答题")
	btn.custom_minimum_size = Vector2(0, 66)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	var bts := StyleBoxFlat.new()
	bts.bg_color = Color(0.08, 0.08, 0.10, 0.82)
	bts.set_corner_radius_all(6)
	bts.set_content_margin_all(12)
	bts.border_color = Color(0.25, 0.55, 0.30)
	bts.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", bts)
	btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		overlay.queue_free()
		if on_gate_dismissed.is_valid():
			on_gate_dismissed.call()
	)
	btn_margin.add_child(btn)

	_parent.add_child(overlay)
	DialogQueue.register(overlay)

func on_ad_completed() -> void:
	_ad_reward_granted = true
	GuestModeManager.on_guest_ad_watched()
	remove_loading_overlay()
	show_ad_reward_dialog()


func on_ad_closed() -> void:
	remove_loading_overlay()
	_ad_reward_granted = false


func on_ad_loaded() -> void:
	remove_loading_overlay()
	if _waiting_for_ad and AdMobManager.is_ad_ready():
		_waiting_for_ad = false
		AdMobManager.show_rewarded_ad()


func on_ad_failed_to_load(error: String) -> void:
	_waiting_for_ad = false
	remove_loading_overlay()
	show_ad_unavailable_dialog("Load failed: " + error)


func on_ad_failed_to_show(error: String) -> void:
	_waiting_for_ad = false
	remove_loading_overlay()
	show_ad_unavailable_dialog("Show failed: " + error)
