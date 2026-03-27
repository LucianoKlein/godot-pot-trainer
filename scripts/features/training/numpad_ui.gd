class_name NumpadUI
extends PanelContainer
## NumpadUI — 数字键盘组件
## 独立的数字键盘，可被任何需要数字输入的界面使用

signal key_pressed(key: String)

var _grid: GridContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# 键盘背景样式
	var pad_sb := UiFactory.make_stylebox(Color(0.07, 0.07, 0.09, 0.97), 10, 10, Color(0.50, 0.40, 0.16), 2)
	pad_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	pad_sb.shadow_size = 6
	add_theme_stylebox_override("panel", pad_sb)

	# 按钮网格
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)

	# 按键布局
	var keys: Array[String] = [
		"1", "2", "3", "4", "5", "6", "7", "8", "9", "cancel", "0", "confirm",
	]

	for key in keys:
		var btn := _create_key_button(key)
		_grid.add_child(btn)


func _create_key_button(key: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 72)
	btn.add_theme_font_size_override("font_size", 28)

	var colors: Array  # [font, ns_bg, ns_border, hs_bg, hs_border, ps_bg, ps_border]
	if key == "confirm":
		btn.text = Locale.tr_key("numpad_confirm")
		colors = [Color(0.30, 0.92, 0.50),
			Color(0.12, 0.22, 0.14, 0.9), Color(0.25, 0.55, 0.30, 0.7),
			Color(0.16, 0.30, 0.18, 0.9), Color(0.30, 0.70, 0.38),
			Color(0.08, 0.16, 0.10, 0.95), Color(0.30, 0.70, 0.38)]
	elif key == "cancel":
		btn.text = Locale.tr_key("numpad_cancel")
		colors = [Color(0.90, 0.45, 0.40),
			Color(0.22, 0.12, 0.12, 0.9), Color(0.55, 0.25, 0.22, 0.7),
			Color(0.30, 0.16, 0.14, 0.9), Color(0.70, 0.32, 0.28),
			Color(0.16, 0.08, 0.08, 0.95), Color(0.70, 0.32, 0.28)]
	else:
		btn.text = key
		colors = [Color(0.92, 0.88, 0.78),
			Color(0.16, 0.15, 0.13, 0.92), Color(0.50, 0.40, 0.16, 0.5),
			Color(0.22, 0.20, 0.16, 0.92), Color(0.72, 0.58, 0.24),
			Color(0.10, 0.09, 0.08, 0.95), Color(0.72, 0.58, 0.24)]

	btn.add_theme_color_override("font_color", colors[0])
	btn.add_theme_stylebox_override("normal", UiFactory.make_stylebox(colors[1], 8, 6, colors[2], 1))
	btn.add_theme_stylebox_override("hover", UiFactory.make_stylebox(colors[3], 8, 6, colors[4], 1))
	btn.add_theme_stylebox_override("pressed", UiFactory.make_stylebox(colors[5], 8, 6, colors[6], 1))
	btn.pressed.connect(func() -> void: key_pressed.emit(key))
	return btn
