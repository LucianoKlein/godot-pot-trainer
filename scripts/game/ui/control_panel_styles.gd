class_name ControlPanelStyles
extends RefCounted
## ControlPanelStyles — 控制面板样式工厂

const GOLD := Color(0.90, 0.80, 0.55)
const BG := Color(0.08, 0.08, 0.10, 0.82)
const BORDER := Color(0.50, 0.40, 0.16)
const HOVER_BG := Color(0.14, 0.13, 0.10, 0.85)
const HOVER_BORDER := Color(0.72, 0.58, 0.24)


static func make_action_btn(text: String, bg_color: Color, border_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 75)
	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_stylebox_override("normal", UiFactory.make_stylebox(bg_color, 4, 8, border_color, 1))
	btn.add_theme_stylebox_override("hover", UiFactory.make_stylebox(HOVER_BG, 4, 8, border_color.lightened(0.15), 1))
	btn.add_theme_color_override("font_color", GOLD)
	return btn


static func make_option_group(label_text: String) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_child(UiFactory.make_label(label_text, 28, GOLD))
	return group


static func make_styled_option() -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(240, 72)
	opt.add_theme_font_size_override("font_size", 28)
	opt.add_theme_stylebox_override("normal", UiFactory.make_stylebox(BG, 4, 8, BORDER, 1))
	opt.add_theme_stylebox_override("hover", UiFactory.make_stylebox(HOVER_BG, 4, 8, HOVER_BORDER, 1))
	opt.add_theme_color_override("font_color", GOLD)
	return opt


static func style_popup(opt: OptionButton) -> void:
	var popup := opt.get_popup()
	popup.add_theme_font_size_override("font_size", 28)
	popup.add_theme_constant_override("v_separation", 6)
	popup.add_theme_stylebox_override("panel", UiFactory.make_stylebox(Color(0.08, 0.08, 0.10, 0.95), 6, 10, BORDER, 1))
	popup.add_theme_stylebox_override("hover", UiFactory.make_stylebox(Color(0.22, 0.17, 0.06), 4, 0))
	popup.add_theme_color_override("font_color", GOLD)
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.35))
