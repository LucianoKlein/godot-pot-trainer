class_name LayoutPanelUI
extends RefCounted
## LayoutPanelUI — 布局编辑器面板 UI 管理

signal save_requested
signal reset_requested
signal collapse_toggled(collapsed: bool)
signal display_mode_changed(mode: String)
signal blinds_mode_changed(mode: String)

var _parent: Control
var _layout_panel: PanelContainer
var _layout_panel_content: VBoxContainer
var _scroll_container: ScrollContainer
var _layout_panel_collapsed: bool = false
var _collapse_btn: Button
var _dragging_panel: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _slider_builder: LayoutSliderBuilder


func setup(parent: Control) -> RefCounted:
	_parent = parent
	return self


func build() -> PanelContainer:
	_layout_panel = PanelContainer.new()
	_layout_panel.name = "LayoutPanel"
	_layout_panel.add_theme_stylebox_override("panel", UiFactory.make_stylebox(Color(0.1, 0.1, 0.18, 0.92), 8, 12))
	_layout_panel.z_index = 200
	_layout_panel.visible = false
	_layout_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_panel.custom_minimum_size = Vector2(400, 0)
	_parent.add_child(_layout_panel)
	var vp_size := _parent.get_viewport_rect().size
	_layout_panel.position = Vector2(vp_size.x - 520, vp_size.y * 0.15)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_layout_panel.add_child(vbox)

	_build_title_bar(vbox)

	_scroll_container = ScrollContainer.new()
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll_container.custom_minimum_size = Vector2(0, 650)
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll_container)

	_layout_panel_content = VBoxContainer.new()
	_layout_panel_content.add_theme_constant_override("separation", 8)
	_layout_panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_layout_panel_content)

	return _layout_panel


func _build_title_bar(parent: VBoxContainer) -> void:
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(340, 58)
	title_bar.add_theme_constant_override("separation", 6)
	title_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(title_bar)

	var drag_area := Control.new()
	drag_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drag_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_area.gui_input.connect(_on_title_input)
	title_bar.add_child(drag_area)

	var drag_hint_text := "↕ " + ("可拖动此面板" if GameManager.language == "zh" else "Drag to move")
	var title := UiFactory.make_label(drag_hint_text, 24, Color(0.65, 0.58, 0.42, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_area.add_child(title)

	_collapse_btn = Button.new()
	_collapse_btn.text = "▲"
	_collapse_btn.custom_minimum_size = Vector2(60, 58)
	_collapse_btn.add_theme_font_size_override("font_size", 28)
	_collapse_btn.pressed.connect(_on_collapse_pressed)
	title_bar.add_child(_collapse_btn)


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_panel = mb.pressed
			if mb.pressed:
				_drag_offset = _layout_panel.position - mb.global_position
	elif event is InputEventMouseMotion and _dragging_panel:
		_layout_panel.position = (event as InputEventMouseMotion).global_position + _drag_offset


func _on_collapse_pressed() -> void:
	_layout_panel_collapsed = not _layout_panel_collapsed
	_scroll_container.visible = not _layout_panel_collapsed
	_collapse_btn.text = "▼" if _layout_panel_collapsed else "▲"
	collapse_toggled.emit(_layout_panel_collapsed)
	_layout_panel.reset_size()


func get_content_container() -> VBoxContainer:
	return _layout_panel_content


func set_visible(visible: bool) -> void:
	if _layout_panel:
		_layout_panel.visible = visible


func build_sliders(visibility_manager: RefCounted) -> void:
	_slider_builder = LayoutSliderBuilder.new()
	_slider_builder.build_sliders(_layout_panel_content, visibility_manager)
	_slider_builder.display_mode_changed.connect(func(mode: String) -> void: display_mode_changed.emit(mode))
	_slider_builder.blinds_mode_changed.connect(func(mode: String) -> void: blinds_mode_changed.emit(mode))


func build_action_buttons() -> void:
	_layout_panel_content.add_child(UiFactory.make_layout_btn(Locale.tr_key("save_to_file"), Color(0.25, 0.55, 0.30), func() -> void: save_requested.emit()))
	_layout_panel_content.add_child(UiFactory.make_layout_btn(Locale.tr_key("reset_layout"), Color(0.55, 0.25, 0.15), func() -> void: reset_requested.emit()))


func sync_sliders() -> void:
	if _slider_builder:
		_slider_builder.sync_sliders()


func get_active_chip_slider() -> HSlider:
	if _slider_builder:
		return _slider_builder.get_active_chip_slider()
	return null


func build_back_button(back_to_menu_callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = Locale.tr_key("back_to_menu")
	btn.custom_minimum_size = Vector2(280, 60)
	btn.z_index = 200
	btn.visible = false
	btn.add_theme_stylebox_override("normal", UiFactory.make_stylebox(UiFactory.LAYOUT_BG, 8, 8, Color(0.7, 0.2, 0.2), 1))
	btn.add_theme_stylebox_override("hover", UiFactory.make_stylebox(Color(0.15, 0.15, 0.25, 0.85), 8, 8, Color(0.7, 0.2, 0.2).lightened(0.15), 1))
	btn.add_theme_stylebox_override("pressed", UiFactory.make_stylebox(Color(0.15, 0.15, 0.25, 0.85), 8, 8, Color(0.7, 0.2, 0.2).lightened(0.15), 1))
	btn.add_theme_color_override("font_color", UiFactory.LAYOUT_FONT)
	btn.add_theme_font_size_override("font_size", 28)
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn.offset_left = 16
	btn.offset_top = 8
	btn.pressed.connect(back_to_menu_callback)
	_parent.add_child(btn)
	return btn


func get_display_mode() -> String:
	if _slider_builder:
		return _slider_builder.get_display_mode()
	return "numbers"
