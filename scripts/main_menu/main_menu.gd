extends Control

var _entry_panel: Control
var _settings_panel: Control
var _back_btn: Button
var _music_slider: HSlider
var _music_value_lbl: Label
var _sfx_toggle_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background image
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var bg_tex := load("res://assets/ui/bg/main_bg.jpg")
	if bg_tex:
		bg.texture = bg_tex
	else:
		var fallback := ColorRect.new()
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.color = Color(0.05, 0.08, 0.05)
		add_child(fallback)
	add_child(bg)

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.30)
	add_child(overlay)

	# Title
	var title := Label.new()
	title.text = "底池训练器"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.94, 0.80, 0.31))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 28
	title.offset_bottom = 80
	add_child(title)

	# --- Entry panel ---
	_entry_panel = Control.new()
	_entry_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_entry_panel.offset_top = 100
	add_child(_entry_panel)

	var entry_vbox := VBoxContainer.new()
	entry_vbox.set_anchors_preset(Control.PRESET_CENTER)
	entry_vbox.offset_left = -200
	entry_vbox.offset_right = 200
	entry_vbox.offset_top = -100
	entry_vbox.offset_bottom = 100
	entry_vbox.add_theme_constant_override("separation", 24)
	_entry_panel.add_child(entry_vbox)

	var new_game_btn := _make_entry_btn("开始游戏", Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
	new_game_btn.pressed.connect(_on_new_game_pressed)
	entry_vbox.add_child(new_game_btn)

	var settings_btn := _make_entry_btn("设置", Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
	settings_btn.pressed.connect(_on_settings_pressed)
	entry_vbox.add_child(settings_btn)

	# --- Settings panel (hidden) ---
	_settings_panel = Control.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.offset_top = 100
	_settings_panel.visible = false
	add_child(_settings_panel)

	var settings_title := Label.new()
	settings_title.text = "设置"
	settings_title.add_theme_font_size_override("font_size", 26)
	settings_title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	settings_title.offset_top = 0
	settings_title.offset_bottom = 40
	_settings_panel.add_child(settings_title)

	var settings_vbox := VBoxContainer.new()
	settings_vbox.set_anchors_preset(Control.PRESET_CENTER)
	settings_vbox.offset_left = -300
	settings_vbox.offset_right = 300
	settings_vbox.offset_top = -200
	settings_vbox.offset_bottom = 200
	settings_vbox.add_theme_constant_override("separation", 32)
	_settings_panel.add_child(settings_vbox)

	# Music volume row
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 16)
	settings_vbox.add_child(music_row)

	var music_label := Label.new()
	music_label.text = "背景音乐音量"
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
	var main_node := get_tree().root.get_node_or_null("Main")
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

	# Sound effects toggle row
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 16)
	settings_vbox.add_child(sfx_row)

	var sfx_label := Label.new()
	sfx_label.text = "音效"
	sfx_label.add_theme_font_size_override("font_size", 28)
	sfx_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.32))
	sfx_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_row.add_child(sfx_label)

	var sfx_on: bool = main_node.sfx_enabled if main_node else true
	_sfx_toggle_btn = _make_toolbar_btn("", Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
	_sfx_toggle_btn.custom_minimum_size = Vector2(120, 48)
	_sfx_toggle_btn.pressed.connect(_on_sfx_toggle_pressed)
	sfx_row.add_child(_sfx_toggle_btn)
	_refresh_sfx_btn()

	# Layout adjust button
	var layout_btn := _make_entry_btn("布局调整", Color(0.08, 0.08, 0.10, 0.82), Color(0.82, 0.66, 0.26))
	layout_btn.pressed.connect(_on_layout_pressed)
	settings_vbox.add_child(layout_btn)

	# Back button — top-left
	_back_btn = _make_toolbar_btn("← 返回", Color(0.08, 0.08, 0.10, 0.82), Color(0.55, 0.25, 0.15))
	_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_btn.offset_top = 16
	_back_btn.offset_left = 16
	_back_btn.offset_bottom = 72
	_back_btn.offset_right = 200
	_back_btn.visible = false
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)


# =============================================================================
# Callbacks
# =============================================================================

func _play_sfx(path: String) -> void:
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.play_sfx(path)


func _on_new_game_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	GameManager.change_state(GameManager.State.PLAYING)
	get_tree().root.get_node("Main").switch_scene("res://scenes/game/game_table.tscn")


func _on_settings_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	_entry_panel.visible = false
	_settings_panel.visible = true
	_back_btn.visible = true


func _on_back_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	_settings_panel.visible = false
	_back_btn.visible = false
	_entry_panel.visible = true


func _on_layout_pressed() -> void:
	_play_sfx("res://assets/music/sounds_effect/button.ogg")
	GameManager.pending_layout_mode = true
	GameManager.change_state(GameManager.State.PLAYING)
	get_tree().root.get_node("Main").switch_scene("res://scenes/game/game_table.tscn")


func _on_music_volume_changed(value: float) -> void:
	if _music_value_lbl:
		_music_value_lbl.text = "%d%%" % [roundi(value * 100)]
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.music_volume = value


func _on_sfx_toggle_pressed() -> void:
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.sfx_enabled = not main_node.sfx_enabled
	_refresh_sfx_btn()
	_play_sfx("res://assets/music/sounds_effect/button.ogg")


func _refresh_sfx_btn() -> void:
	if not _sfx_toggle_btn:
		return
	var main_node := get_tree().root.get_node_or_null("Main")
	var on: bool = main_node.sfx_enabled if main_node else true
	_sfx_toggle_btn.text = "开启" if on else "关闭"
	var border_color := Color(0.25, 0.55, 0.30) if on else Color(0.55, 0.25, 0.15)
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(10)
	normal.bg_color = Color(0.08, 0.08, 0.10, 0.82)
	normal.border_color = border_color
	normal.set_border_width_all(1)
	_sfx_toggle_btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(10)
	hover.bg_color = Color(0.14, 0.13, 0.10, 0.85)
	hover.border_color = border_color.lightened(0.15)
	hover.set_border_width_all(1)
	_sfx_toggle_btn.add_theme_stylebox_override("hover", hover)
	_sfx_toggle_btn.add_theme_stylebox_override("pressed", hover)
	_sfx_toggle_btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	_sfx_toggle_btn.add_theme_color_override("font_hover_color", Color(0.90, 0.80, 0.55))
	_sfx_toggle_btn.add_theme_font_size_override("font_size", 24)


# =============================================================================
# Button helpers
# =============================================================================

func _make_entry_btn(text: String, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(340, 80)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(14)
	btn.add_theme_stylebox_override("normal", s)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.14, 0.13, 0.10, 0.85)
	h.border_color = Color(border.r + 0.15, border.g + 0.12, border.b + 0.05)
	h.set_border_width_all(1)
	h.set_corner_radius_all(6)
	h.set_content_margin_all(14)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus", s)
	return btn


func _make_toolbar_btn(text: String, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 56)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", s)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.14, 0.13, 0.10, 0.85)
	h.border_color = border.lightened(0.15)
	h.set_border_width_all(1)
	h.set_corner_radius_all(6)
	h.set_content_margin_all(12)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus", s)
	return btn
