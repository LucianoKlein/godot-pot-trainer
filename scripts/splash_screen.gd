extends Control

var _spinner_angle := 0.0
var _spinner: Control

func _t(en: String, zh: String) -> String:
	return zh if GameManager.language == "zh" else en

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

	# Loading text — right-bottom, hidden initially
	var loading_lbl := Label.new()
	loading_lbl.text = _t("Loading, please wait...", "正在进入，请稍后...")
	loading_lbl.add_theme_font_size_override("font_size", 20)
	loading_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.0))
	loading_lbl.anchor_left = 1.0
	loading_lbl.anchor_top = 1.0
	loading_lbl.anchor_right = 1.0
	loading_lbl.anchor_bottom = 1.0
	loading_lbl.offset_left = -300
	loading_lbl.offset_right = -60
	loading_lbl.offset_top = -50
	loading_lbl.offset_bottom = -20
	loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(loading_lbl)

	# Spinner — right-bottom, next to loading text
	_spinner = Control.new()
	_spinner.anchor_left = 1.0
	_spinner.anchor_top = 1.0
	_spinner.anchor_right = 1.0
	_spinner.anchor_bottom = 1.0
	_spinner.offset_left = -48
	_spinner.offset_right = -20
	_spinner.offset_top = -50
	_spinner.offset_bottom = -22
	_spinner.modulate.a = 0.0
	_spinner.connect("draw", _draw_spinner)
	add_child(_spinner)

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

	# Fade in REG School + loading text + spinner
	tween.tween_property(school_lbl, "theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(loading_lbl, "theme_override_colors/font_color", Color(0.6, 0.6, 0.6, 1.0), 0.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_spinner, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

	# Hold for background loading
	tween.tween_interval(1.0)

	# Auto-enter main menu
	tween.tween_callback(_go_to_menu)


func _process(delta: float) -> void:
	_spinner_angle += delta * 360.0
	if _spinner_angle > 360.0:
		_spinner_angle -= 360.0
	if _spinner:
		_spinner.queue_redraw()


func _draw_spinner() -> void:
	var center := _spinner.size / 2.0
	var radius: float = min(center.x, center.y) - 2.0
	var color := Color(0.7, 0.7, 0.7)
	var arc_points := 24
	var start_angle := deg_to_rad(_spinner_angle)
	var end_angle := start_angle + deg_to_rad(270.0)
	var points := PackedVector2Array()
	for i in range(arc_points + 1):
		var angle := start_angle + (end_angle - start_angle) * float(i) / float(arc_points)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for i in range(arc_points):
		_spinner.draw_line(points[i], points[i + 1], color, 2.5, true)


func _go_to_menu() -> void:
	get_tree().root.get_node("Main").switch_from_splash("res://scenes/main_menu/main_menu.tscn")
