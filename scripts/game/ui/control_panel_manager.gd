class_name ControlPanelManager
extends RefCounted
## ControlPanelManager — 控制面板管理器
## 底部浮动面板：主行(按钮) + 可展开配置行(select)

signal start_pressed
signal pause_pressed
signal reset_pressed
signal player_count_changed(count: int)
signal blinds_changed(sb: int, bb: int)
signal preset_changed(preset: int)
signal mode_changed(mode: String)
signal display_mode_changed(mode: String)
signal dealer_changed(index: int)

var parent: Control
var control_panel: PanelContainer

# UI 节点
var start_btn: Button
var pause_btn: Button
var reset_btn: Button
var blinds_option: OptionButton
var preset_option: OptionButton
var player_count_option: OptionButton
var mode_option: OptionButton
var dealer_option: OptionButton
var layout_btn: Button
var _display_mode_option: OptionButton

# 展开/收起
var _config_row: HBoxContainer
var _toggle_btn: Button
var _expanded: bool = false


func _init(p: Control) -> void:
	parent = p


func build(back_to_menu_callback: Callable) -> void:
	control_panel = PanelContainer.new()
	control_panel.name = "ControlPanel"
	control_panel.z_index = 200
	control_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	control_panel.set_anchors_preset(7) # PRESET_BOTTOM_CENTER
	control_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	control_panel.offset_left = 0
	control_panel.offset_top = -16
	control_panel.offset_right = 0
	control_panel.offset_bottom = -16
	var cp_sb := StyleBoxFlat.new()
	cp_sb.bg_color = Color(0.08, 0.08, 0.10, 0.82)
	cp_sb.border_color = Color(0.50, 0.40, 0.16)
	cp_sb.set_border_width_all(1)
	cp_sb.set_corner_radius_all(6)
	cp_sb.set_content_margin_all(12)
	control_panel.add_theme_stylebox_override("panel", cp_sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	control_panel.add_child(vbox)

	# ── 配置行（默认隐藏） ──
	_config_row = HBoxContainer.new()
	_config_row.name = "ConfigRow"
	_config_row.add_theme_constant_override("separation", 14)
	_config_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_config_row.visible = false
	vbox.add_child(_config_row)

	_build_config_row()

	# ── 主行（按钮，始终可见） ──
	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 10)
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(main_row)

	_build_main_row(main_row, back_to_menu_callback)

	parent.add_child(control_panel)


# ============================================================================
# 配置行：4个 select（人数、盲注、牌桌、模式）
# ============================================================================

func _build_config_row() -> void:
	# 人数
	var pc_group := _make_option_group("人数:")
	player_count_option = _make_styled_option()
	for n in range(2, 10):
		player_count_option.add_item("%d" % n, n)
	player_count_option.selected = 6
	player_count_option.item_selected.connect(func(index: int) -> void:
		player_count_changed.emit(index + 2)
	)
	_style_popup(player_count_option)
	pc_group.add_child(player_count_option)
	_config_row.add_child(pc_group)

	# 盲注
	var bl_group := _make_option_group("盲注:")
	blinds_option = _make_styled_option()
	for pair in GameManager.POT_BLINDS:
		blinds_option.add_item("%d/%d" % [pair[0], pair[1]])
	blinds_option.selected = 0
	blinds_option.item_selected.connect(func(index: int) -> void:
		var pair: Array = GameManager.POT_BLINDS[index]
		blinds_changed.emit(pair[0], pair[1])
	)
	bl_group.add_child(blinds_option)
	_config_row.add_child(bl_group)

	# 牌桌
	var tp_group := _make_option_group("牌桌:")
	preset_option = _make_styled_option()
	for key in TablePresets.PRESET_NAMES:
		preset_option.add_item(TablePresets.PRESET_NAMES[key], key)
	preset_option.selected = 0
	preset_option.item_selected.connect(func(index: int) -> void:
		preset_changed.emit(index)
	)
	tp_group.add_child(preset_option)
	_config_row.add_child(tp_group)

	# 模式
	var mo_group := _make_option_group("模式:")
	mode_option = _make_styled_option()
	mode_option.add_item("场景模式")
	mode_option.add_item("游戏模式")
	mode_option.selected = 0
	mode_option.item_selected.connect(func(index: int) -> void:
		var mode := "scenario" if index == 0 else "game"
		mode_changed.emit(mode)
	)
	mo_group.add_child(mode_option)
	_config_row.add_child(mo_group)

	# 庄家
	var dl_group := _make_option_group("庄家:")
	dealer_option = _make_styled_option()
	_rebuild_dealer_options()
	dealer_option.item_selected.connect(func(index: int) -> void:
		dealer_changed.emit(index)
	)
	dl_group.add_child(dealer_option)
	_config_row.add_child(dl_group)

	# 展示模式
	var dm_group := _make_option_group("展示模式:")
	_display_mode_option = _make_styled_option()
	_display_mode_option.add_item("筹码", 0)
	_display_mode_option.add_item("数字", 1)
	_display_mode_option.selected = 0 if GameManager.display_mode == "chips" else 1
	_display_mode_option.item_selected.connect(func(index: int) -> void:
		var mode := "chips" if index == 0 else "numbers"
		_set_display_mode(mode)
	)
	dm_group.add_child(_display_mode_option)
	_config_row.add_child(dm_group)


# ============================================================================
# 主行：齿轮按钮 + 操作按钮 + 显示切换 + 返回
# ============================================================================

func _build_main_row(row: HBoxContainer, back_cb: Callable) -> void:
	# 齿轮展开按钮
	_toggle_btn = Button.new()
	_toggle_btn.text = "⚙ 配置 ▲"
	_toggle_btn.custom_minimum_size = Vector2(110, 44)
	_toggle_btn.add_theme_font_size_override("font_size", 20)
	var tg_s := StyleBoxFlat.new()
	tg_s.bg_color = Color(0.08, 0.08, 0.10, 0.82)
	tg_s.border_color = Color(0.50, 0.40, 0.16)
	tg_s.set_border_width_all(1)
	tg_s.set_corner_radius_all(6)
	tg_s.set_content_margin_all(8)
	_toggle_btn.add_theme_stylebox_override("normal", tg_s)
	var tg_h := StyleBoxFlat.new()
	tg_h.bg_color = Color(0.14, 0.13, 0.10, 0.85)
	tg_h.border_color = Color(0.72, 0.58, 0.24)
	tg_h.set_border_width_all(1)
	tg_h.set_corner_radius_all(6)
	tg_h.set_content_margin_all(8)
	_toggle_btn.add_theme_stylebox_override("hover", tg_h)
	_toggle_btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	_toggle_btn.pressed.connect(_on_toggle)
	row.add_child(_toggle_btn)

	row.add_child(VSeparator.new())

	# 操作按钮
	start_btn = _make_action_btn("开始", Color(0.08, 0.08, 0.10, 0.82), Color(0.25, 0.55, 0.30))
	row.add_child(start_btn)
	start_btn.pressed.connect(func() -> void: start_pressed.emit())

	pause_btn = _make_action_btn("暂停", Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16))
	row.add_child(pause_btn)
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())

	reset_btn = _make_action_btn("重置", Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16))
	row.add_child(reset_btn)
	reset_btn.pressed.connect(func() -> void: reset_pressed.emit())

	row.add_child(VSeparator.new())

	# 布局（隐藏）
	layout_btn = _make_action_btn("布局", Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16))
	layout_btn.visible = false
	row.add_child(layout_btn)

	# 返回主菜单
	var back_btn := _make_action_btn("返回主菜单", Color(0.08, 0.08, 0.10, 0.82), Color(0.55, 0.25, 0.15))
	back_btn.custom_minimum_size = Vector2(140, 44)
	row.add_child(back_btn)
	back_btn.pressed.connect(back_cb)


# ============================================================================
# 展开/收起
# ============================================================================

func _on_toggle() -> void:
	_expanded = not _expanded
	_config_row.visible = _expanded
	_toggle_btn.text = "⚙ 配置 ▼" if _expanded else "⚙ 配置 ▲"


# ============================================================================
# 公共方法
# ============================================================================

func set_visible(visible: bool) -> void:
	if control_panel:
		control_panel.visible = visible


func update_dealer_options() -> void:
	_rebuild_dealer_options()


# ============================================================================
# 工具方法
# ============================================================================

func _set_display_mode(mode: String) -> void:
	if GameManager.display_mode == mode:
		return
	display_mode_changed.emit(mode)


func _rebuild_dealer_options() -> void:
	if not dealer_option:
		return
	var prev_selected := dealer_option.selected
	dealer_option.clear()
	var count: int = GameManager.config.player_count
	for i in range(count):
		var physical_seat: int = GameManager.get_physical_seat(i)
		dealer_option.add_item("座位 %d" % (physical_seat + 1), i)
	# Restore selection if still valid
	if prev_selected >= 0 and prev_selected < count:
		dealer_option.selected = prev_selected
	else:
		dealer_option.selected = 0


func _make_action_btn(text: String, bg_color: Color, border_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 44)
	btn.add_theme_font_size_override("font_size", 24)
	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color = bg_color
	s_normal.border_color = border_color
	s_normal.set_border_width_all(1)
	s_normal.set_corner_radius_all(6)
	s_normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", s_normal)
	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color = Color(0.14, 0.13, 0.10, 0.85)
	s_hover.border_color = border_color.lightened(0.15)
	s_hover.set_border_width_all(1)
	s_hover.set_corner_radius_all(6)
	s_hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", s_hover)
	btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	return btn


func _make_option_group(label_text: String) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	group.add_child(lbl)
	return group


func _make_styled_option() -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(110, 44)
	opt.add_theme_font_size_override("font_size", 22)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.10, 0.82)
	s.border_color = Color(0.50, 0.40, 0.16)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8)
	opt.add_theme_stylebox_override("normal", s)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.14, 0.13, 0.10, 0.85)
	h.border_color = Color(0.72, 0.58, 0.24)
	h.set_border_width_all(1)
	h.set_corner_radius_all(6)
	h.set_content_margin_all(8)
	opt.add_theme_stylebox_override("hover", h)
	opt.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	return opt


func _style_popup(opt: OptionButton) -> void:
	var popup := opt.get_popup()
	popup.add_theme_font_size_override("font_size", 28)
	popup.add_theme_constant_override("v_separation", 6)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.10, 0.95)
	ps.border_color = Color(0.50, 0.40, 0.16)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(6)
	ps.set_content_margin_all(10)
	popup.add_theme_stylebox_override("panel", ps)
	var ph := StyleBoxFlat.new()
	ph.bg_color = Color(0.22, 0.17, 0.06)
	ph.set_corner_radius_all(4)
	popup.add_theme_stylebox_override("hover", ph)
	popup.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.35))


func _update_display_mode_styles() -> void:
	if _display_mode_option:
		_display_mode_option.selected = 0 if GameManager.display_mode == "chips" else 1
