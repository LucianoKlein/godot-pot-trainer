class_name GuestDialog
extends AcceptDialog
## GuestDialog — 游客登录提示弹窗
## 当游客尝试提交答案时显示，引导用户登录

signal go_to_login()


func _ready() -> void:
	title = ""
	dialog_text = Locale.tr_key("guest_login_required")
	ok_button_text = Locale.tr_key("go_to_login")
	add_cancel_button(Locale.tr_key("cancel"))
	confirmed.connect(_on_confirmed)
	_apply_styles()


func _apply_styles() -> void:
	var panel_sb := UiFactory.make_stylebox(Color(0.08, 0.08, 0.10, 0.95), 8, 20, Color(0.82, 0.66, 0.26), 2)
	add_theme_stylebox_override("panel", panel_sb)
	add_theme_font_size_override("font_size", 24)
	add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))


func show_dialog() -> void:
	popup_centered()


func _on_confirmed() -> void:
	go_to_login.emit()
