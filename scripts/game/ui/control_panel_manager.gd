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
var layout_btn: Button

# 展开/收起
var _config_row: HBoxContainer
var _toggle_btn: Button
var _expanded: bool = false

# 配置行构建器
var _config_builder: ConfigRowBuilder


func setup(p: Control) -> RefCounted:
	parent = p
	return self


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
	control_panel.add_theme_stylebox_override("panel", UiFactory.make_stylebox(
		Color(0.08, 0.08, 0.10, 0.82), 6, 12, Color(0.50, 0.40, 0.16), 1))

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

	_config_builder = ConfigRowBuilder.new()
	_config_builder.build(_config_row)
	_connect_config_signals()

	# ── 主行（按钮，始终可见） ──
	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 10)
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(main_row)

	_build_main_row(main_row, back_to_menu_callback)

	parent.add_child(control_panel)


func _connect_config_signals() -> void:
	_config_builder.player_count_changed.connect(func(c: int) -> void: player_count_changed.emit(c))
	_config_builder.blinds_changed.connect(func(s: int, b: int) -> void: blinds_changed.emit(s, b))
	_config_builder.preset_changed.connect(func(p: int) -> void: preset_changed.emit(p))
	_config_builder.mode_changed.connect(func(m: String) -> void: mode_changed.emit(m))
	_config_builder.display_mode_changed.connect(func(m: String) -> void: display_mode_changed.emit(m))
	_config_builder.dealer_changed.connect(func(i: int) -> void: dealer_changed.emit(i))


# ============================================================================
# 主行：齿轮按钮 + 操作按钮 + 返回
# ============================================================================

func _build_main_row(row: HBoxContainer, back_cb: Callable) -> void:
	# 齿轮展开按钮
	_toggle_btn = Button.new()
	_toggle_btn.text = Locale.tr_key("config_expand")
	_toggle_btn.custom_minimum_size = Vector2(165, 66)
	_toggle_btn.add_theme_font_size_override("font_size", 30)
	_toggle_btn.add_theme_stylebox_override("normal", UiFactory.make_stylebox(
		ControlPanelStyles.BG, 6, 12, ControlPanelStyles.BORDER, 1))
	_toggle_btn.add_theme_stylebox_override("hover", UiFactory.make_stylebox(
		ControlPanelStyles.HOVER_BG, 6, 12, ControlPanelStyles.HOVER_BORDER, 1))
	_toggle_btn.add_theme_color_override("font_color", ControlPanelStyles.GOLD)
	_toggle_btn.pressed.connect(_on_toggle)
	row.add_child(_toggle_btn)

	row.add_child(VSeparator.new())

	# 操作按钮
	start_btn = ControlPanelStyles.make_action_btn(Locale.tr_key("start"), ControlPanelStyles.BG, Color(0.25, 0.55, 0.30))
	row.add_child(start_btn)
	start_btn.pressed.connect(func() -> void: start_pressed.emit())

	pause_btn = ControlPanelStyles.make_action_btn(Locale.tr_key("pause"), ControlPanelStyles.BG, ControlPanelStyles.BORDER)
	row.add_child(pause_btn)
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())

	reset_btn = ControlPanelStyles.make_action_btn(Locale.tr_key("reset"), ControlPanelStyles.BG, ControlPanelStyles.BORDER)
	row.add_child(reset_btn)
	reset_btn.pressed.connect(func() -> void: reset_pressed.emit())

	row.add_child(VSeparator.new())

	# 布局（隐藏）
	layout_btn = ControlPanelStyles.make_action_btn(Locale.tr_key("layout"), ControlPanelStyles.BG, ControlPanelStyles.BORDER)
	layout_btn.visible = false
	row.add_child(layout_btn)

	# 返回主菜单
	var back_btn := ControlPanelStyles.make_action_btn(Locale.tr_key("back_to_menu"), ControlPanelStyles.BG, Color(0.55, 0.25, 0.15))
	back_btn.custom_minimum_size = Vector2(210, 66)
	row.add_child(back_btn)
	back_btn.pressed.connect(back_cb)


# ============================================================================
# 展开/收起
# ============================================================================

func _on_toggle() -> void:
	_expanded = not _expanded
	_config_row.visible = _expanded
	_toggle_btn.text = Locale.tr_key("config_collapse") if _expanded else Locale.tr_key("config_expand")


func collapse_config() -> void:
	if _expanded:
		_expanded = false
		_config_row.visible = false
		_toggle_btn.text = Locale.tr_key("config_expand")


# ============================================================================
# 公共方法
# ============================================================================

func set_visible(visible: bool) -> void:
	if control_panel:
		control_panel.visible = visible


func update_dealer_options() -> void:
	_config_builder.update_dealer_options()


func _update_display_mode_styles() -> void:
	_config_builder.update_display_mode_styles()
