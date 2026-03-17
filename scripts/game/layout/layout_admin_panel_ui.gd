class_name LayoutAdminPanelUI
extends RefCounted
## LayoutAdminPanelUI — 布局编辑器管理员面板
## 仅PC端显示，包含玩家大小、单个玩家大小、玩家旋转、椅子大小、椅子旋转、手牌旋转

signal save_requested
signal reset_requested

var _parent: Control
var _panel: PanelContainer
var _content: VBoxContainer
var _collapsed: bool = false
var _collapse_btn: Button
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# Slider references
var _avatar_scale_slider: HSlider
var _avatar_per_seat_scale_slider: HSlider
var _avatar_per_seat_scale_selector: OptionButton
var _avatar_rotation_slider: HSlider
var _avatar_seat_selector: OptionButton
var _chair_scale_slider: HSlider
var _chair_rotation_slider: HSlider
var _chair_seat_selector: OptionButton
var _hole_card_rotation_slider: HSlider
var _hole_card_rotation_seat_selector: OptionButton


static func is_pc() -> bool:
	return OS.get_name() in ["Windows", "macOS", "Linux"]


func _init(parent: Control) -> void:
	_parent = parent


func build() -> PanelContainer:
	_panel = PanelContainer.new()
	_panel.name = "AdminPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.18, 0.92)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.z_index = 200
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_parent.add_child(_panel)
	_panel.position = Vector2(50, 50)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_build_title_bar(vbox)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	vbox.add_child(_content)

	return _panel


func _build_title_bar(parent_vbox: VBoxContainer) -> void:
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 58)
	title_bar.add_theme_constant_override("separation", 6)
	title_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	parent_vbox.add_child(title_bar)

	var drag_area := Control.new()
	drag_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drag_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_area.gui_input.connect(_on_title_input)
	title_bar.add_child(drag_area)

	var title := Label.new()
	title.text = "管理员面板  (拖动此处)"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
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
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_offset = _panel.position - mb.global_position
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_panel.position = (event as InputEventMouseMotion).global_position + _drag_offset


func _on_collapse_pressed() -> void:
	_collapsed = not _collapsed
	_content.visible = not _collapsed
	_collapse_btn.text = "▼" if _collapsed else "▲"
	_panel.reset_size()


func build_sliders() -> void:
	# Avatar scale
	_avatar_scale_slider = _make_scale_row(_content, "玩家大小", 0.3, 3.0,
		GameManager.layout_config.get("avatar_scale", 1.0),
		func(v: float) -> void: GameManager.set_avatar_scale(v))

	# Avatar per-seat scale
	var per_seat_arr: Array = GameManager.layout_config.get("avatar_per_seat_scale", [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	var per_seat_result := _make_per_seat_scale_row(_content, "单个玩家大小", "avatar_per_seat_scale", per_seat_arr,
		func(seat: int, scale: float) -> void: GameManager.set_avatar_per_seat_scale(seat, scale))
	_avatar_per_seat_scale_slider = per_seat_result["slider"]
	_avatar_per_seat_scale_selector = per_seat_result["selector"]

	# Avatar rotation (per-seat)
	var avatar_rot_arr: Array = GameManager.layout_config.get("avatar_rotation", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var avatar_rot_result := _make_per_seat_rotation_row(_content, "玩家旋转", "avatar_rotation", avatar_rot_arr,
		func(seat: int, deg: float) -> void: GameManager.set_avatar_rotation(seat, deg))
	_avatar_rotation_slider = avatar_rot_result["slider"]
	_avatar_seat_selector = avatar_rot_result["selector"]

	# Chair scale
	_chair_scale_slider = _make_scale_row(_content, "椅子大小", 0.3, 3.0,
		GameManager.layout_config.get("chair_scale", 1.0),
		func(v: float) -> void: GameManager.set_chair_scale(v))

	# Chair rotation (per-seat)
	var chair_rot_arr: Array = GameManager.layout_config.get("chair_rotation", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var chair_rot_result := _make_per_seat_rotation_row(_content, "椅子旋转", "chair_rotation", chair_rot_arr,
		func(seat: int, deg: float) -> void: GameManager.set_chair_rotation(seat, deg))
	_chair_rotation_slider = chair_rot_result["slider"]
	_chair_seat_selector = chair_rot_result["selector"]

	# Hole card rotation (per-seat)
	var hole_rot_arr: Array = GameManager.layout_config.get("hole_card_rotation", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var hole_rot_result := _make_per_seat_rotation_row(_content, "手牌旋转", "hole_card_rotation", hole_rot_arr,
		func(seat: int, deg: float) -> void: GameManager.set_hole_card_rotation(seat, deg))
	_hole_card_rotation_slider = hole_rot_result["slider"]
	_hole_card_rotation_seat_selector = hole_rot_result["selector"]


func build_action_buttons() -> void:
	var save_btn := _make_btn("保存到文件", Color(0.25, 0.55, 0.30), func() -> void: save_requested.emit())
	_content.add_child(save_btn)

	var reset_btn := _make_btn("重置布局", Color(0.55, 0.25, 0.15), func() -> void: reset_requested.emit())
	_content.add_child(reset_btn)


func sync_sliders() -> void:
	_avatar_scale_slider.value = GameManager.layout_config.get("avatar_scale", 1.0)
	_chair_scale_slider.value = GameManager.layout_config.get("chair_scale", 1.0)
	_sync_per_seat_scale_slider(_avatar_per_seat_scale_slider, "avatar_per_seat_scale", _avatar_per_seat_scale_selector.selected)
	_sync_per_seat_rotation_slider(_avatar_rotation_slider, "avatar_rotation", _avatar_seat_selector.selected)
	_sync_per_seat_rotation_slider(_chair_rotation_slider, "chair_rotation", _chair_seat_selector.selected)
	_sync_per_seat_rotation_slider(_hole_card_rotation_slider, "hole_card_rotation", _hole_card_rotation_seat_selector.selected)


func set_visible(visible: bool) -> void:
	if _panel:
		_panel.visible = visible


# =============================================================================
# UI helpers
# =============================================================================

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


func _make_scale_row(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, initial: float, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	var lbl := _make_label(label_text, 28, Color(0.7, 0.7, 0.7))
	lbl.custom_minimum_size.x = 160
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


func _make_per_seat_rotation_row(parent: VBoxContainer, label_text: String, config_key: String, rotation_arr: Array, callback: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	var lbl := _make_label(label_text, 28, Color(0.7, 0.7, 0.7))
	lbl.custom_minimum_size.x = 100
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)

	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(80, 50)
	selector.add_theme_font_size_override("font_size", 32)
	for i in range(9):
		selector.add_item("座%d" % (i + 1), i)
	selector.selected = 0
	row.add_child(selector)
	var sel_popup: PopupMenu = selector.get_popup()
	sel_popup.add_theme_font_size_override("font_size", 32)

	var slider := HSlider.new()
	slider.min_value = -180.0
	slider.max_value = 180.0
	slider.step = 1.0
	slider.value = rotation_arr[0] if rotation_arr.size() > 0 else 0.0
	slider.custom_minimum_size = Vector2(200, 50)
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
	row.add_child(slider)

	slider.value_changed.connect(func(v: float) -> void:
		callback.call(selector.selected, v)
	)

	selector.item_selected.connect(func(idx: int) -> void:
		var arr: Array = GameManager.layout_config.get(config_key, [])
		slider.set_value_no_signal(arr[idx] if idx < arr.size() else 0.0)
	)

	return {"slider": slider, "selector": selector}


func _make_per_seat_scale_row(parent: VBoxContainer, label_text: String, config_key: String, scale_arr: Array, callback: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	var lbl := _make_label(label_text, 28, Color(0.7, 0.7, 0.7))
	lbl.custom_minimum_size.x = 100
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)

	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(80, 50)
	selector.add_theme_font_size_override("font_size", 32)
	for i in range(9):
		selector.add_item("座%d" % (i + 1), i)
	selector.selected = 0
	row.add_child(selector)
	var sel_popup: PopupMenu = selector.get_popup()
	sel_popup.add_theme_font_size_override("font_size", 32)

	var slider := HSlider.new()
	slider.min_value = 0.3
	slider.max_value = 3.0
	slider.step = 0.05
	slider.value = scale_arr[0] if scale_arr.size() > 0 else 1.0
	slider.custom_minimum_size = Vector2(200, 50)
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
	row.add_child(slider)

	slider.value_changed.connect(func(v: float) -> void:
		callback.call(selector.selected, v)
	)

	selector.item_selected.connect(func(idx: int) -> void:
		var arr: Array = GameManager.layout_config.get(config_key, [])
		slider.set_value_no_signal(arr[idx] if idx < arr.size() else 1.0)
	)

	return {"slider": slider, "selector": selector}


func _sync_per_seat_scale_slider(slider: HSlider, config_key: String, seat_index: int) -> void:
	var arr: Array = GameManager.layout_config.get(config_key, [])
	var val: float = arr[seat_index] if seat_index < arr.size() else 1.0
	slider.set_value_no_signal(val)


func _sync_per_seat_rotation_slider(slider: HSlider, config_key: String, seat_index: int) -> void:
	var arr: Array = GameManager.layout_config.get(config_key, [])
	var val: float = arr[seat_index] if seat_index < arr.size() else 0.0
	slider.set_value_no_signal(val)
