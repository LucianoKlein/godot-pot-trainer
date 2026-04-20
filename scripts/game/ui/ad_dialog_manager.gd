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

# 构造函数
func _init(parent: Control) -> void:
	_parent = parent

# 显示广告提示弹窗
func show_ad_dialog(dismiss_callback: Callable = Callable()) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	panel_style.border_color = Color(0.82, 0.66, 0.26)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# X 关闭按钮（右对齐，在弹窗顶部）
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(close_row)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color(0.70, 0.60, 0.35))
	close_btn.add_theme_color_override("font_hover_color", Color(0.95, 0.85, 0.55))
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		overlay.queue_free()
		if dismiss_callback.is_valid():
			dismiss_callback.call()
	)
	close_row.add_child(close_btn)

	var title := Label.new()
	title.text = _t("Watch Ad to Continue", "观看广告继续")
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = _t("You've completed 3 questions!\nWatch an ad to unlock 3 more.", "你已完成 3 题！\n观看一次广告解锁 3 题。")
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color(0.88, 0.74, 0.30))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var watch_btn := Button.new()
	watch_btn.text = _t("▶ Watch Ad (15-20s)", "▶ 观看广告 (15-20秒)")
	watch_btn.custom_minimum_size = Vector2(0, 60)
	watch_btn.add_theme_font_size_override("font_size", 26)
	watch_btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.08, 0.08, 0.10, 0.82)
	btn_style.border_color = Color(0.25, 0.55, 0.30)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(12)
	watch_btn.add_theme_stylebox_override("normal", btn_style)
	watch_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		overlay.queue_free()
		load_and_show_ad()
	)
	vbox.add_child(watch_btn)

	# Debug 包：显示跳过按钮，点击直接算看完广告
	if OS.is_debug_build():
		var skip_btn := Button.new()
		skip_btn.text = _t("[DEBUG] Skip Ad", "[测试] 跳过广告")
		skip_btn.custom_minimum_size = Vector2(0, 60)
		skip_btn.add_theme_font_size_override("font_size", 26)
		skip_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
		var skip_style := StyleBoxFlat.new()
		skip_style.bg_color = Color(0.25, 0.15, 0.08, 0.90)
		skip_style.border_color = Color(0.82, 0.66, 0.26)
		skip_style.set_border_width_all(2)
		skip_style.set_corner_radius_all(8)
		skip_style.set_content_margin_all(12)
		skip_btn.add_theme_stylebox_override("normal", skip_style)
		var skip_hover := StyleBoxFlat.new()
		skip_hover.bg_color = Color(0.35, 0.22, 0.10, 0.90)
		skip_hover.border_color = Color(0.95, 0.80, 0.35)
		skip_hover.set_border_width_all(2)
		skip_hover.set_corner_radius_all(8)
		skip_hover.set_content_margin_all(12)
		skip_btn.add_theme_stylebox_override("hover", skip_hover)
		skip_btn.pressed.connect(func() -> void:
			_play_sfx("res://assets/music/sounds_effect/button.ogg")
			overlay.queue_free()
			on_ad_completed()
		)
		vbox.add_child(skip_btn)

	_parent.add_child(overlay)

# 加载并显示广告
func load_and_show_ad() -> void:
	if not AdMobManager.is_available():
		show_ad_unavailable_dialog()
		return

	# 显示加载提示
	show_loading_ad_dialog()

	# 加载广告
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
func show_ad_unavailable_dialog() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -100
	panel.offset_bottom = 100
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	panel_style.border_color = Color(0.82, 0.66, 0.26)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var msg := Label.new()
	msg.text = _t("Ad not available.\nPlease try again later.", "广告暂不可用。\n请稍后再试。")
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color(0.88, 0.74, 0.30))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

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

# 显示广告奖励弹窗
func show_ad_reward_dialog() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -120
	panel.offset_bottom = 120
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	panel_style.border_color = Color(0.25, 0.75, 0.35)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = _t("✓ Reward Unlocked!", "✓ 奖励已解锁！")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var reward_msg := Label.new()
	reward_msg.text = _t("You've unlocked 3 more questions!\nKeep playing.", "已解锁 3 题！\n继续答题吧。")
	reward_msg.add_theme_font_size_override("font_size", 22)
	reward_msg.add_theme_color_override("font_color", Color(0.88, 0.74, 0.30))
	reward_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(reward_msg)

	var continue_btn := Button.new()
	continue_btn.text = _t("Continue", "继续")
	continue_btn.custom_minimum_size = Vector2(0, 54)
	continue_btn.add_theme_font_size_override("font_size", 26)
	continue_btn.pressed.connect(func() -> void:
		_play_sfx("res://assets/music/sounds_effect/button.ogg")
		overlay.queue_free()
	)
	vbox.add_child(continue_btn)

	_parent.add_child(overlay)

# 广告观看完成回调
func on_ad_completed() -> void:
	GuestModeManager.on_guest_ad_watched()
	remove_loading_overlay()
	show_ad_reward_dialog()

# 广告关闭回调（无论是否完成）
func on_ad_closed() -> void:
	remove_loading_overlay()

# 广告加载成功，自动显示
func on_ad_loaded() -> void:
	remove_loading_overlay()
	if AdMobManager.is_ad_ready():
		AdMobManager.show_rewarded_ad()

# 广告加载失败
func on_ad_failed_to_load(error: String) -> void:
	print("[AdDialogManager] Ad failed to load: ", error)
	remove_loading_overlay()
	show_ad_unavailable_dialog()
