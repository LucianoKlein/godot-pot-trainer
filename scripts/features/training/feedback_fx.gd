class_name FeedbackFX
extends Control
## FeedbackFX — 答题反馈特效组件
## 显示答对/答错的视觉反馈（闪屏 + 粒子效果）


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 190
	visible = false


func play_correct() -> void:
	_play_sfx("res://assets/music/sounds_effect/right.ogg")
	_flash_correct()


func play_wrong() -> void:
	_play_sfx("res://assets/music/sounds_effect/wrong.ogg")
	_flash_wrong()


func _play_sfx(path: String) -> void:
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.play_sfx(path)


func _flash_wrong() -> void:
	for c in get_children():
		c.queue_free()
	visible = true
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.8, 0.1, 0.1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.35, 0.1)
	tw.tween_property(flash, "color:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		visible = false
		for c2 in get_children():
			c2.queue_free()
	)


func _flash_correct() -> void:
	for c in get_children():
		c.queue_free()
	visible = true
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.1, 0.8, 0.3, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw_flash := create_tween()
	tw_flash.tween_property(flash, "color:a", 0.3, 0.1)
	tw_flash.tween_property(flash, "color:a", 0.0, 0.35)
	await get_tree().create_timer(0.5).timeout
	visible = false
	for c2 in get_children():
		c2.queue_free()
	var symbols: Array[String] = ["★", "✦", "♠", "♥", "♦", "♣", "●", "◆"]
	var colors: Array[Color] = [Color.YELLOW, Color(0.2, 1.0, 0.4), Color.CYAN, Color.WHITE, Color(1.0, 0.6, 0.1)]
	visible = true
	for _i in range(18):
		var p := Label.new()
		p.text = symbols[randi() % symbols.size()]
		p.add_theme_font_size_override("font_size", randi_range(36, 72))
		p.add_theme_color_override("font_color", colors[randi() % colors.size()])
		p.position = Vector2(randi_range(100, 1820), randi_range(100, 980))
		add_child(p)
		var tw := create_tween()
		tw.set_parallel(true)
		var target := p.position + Vector2(randf_range(-200, 200), randf_range(-300, 100))
		tw.tween_property(p, "position", target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_LINEAR)
	await get_tree().create_timer(0.5).timeout
	visible = false
	for c3 in get_children():
		c3.queue_free()
