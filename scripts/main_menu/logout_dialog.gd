class_name LogoutDialog
extends RefCounted
## LogoutDialog — 登出确认对话框

signal play_sfx_requested(path: String)
signal logout_completed()

var _parent: Control
var _make_entry_btn: Callable
var _dialog: Control


func setup(parent: Control, make_btn_callable: Callable) -> RefCounted:
	_parent = parent
	_make_entry_btn = make_btn_callable
	return self


func show() -> void:
	if _dialog != null:
		_dialog.queue_free()
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_parent.add_child(overlay)
	_dialog = overlay

	var dialog := PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.offset_left = -200
	dialog.offset_right = 200
	dialog.offset_top = -90
	dialog.offset_bottom = 90
	dialog.add_theme_stylebox_override("panel", UiFactory.make_stylebox(
		Color(0.08, 0.08, 0.10, 0.97), 6, 0, Color(0.50, 0.40, 0.16), 1))
	overlay.add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 20)
	margin.add_child(inner)

	var msg := Label.new()
	msg.text = Locale.tr_key("confirm_logout")
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color(0.92, 0.80, 0.55))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(btn_row)

	var cancel_btn: Button = _make_entry_btn.call(Locale.tr_key("cancel"), Color(0.08, 0.08, 0.10, 0.82), Color(0.50, 0.40, 0.16))
	cancel_btn.custom_minimum_size = Vector2(130, 52)
	cancel_btn.pressed.connect(func() -> void:
		play_sfx_requested.emit("res://assets/music/sounds_effect/button.ogg")
		_dialog.queue_free()
		_dialog = null)
	btn_row.add_child(cancel_btn)

	var confirm_btn: Button = _make_entry_btn.call(Locale.tr_key("logout"), Color(0.08, 0.08, 0.10, 0.82), Color(0.55, 0.25, 0.15))
	confirm_btn.custom_minimum_size = Vector2(130, 52)
	confirm_btn.pressed.connect(func() -> void:
		play_sfx_requested.emit("res://assets/music/sounds_effect/button.ogg")
		_dialog.queue_free()
		_dialog = null
		FirebaseAuth.logout())
	btn_row.add_child(confirm_btn)
