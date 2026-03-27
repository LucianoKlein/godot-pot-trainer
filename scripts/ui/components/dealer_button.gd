class_name DealerButton
extends RefCounted
## DealerButton — 庄位按钮组件
## 负责庄位按钮的创建、刷新和动画

var _parent: Control
var _table_overlay: Control
var _button: Control
var _tween: Tween


func setup(parent: Control, table_overlay: Control) -> RefCounted:
	_parent = parent
	_table_overlay = table_overlay
	return self


func build() -> void:
	var scale: float = GameManager.layout_config.get("dealer_button_scale", 1.0)
	var btn_size: Vector2 = Vector2(28, 28) * scale

	_button = Control.new()
	_button.name = "DealerButton"
	_button.custom_minimum_size = btn_size
	_button.size = btn_size
	_button.z_index = 3

	var bg: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = Color.BLACK
	sb.set_border_width_all(2)
	var radius: int = int(btn_size.x / 2)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(bg)

	var lbl: Label = Label.new()
	lbl.text = "D"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(14 * scale))
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(lbl)

	var pos: Vector2 = GameManager.get_layout_position_px("dealer_buttons", GameManager.get_physical_seat(GameManager.dealer_index))
	_button.position = pos - btn_size * 0.5
	_table_overlay.add_child(_button)


func get_button() -> Control:
	return _button


func refresh() -> void:
	if not _button or not is_instance_valid(_button):
		return

	var physical_seat: int = GameManager.get_physical_seat(GameManager.dealer_index)
	var scale: float = GameManager.layout_config.get("dealer_button_scale", 1.0)
	var btn_size: Vector2 = Vector2(28, 28) * scale
	_button.size = btn_size

	var pos: Vector2 = GameManager.get_layout_position_px("dealer_buttons", physical_seat)
	var target: Vector2 = pos - btn_size * 0.5

	if _tween:
		_tween.kill()
	_tween = _parent.create_tween()
	_tween.tween_property(_button, "position", target, 0.3)
