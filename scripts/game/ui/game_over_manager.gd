class_name GameOverManager
extends RefCounted
## GameOverManager — 游戏结束遮罩管理

var _parent: Control
var _overlay: Control


func setup(parent: Control) -> RefCounted:
	_parent = parent
	return self


func show() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()

	_overlay = Control.new()
	_overlay.name = "GameOverOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 200
	_parent.add_child(_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bg)

	var lbl := Label.new()
	lbl.text = Locale.tr_key("game_mode_hand_over")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	var lbl_sb := StyleBoxFlat.new()
	lbl_sb.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	lbl_sb.border_color = Color(0.72, 0.58, 0.24)
	lbl_sb.set_border_width_all(2)
	lbl_sb.set_corner_radius_all(12)
	lbl_sb.set_content_margin_all(24)
	lbl.add_theme_stylebox_override("normal", lbl_sb)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.modulate.a = 0.0
	_overlay.add_child(lbl)

	var tw := _parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(bg, "color:a", 0.4, 0.3)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.3)


func hide() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
