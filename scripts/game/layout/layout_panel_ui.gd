class_name LayoutPanelUI
extends RefCounted
## LayoutPanelUI — 布局编辑器面板 UI 管理
## 管理布局面板的构建、滑块、按钮等 UI 元素

signal save_requested
signal reset_requested
signal collapse_toggled(collapsed: bool)
signal title_drag_started(offset: Vector2)
signal title_dragging(new_position: Vector2)
signal display_mode_changed(mode: String)  # "numbers" or "chips"

var _parent: Control
var _layout_panel: PanelContainer
var _layout_panel_content: VBoxContainer
var _scroll_container: ScrollContainer
var _layout_panel_collapsed: bool = false
var _collapse_btn: Button
var _dragging_panel: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# Slider references
var _dealer_scale_slider: HSlider
var _hole_card_scale_slider: HSlider
var _hole_card_gap_slider: HSlider
var _community_card_scale_slider: HSlider
var _bet_label_scale_slider: HSlider
var _stack_label_scale_slider: HSlider
var _answer_box_scale_slider: HSlider
var _action_box_scale_slider: HSlider
var _player_chip_scale_slider: HSlider
var _bet_chip_scale_slider: HSlider
var _bet_chip_spread_slider: HSlider
var _pot_chip_scale_slider: HSlider
var _chip_record_scale_slider: HSlider
var _ordered_bet_chip_scale_slider: HSlider

# Display mode: "numbers" shows labels, "chips" shows chip UI
var _display_mode: String = "numbers"
var _mode_numbers_btn: Button
var _mode_chips_btn: Button

# Rows grouped by display mode (to show/hide)
var _numbers_rows: Array[Control] = []  # bet_label, stack_label, pot_display rows
var _chips_rows: Array[Control] = []    # player_chips, bet_chips, pot_chips rows


func setup(parent: Control) -> RefCounted:
	_parent = parent
	return self


func build() -> PanelContainer:
	_layout_panel = PanelContainer.new()
	_layout_panel.name = "LayoutPanel"
	var lp_style := StyleBoxFlat.new()
	lp_style.bg_color = Color(0.1, 0.1, 0.18, 0.92)
	lp_style.set_corner_radius_all(8)
	lp_style.set_content_margin_all(12)
	_layout_panel.add_theme_stylebox_override("panel", lp_style)
	_layout_panel.z_index = 200
	_layout_panel.visible = false
	_layout_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_parent.add_child(_layout_panel)
	_layout_panel.position = Vector2(50, 50)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_layout_panel.add_child(vbox)

	# Build title bar with collapse button
	_build_title_bar(vbox)

	# ScrollContainer wrapping content for vertical scrolling
	_scroll_container = ScrollContainer.new()
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll_container.custom_minimum_size = Vector2(0, 400)
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll_container)

	# Content container (can be hidden)
	_layout_panel_content = VBoxContainer.new()
	_layout_panel_content.add_theme_constant_override("separation", 8)
	_layout_panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_layout_panel_content)

	return _layout_panel


func _build_title_bar(parent: VBoxContainer) -> void:
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 58)
	title_bar.add_theme_constant_override("separation", 6)
	title_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(title_bar)

	# Drag area (takes most space)
	var drag_area := Control.new()
	drag_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drag_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_area.gui_input.connect(_on_title_input)
	title_bar.add_child(drag_area)

	var title := Label.new()
	title.text = Locale.tr_key("layout_editor_title")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_area.add_child(title)

	# Collapse button
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
			if mb.pressed:
				_dragging_panel = true
				_drag_offset = _layout_panel.position - mb.global_position
			else:
				_dragging_panel = false
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
	var parent: VBoxContainer = _layout_panel_content

	# Dealer button scale
	_dealer_scale_slider = _make_scale_row(parent, Locale.tr_key("dealer_button_label"), "dealer_buttons", 0.5, 3.0,
		GameManager.layout_config.get("dealer_button_scale", 1.0),
		func(v: float) -> void: GameManager.set_dealer_button_scale(v), [], visibility_manager)

	# Hole card scale
	_hole_card_scale_slider = _make_scale_row(parent, Locale.tr_key("hole_cards_label"), "hole_cards", 0.3, 3.0,
		GameManager.layout_config.get("hole_card_scale", 1.0),
		func(v: float) -> void: GameManager.set_hole_card_scale(v), [], visibility_manager)

	# Hole card gap
	_hole_card_gap_slider = _make_scale_row(parent, Locale.tr_key("hole_card_gap_label"), "", 0.0, 1.5,
		GameManager.layout_config.get("hole_card_gap", 0.6),
		func(v: float) -> void: GameManager.set_hole_card_gap(v), [], visibility_manager)

	# Community card scale
	_community_card_scale_slider = _make_scale_row(parent, Locale.tr_key("community_cards_label"), "community_cards", 0.3, 3.0,
		GameManager.layout_config.get("community_card_scale", 1.0),
		func(v: float) -> void: GameManager.set_community_card_scale(v), [], visibility_manager)

	# --- Display mode toggle (数字 / 筹码) ---
	_build_display_mode_toggle(parent)

	# --- Numbers mode rows (bet label, stack label, pot display) ---
	var bet_row_start: int = parent.get_child_count()
	_bet_label_scale_slider = _make_scale_row(parent, Locale.tr_key("bet_label_label"), "bet_labels", 0.5, 3.0,
		GameManager.layout_config.get("bet_label_scale", 1.0),
		func(v: float) -> void: GameManager.set_bet_label_scale(v), [], visibility_manager)
	_numbers_rows.append(parent.get_child(bet_row_start))

	var stack_row_start: int = parent.get_child_count()
	_stack_label_scale_slider = _make_scale_row(parent, Locale.tr_key("stack_label_label"), "stack_labels", 0.5, 3.0,
		GameManager.layout_config.get("stack_label_scale", 1.0),
		func(v: float) -> void: GameManager.set_stack_label_scale(v), [], visibility_manager)
	_numbers_rows.append(parent.get_child(stack_row_start))

	var pot_disp_row_start: int = parent.get_child_count()
	_make_scale_row(parent, Locale.tr_key("pot_display_label"), "pot_display", 0.5, 3.0, 1.0,
		func(_v: float) -> void: pass, [], visibility_manager)
	_numbers_rows.append(parent.get_child(pot_disp_row_start))

	# --- Chips mode rows (player chips, bet chips, pot chips) ---
	var player_chip_row_start: int = parent.get_child_count()
	_player_chip_scale_slider = _make_scale_row(parent, Locale.tr_key("player_chips_label"), "player_chips", 0.3, 3.0,
		GameManager.layout_config.get("player_chip_scale", 1.0),
		func(v: float) -> void: GameManager.set_player_chip_scale(v), [], visibility_manager)
	_chips_rows.append(parent.get_child(player_chip_row_start))

	var bet_chip_row_start: int = parent.get_child_count()
	_bet_chip_scale_slider = _make_scale_row(parent, Locale.tr_key("bet_chips_label"), "bet_chips", 0.3, 3.0,
		GameManager.layout_config.get("bet_chip_scale", 1.0),
		func(v: float) -> void: GameManager.set_bet_chip_scale(v), [], visibility_manager)
	_chips_rows.append(parent.get_child(bet_chip_row_start))

	var bet_chip_spread_start: int = parent.get_child_count()
	_bet_chip_spread_slider = _make_scale_row(parent, Locale.tr_key("bet_spread_label"), "", 0.5, 3.0,
		GameManager.layout_config.get("bet_chip_spread", 1.0),
		func(v: float) -> void: GameManager.set_bet_chip_spread(v), [], visibility_manager)
	_chips_rows.append(parent.get_child(bet_chip_spread_start))

	var pot_chip_row_start: int = parent.get_child_count()
	_pot_chip_scale_slider = _make_scale_row(parent, Locale.tr_key("pot_chips_label"), "pot_chips", 0.3, 3.0,
		GameManager.layout_config.get("pot_chip_scale", 1.0),
		func(v: float) -> void: GameManager.set_pot_chip_scale(v), [], visibility_manager)
	_chips_rows.append(parent.get_child(pot_chip_row_start))

	var chip_record_row_start: int = parent.get_child_count()
	_chip_record_scale_slider = _make_scale_row(parent, Locale.tr_key("chip_record_label"), "chip_record", 0.3, 3.0,
		GameManager.layout_config.get("chip_record_scale", 1.0),
		func(v: float) -> void: GameManager.set_chip_record_scale(v), [], visibility_manager)
	_chips_rows.append(parent.get_child(chip_record_row_start))

	var ordered_bet_chip_row_start: int = parent.get_child_count()
	_ordered_bet_chip_scale_slider = _make_scale_row(parent, Locale.tr_key("ordered_chips_label"), "ordered_bet_chips", 0.3, 3.0,
		GameManager.layout_config.get("ordered_bet_chip_scale", 1.0),
		func(v: float) -> void: GameManager.set_ordered_bet_chip_scale(v), [], visibility_manager)
	_chips_rows.append(parent.get_child(ordered_bet_chip_row_start))

	# Answer box scale
	_answer_box_scale_slider = _make_scale_row(parent, Locale.tr_key("answer_box_label"), "answer_boxes", 0.5, 3.0,
		GameManager.layout_config.get("answer_box_scale", 1.0),
		func(v: float) -> void: GameManager.set_answer_box_scale(v), [], visibility_manager)

	# Action box scale
	_action_box_scale_slider = _make_scale_row(parent, Locale.tr_key("action_box_label"), "action_boxes", 0.5, 3.0,
		GameManager.layout_config.get("action_box_scale", 1.0),
		func(v: float) -> void: GameManager.set_action_box_scale(v), [], visibility_manager)

	# Apply initial mode visibility
	_apply_display_mode()


func build_action_buttons() -> void:
	var parent: VBoxContainer = _layout_panel_content

	# Save button
	var save_btn := _make_btn(Locale.tr_key("save_to_file"), Color(0.25, 0.55, 0.30), func() -> void: save_requested.emit())
	parent.add_child(save_btn)

	# Reset button
	var reset_btn := _make_btn(Locale.tr_key("reset_layout"), Color(0.55, 0.25, 0.15), func() -> void: reset_requested.emit())
	parent.add_child(reset_btn)


func sync_sliders() -> void:
	_dealer_scale_slider.value = GameManager.layout_config.get("dealer_button_scale", 1.0)
	_hole_card_scale_slider.value = GameManager.layout_config.get("hole_card_scale", 1.0)
	_hole_card_gap_slider.value = GameManager.layout_config.get("hole_card_gap", 0.6)
	_community_card_scale_slider.value = GameManager.layout_config.get("community_card_scale", 1.0)
	_bet_label_scale_slider.value = GameManager.layout_config.get("bet_label_scale", 1.0)
	_stack_label_scale_slider.value = GameManager.layout_config.get("stack_label_scale", 1.0)
	_answer_box_scale_slider.value = GameManager.layout_config.get("answer_box_scale", 1.0)
	_action_box_scale_slider.value = GameManager.layout_config.get("action_box_scale", 1.0)
	_player_chip_scale_slider.value = GameManager.layout_config.get("player_chip_scale", 1.0)
	_bet_chip_scale_slider.value = GameManager.layout_config.get("bet_chip_scale", 1.0)
	_bet_chip_spread_slider.value = GameManager.layout_config.get("bet_chip_spread", 1.0)
	_pot_chip_scale_slider.value = GameManager.layout_config.get("pot_chip_scale", 1.0)
	_chip_record_scale_slider.value = GameManager.layout_config.get("chip_record_scale", 1.0)
	_ordered_bet_chip_scale_slider.value = GameManager.layout_config.get("ordered_bet_chip_scale", 1.0)
	# Sync display mode from GameManager
	_display_mode = GameManager.display_mode
	_apply_display_mode()
	_update_mode_button_styles()


func get_active_chip_slider() -> HSlider:
	# Priority: player_chips > bet_chips > pot_chips
	return _player_chip_scale_slider


func build_back_button(back_to_menu_callback: Callable) -> Button:
	var layout_back_btn := Button.new()
	layout_back_btn.text = Locale.tr_key("back_to_menu")
	layout_back_btn.custom_minimum_size = Vector2(280, 60)
	layout_back_btn.z_index = 200
	layout_back_btn.visible = false
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.1, 0.1, 0.18, 0.82)
	back_style.border_color = Color(0.7, 0.2, 0.2)
	back_style.set_border_width_all(1)
	back_style.set_corner_radius_all(8)
	back_style.set_content_margin_all(8)
	layout_back_btn.add_theme_stylebox_override("normal", back_style)
	var back_hover := StyleBoxFlat.new()
	back_hover.bg_color = Color(0.15, 0.15, 0.25, 0.85)
	back_hover.border_color = Color(0.7, 0.2, 0.2).lightened(0.15)
	back_hover.set_border_width_all(1)
	back_hover.set_corner_radius_all(8)
	back_hover.set_content_margin_all(8)
	layout_back_btn.add_theme_stylebox_override("hover", back_hover)
	layout_back_btn.add_theme_stylebox_override("pressed", back_hover)
	layout_back_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	layout_back_btn.add_theme_font_size_override("font_size", 28)
	layout_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	layout_back_btn.offset_left = 16
	layout_back_btn.offset_top = 8
	layout_back_btn.pressed.connect(back_to_menu_callback)
	_parent.add_child(layout_back_btn)
	return layout_back_btn


func get_display_mode() -> String:
	return _display_mode


func _build_display_mode_toggle(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	parent.add_child(sep)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = Locale.tr_key("display_mode_toggle")
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(lbl)

	_mode_numbers_btn = Button.new()
	_mode_numbers_btn.text = Locale.tr_key("numbers_mode")
	_mode_numbers_btn.custom_minimum_size = Vector2(120, 50)
	_mode_numbers_btn.add_theme_font_size_override("font_size", 28)
	_mode_numbers_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	_mode_numbers_btn.pressed.connect(func() -> void: _set_display_mode("numbers"))
	row.add_child(_mode_numbers_btn)

	_mode_chips_btn = Button.new()
	_mode_chips_btn.text = Locale.tr_key("chips_mode")
	_mode_chips_btn.custom_minimum_size = Vector2(120, 50)
	_mode_chips_btn.add_theme_font_size_override("font_size", 28)
	_mode_chips_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	_mode_chips_btn.pressed.connect(func() -> void: _set_display_mode("chips"))
	row.add_child(_mode_chips_btn)

	_update_mode_button_styles()


func _set_display_mode(mode: String) -> void:
	if _display_mode == mode:
		return
	_display_mode = mode
	_apply_display_mode()
	_update_mode_button_styles()
	display_mode_changed.emit(_display_mode)


func _apply_display_mode() -> void:
	var is_numbers: bool = _display_mode == "numbers"
	for row in _numbers_rows:
		row.visible = is_numbers
	for row in _chips_rows:
		row.visible = not is_numbers


func _update_mode_button_styles() -> void:
	var active_color: Color = Color(0.3, 0.3, 0.5, 0.9)
	var inactive_color: Color = Color(0.1, 0.1, 0.18, 0.85)

	var active_style := StyleBoxFlat.new()
	active_style.bg_color = active_color
	active_style.set_corner_radius_all(8)
	active_style.set_content_margin_all(6)

	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = inactive_color
	inactive_style.set_corner_radius_all(8)
	inactive_style.set_content_margin_all(6)

	var hover_active := StyleBoxFlat.new()
	hover_active.bg_color = active_color.lightened(0.1)
	hover_active.set_corner_radius_all(8)
	hover_active.set_content_margin_all(6)

	var hover_inactive := StyleBoxFlat.new()
	hover_inactive.bg_color = Color(0.15, 0.15, 0.25, 0.85)
	hover_inactive.set_corner_radius_all(8)
	hover_inactive.set_content_margin_all(6)

	if _display_mode == "numbers":
		_mode_numbers_btn.add_theme_stylebox_override("normal", active_style)
		_mode_numbers_btn.add_theme_stylebox_override("hover", hover_active)
		_mode_numbers_btn.add_theme_stylebox_override("pressed", hover_active)
		_mode_chips_btn.add_theme_stylebox_override("normal", inactive_style)
		_mode_chips_btn.add_theme_stylebox_override("hover", hover_inactive)
		_mode_chips_btn.add_theme_stylebox_override("pressed", hover_inactive)
	else:
		_mode_chips_btn.add_theme_stylebox_override("normal", active_style)
		_mode_chips_btn.add_theme_stylebox_override("hover", hover_active)
		_mode_chips_btn.add_theme_stylebox_override("pressed", hover_active)
		_mode_numbers_btn.add_theme_stylebox_override("normal", inactive_style)
		_mode_numbers_btn.add_theme_stylebox_override("hover", hover_inactive)
		_mode_numbers_btn.add_theme_stylebox_override("pressed", hover_inactive)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_btn(text: String, color: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 44
	btn.add_theme_font_size_override("font_size", 28)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.18, 0.82)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.15, 0.15, 0.25, 0.85)
	hover.border_color = color.lightened(0.15)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(8)
	hover.set_content_margin_all(10)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	btn.pressed.connect(callback)
	return btn


func _make_scale_row(parent: VBoxContainer, label_text: String, element_key: String, min_val: float, max_val: float, initial: float, callback: Callable, _snap_points: Array = [], visibility_manager: RefCounted = null) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	# Checkbox (if element_key is provided and visibility_manager exists)
	if element_key != "" and visibility_manager:
		var checkbox: CheckBox = visibility_manager.create_element_checkbox(element_key)
		row.add_child(checkbox)

	var lbl := _make_label(label_text, 28, Color(0.7, 0.7, 0.7))
	lbl.custom_minimum_size.x = 160 if element_key == "" else 120
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(300, 50)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.3, 0.7, 1.0)
	grabber_style.set_corner_radius_all(18)
	grabber_style.content_margin_left = 18
	grabber_style.content_margin_right = 18
	grabber_style.content_margin_top = 18
	grabber_style.content_margin_bottom = 18
	slider.add_theme_stylebox_override("grabber_area", grabber_style)
	var grabber_hl := StyleBoxFlat.new()
	grabber_hl.bg_color = Color(0.4, 0.8, 1.0)
	grabber_hl.set_corner_radius_all(18)
	grabber_hl.content_margin_left = 18
	grabber_hl.content_margin_right = 18
	grabber_hl.content_margin_top = 18
	grabber_hl.content_margin_bottom = 18
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_hl)
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return slider
