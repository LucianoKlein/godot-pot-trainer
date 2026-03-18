extends Control

var _ready_for_input := false


func _ready() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.02, 1.0)
	add_child(bg)

	# Logo
	var logo_size := 360.0
	var logo_land_top := -logo_size / 2.0 - 60.0
	var logo_land_bottom := logo_size / 2.0 - 60.0

	var logo_img := TextureRect.new()
	logo_img.texture = load("res://assets/ui/logo.png")
	logo_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_img.anchor_left = 0.5
	logo_img.anchor_top = 0.5
	logo_img.anchor_right = 0.5
	logo_img.anchor_bottom = 0.5
	logo_img.offset_left = -logo_size / 2.0
	logo_img.offset_right = logo_size / 2.0
	logo_img.offset_top = logo_land_top - 500.0
	logo_img.offset_bottom = logo_land_top - 500.0 + logo_size
	add_child(logo_img)

	# "REG School" label — below logo, hidden initially
	var school_lbl := Label.new()
	school_lbl.text = "Result Education Group"
	school_lbl.add_theme_font_size_override("font_size", 64)
	school_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
	school_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	school_lbl.anchor_left = 0.0
	school_lbl.anchor_top = 0.5
	school_lbl.anchor_right = 1.0
	school_lbl.anchor_bottom = 0.5
	school_lbl.offset_left = 0
	school_lbl.offset_right = 0
	school_lbl.offset_top = logo_land_bottom + 20
	school_lbl.offset_bottom = logo_land_bottom + 90
	add_child(school_lbl)

	# "Tap to continue" prompt — hidden initially
	var prompt_lbl := Label.new()
	prompt_lbl.text = Locale.tr_key("splash_continue")
	prompt_lbl.add_theme_font_size_override("font_size", 22)
	prompt_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.0))
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_lbl.offset_top = -80
	prompt_lbl.offset_bottom = -40
	add_child(prompt_lbl)

	# Animation sequence
	var tween := create_tween()
	tween.set_parallel(false)

	# 1. Fall
	tween.tween_property(logo_img, "offset_top", logo_land_top, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(logo_img, "offset_bottom", logo_land_bottom, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 2. First bounce up
	tween.tween_property(logo_img, "offset_top", logo_land_top - 42.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(logo_img, "offset_bottom", logo_land_bottom - 42.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 3. Fall back
	tween.tween_property(logo_img, "offset_top", logo_land_top, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(logo_img, "offset_bottom", logo_land_bottom, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 4. Second small bounce
	tween.tween_property(logo_img, "offset_top", logo_land_top - 16.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(logo_img, "offset_bottom", logo_land_bottom - 16.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 5. Settle
	tween.tween_property(logo_img, "offset_top", logo_land_top, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(logo_img, "offset_bottom", logo_land_bottom, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Fade in REG School + prompt together
	tween.tween_property(school_lbl, "theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(prompt_lbl, "theme_override_colors/font_color", Color(0.7, 0.7, 0.7, 1.0), 0.4).set_trans(Tween.TRANS_SINE)

	tween.tween_callback(func() -> void:
		_ready_for_input = true
		# Blinking prompt
		var blink := create_tween().set_loops()
		blink.tween_property(prompt_lbl, "theme_override_colors/font_color", Color(0.7, 0.7, 0.7, 0.2), 0.7).set_trans(Tween.TRANS_SINE).set_delay(0.5)
		blink.tween_property(prompt_lbl, "theme_override_colors/font_color", Color(0.7, 0.7, 0.7, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	)


func _input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_go_to_menu()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_menu()
	elif event is InputEventScreenTouch and event.pressed:
		_go_to_menu()


func _go_to_menu() -> void:
	_ready_for_input = false
	get_tree().root.get_node("Main").switch_from_splash("res://scenes/main_menu/main_menu.tscn")
