class_name UiFactory
extends RefCounted
## UiFactory — 共享 UI 构建工具
## 提供 StyleBoxFlat、按钮、标签、滑块的统一创建方法，减少各文件重复代码

# 布局编辑器常用颜色
const LAYOUT_BG := Color(0.1, 0.1, 0.18, 0.85)
const LAYOUT_ACTIVE := Color(0.3, 0.3, 0.5, 0.9)
const LAYOUT_FONT := Color(0.8, 0.8, 0.9)
const LAYOUT_LABEL := Color(0.7, 0.7, 0.7)


static func make_stylebox(bg: Color, radius: int = 8, margin: int = 6, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border_width > 0:
		sb.border_color = border_color
		sb.set_border_width_all(border_width)
	return sb


static func make_label(text: String, font_size: int = 28, color: Color = LAYOUT_LABEL) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


## 布局编辑器风格按钮（深色底 + 彩色边框）
static func make_layout_btn(text: String, border_color: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 44
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_stylebox_override("normal", make_stylebox(LAYOUT_BG, 8, 10, border_color, 1))
	btn.add_theme_stylebox_override("hover", make_stylebox(Color(0.15, 0.15, 0.25, 0.85), 8, 10, border_color.lightened(0.15), 1))
	btn.add_theme_color_override("font_color", LAYOUT_FONT)
	btn.pressed.connect(callback)
	return btn


## 切换按钮组：给一组按钮设置 active/inactive 样式
static func apply_toggle_styles(buttons: Array[Button], active_index: int) -> void:
	var active := make_stylebox(LAYOUT_ACTIVE, 8, 6)
	var inactive := make_stylebox(LAYOUT_BG, 8, 6)
	var hover_active := make_stylebox(LAYOUT_ACTIVE.lightened(0.1), 8, 6)
	var hover_inactive := make_stylebox(Color(0.15, 0.15, 0.25, 0.85), 8, 6)
	for i in range(buttons.size()):
		var is_active := (i == active_index)
		var btn: Button = buttons[i]
		btn.add_theme_stylebox_override("normal", active if is_active else inactive)
		btn.add_theme_stylebox_override("hover", hover_active if is_active else hover_inactive)
		btn.add_theme_stylebox_override("pressed", hover_active if is_active else hover_inactive)


## 创建一个切换按钮
static func make_toggle_btn(text: String, min_width: float = 120.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_width, 50)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", LAYOUT_FONT)
	return btn


## 给 HSlider 应用统一的蓝色 grabber 样式
static func apply_slider_theme(slider: HSlider) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.3, 0.7, 1.0)
	grabber.set_corner_radius_all(18)
	grabber.content_margin_left = 18
	grabber.content_margin_right = 18
	grabber.content_margin_top = 18
	grabber.content_margin_bottom = 18
	slider.add_theme_stylebox_override("grabber_area", grabber)
	var hl := StyleBoxFlat.new()
	hl.bg_color = Color(0.4, 0.8, 1.0)
	hl.set_corner_radius_all(18)
	hl.content_margin_left = 18
	hl.content_margin_right = 18
	hl.content_margin_top = 18
	hl.content_margin_bottom = 18
	slider.add_theme_stylebox_override("grabber_area_highlight", hl)


## 创建标准 HSlider（带 grabber 样式）
static func make_slider(min_val: float, max_val: float, initial: float, step: float = 0.05, min_width: float = 300.0) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(min_width, 50)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	apply_slider_theme(slider)
	return slider


## 创建带标签的滑块行（布局编辑器通用）
static func make_slider_row(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, initial: float, callback: Callable, label_width: float = 160.0, step: float = 0.05, checkbox: CheckBox = null) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	if checkbox:
		row.add_child(checkbox)

	var lbl := make_label(label_text)
	lbl.custom_minimum_size.x = label_width
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)

	var slider := make_slider(min_val, max_val, initial, step)
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return slider


## 创建带座位选择器的 per-seat 滑块行
static func make_per_seat_slider_row(parent: VBoxContainer, label_text: String, config_key: String, values: Array, min_val: float, max_val: float, step: float, default_val: float, callback: Callable, label_width: float = 100.0) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	var lbl := make_label(label_text)
	lbl.custom_minimum_size.x = label_width
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
	selector.get_popup().add_theme_font_size_override("font_size", 32)

	var slider := make_slider(min_val, max_val, values[0] if values.size() > 0 else default_val, step, 200.0)
	row.add_child(slider)

	slider.value_changed.connect(func(v: float) -> void:
		callback.call(selector.selected, v)
	)
	selector.item_selected.connect(func(idx: int) -> void:
		var arr: Array = GameManager.layout_config.get(config_key, [])
		slider.set_value_no_signal(arr[idx] if idx < arr.size() else default_val)
	)

	return {"slider": slider, "selector": selector}
