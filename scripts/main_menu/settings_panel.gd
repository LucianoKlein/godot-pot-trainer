extends Node
## SettingsPanel — 设置面板 UI 管理
## 从 main_menu.gd 提取，负责音量、布局调整、语言切换

signal layout_pressed()
signal play_sfx_requested(path: String)

var _parent: Control
var _make_entry_btn: Callable
var panel: Control
var _music_slider: HSlider
var _music_value_lbl: Label
var _sfx_slider: HSlider
var _sfx_value_lbl: Label


func setup(parent: Control, make_btn_callable: Callable) -> Node:
	_parent = parent
	_make_entry_btn = make_btn_callable
	return self


func build() -> Control:
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = 100
	panel.visible = false
	_parent.add_child(panel)

	var title := Label.new()
	title.text = Locale.tr_key("settings")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 0
	title.offset_bottom = 40
	panel.add_child(title)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -300
	vbox.offset_right = 300
	vbox.offset_top = -200
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 32)
	panel.add_child(vbox)

	var main_node := _parent.get_tree().root.get_node_or_null("Main")

	# Music volume row
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 16)
	vbox.add_child(music_row)

	var music_label := Label.new()
	music_label.text = Locale.tr_key("music_volume")
	music_label.add_theme_font_size_override("font_size", 28)
	music_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.32))
	music_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_row.add_child(music_label)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.01
	_music_slider.custom_minimum_size = Vector2(240, 48)
	_music_slider.size_flags_horizontal = Control.SIZE_SHRINK_END
	_music_slider.value = main_node.music_volume if main_node else 1.0
	_music_slider.value_changed.connect(_on_music_volume_changed)
	music_row.add_child(_music_slider)

	_music_value_lbl = Label.new()
	_music_value_lbl.add_theme_font_size_override("font_size", 24)
	_music_value_lbl.add_theme_color_override("font_color", Color(0.88, 0.74, 0.30))
	_music_value_lbl.custom_minimum_size = Vector2(60, 0)
	_music_value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_music_value_lbl.text = "%d%%" % [roundi(_music_slider.value * 100)]
	music_row.add_child(_music_value_lbl)

	# SFX volume row
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 16)
	vbox.add_child(sfx_row)

	var sfx_label := Label.new()
	sfx_label.text = Locale.tr_key("sfx_volume")
	sfx_label.add_theme_font_size_override("font_size", 28)
	sfx_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.32))
	sfx_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_row.add_child(sfx_label)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.01
	_sfx_slider.custom_minimum_size = Vector2(240, 48)
	_sfx_slider.size_flags_horizontal = Control.SIZE_SHRINK_END
	_sfx_slider.value = main_node.sfx_volume if main_node else 1.0
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_row.add_child(_sfx_slider)

	_sfx_value_lbl = Label.new()
	_sfx_value_lbl.add_theme_font_size_override("font_size", 24)
	_sfx_value_lbl.add_theme_color_override("font_color", Color(0.88, 0.74, 0.30))
	_sfx_value_lbl.custom_minimum_size = Vector2(60, 0)
	_sfx_value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sfx_value_lbl.text = "%d%%" % [roundi(_sfx_slider.value * 100)]
	sfx_row.add_child(_sfx_value_lbl)

	# Layout adjust button
	var layout_btn: Button = _make_entry_btn.call(Locale.tr_key("layout_adjust"), Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
	layout_btn.pressed.connect(func() -> void: layout_pressed.emit())
	vbox.add_child(layout_btn)

	# Language toggle row
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 16)
	vbox.add_child(lang_row)

	var lang_label := Label.new()
	lang_label.text = Locale.tr_key("language")
	lang_label.add_theme_font_size_override("font_size", 28)
	lang_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.32))
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_label)

	var lang_option := OptionButton.new()
	lang_option.add_item("English", 0)
	lang_option.add_item("中文", 1)
	lang_option.selected = 1 if Locale.current_language == "zh" else 0
	lang_option.custom_minimum_size = Vector2(160, 48)
	lang_option.add_theme_font_size_override("font_size", 24)
	var lang_s := StyleBoxFlat.new()
	lang_s.bg_color = Color(0.08, 0.08, 0.10, 0.82)
	lang_s.border_color = Color(0.50, 0.40, 0.16)
	lang_s.set_border_width_all(1)
	lang_s.set_corner_radius_all(6)
	lang_s.set_content_margin_all(8)
	lang_option.add_theme_stylebox_override("normal", lang_s)
	lang_option.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	lang_option.item_selected.connect(func(index: int) -> void:
		var lang: String = "en" if index == 0 else "zh"
		Locale.current_language = lang
		var mn := _parent.get_tree().root.get_node_or_null("Main")
		if mn:
			mn._save_settings()
	)
	lang_row.add_child(lang_option)

	return panel


func _on_music_volume_changed(value: float) -> void:
	if _music_value_lbl:
		_music_value_lbl.text = "%d%%" % [roundi(value * 100)]
	var main_node := _parent.get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.music_volume = value


func _on_sfx_volume_changed(value: float) -> void:
	if _sfx_value_lbl:
		_sfx_value_lbl.text = "%d%%" % [roundi(value * 100)]
	var main_node := _parent.get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.sfx_volume = value
