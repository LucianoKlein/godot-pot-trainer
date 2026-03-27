class_name SceneSwitcher
extends RefCounted
## SceneSwitcher — 场景切换器
## 负责场景加载、过渡动画、加载进度条

var _main: Node
var _transition_overlay: ColorRect
var _loading_bar_bg: ColorRect
var _loading_bar_fill: ColorRect
var _loading_label: Label
var _tip_label: Label
var _scene_cache: Dictionary = {}


func setup(main: Node, overlay: ColorRect, bar_bg: ColorRect, bar_fill: ColorRect, loading_label: Label, tip_label: Label) -> RefCounted:
	_main = main
	_transition_overlay = overlay
	_loading_bar_bg = bar_bg
	_loading_bar_fill = bar_fill
	_loading_label = loading_label
	_tip_label = tip_label
	return self


func get_scene(scene_path: String) -> PackedScene:
	if _scene_cache.has(scene_path):
		return _scene_cache[scene_path]
	var packed := ResourceLoader.load(scene_path) as PackedScene
	_scene_cache[scene_path] = packed
	return packed


func show_loading() -> void:
	_loading_bar_bg.visible = true
	_loading_bar_fill.size.x = 0
	_loading_label.visible = true
	_loading_label.text = "0%"
	var tips: Array = _main.TIPS_ZH if GameManager.language == "zh" else _main.TIPS_EN
	_tip_label.text = tips[randi() % tips.size()]
	_tip_label.visible = true


func set_loading_progress(p: float) -> void:
	_loading_bar_fill.size.x = _loading_bar_bg.size.x * clampf(p, 0.0, 1.0)
	_loading_label.text = "%d%%" % int(p * 100)


func hide_loading() -> void:
	_loading_bar_bg.visible = false
	_loading_label.visible = false
	_tip_label.visible = false


func switch_scene(scene_path: String) -> void:
	var intro_player: AudioStreamPlayer = _main.get_node("IntroMusic")
	var main_player: AudioStreamPlayer = _main.get_node("MainMusic")
	if intro_player.playing:
		intro_player.stop()
		main_player.play()

	var status := ResourceLoader.load_threaded_get_status(scene_path)
	if status != ResourceLoader.THREAD_LOAD_LOADED and status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		ResourceLoader.load_threaded_request(scene_path)

	_transition_overlay.color.a = 1.0
	_transition_overlay.visible = true
	show_loading()
	set_loading_progress(0.0)

	await _main.get_tree().process_frame
	await _main.get_tree().process_frame

	# Phase 0: chaotic ramp 0% → random target (25-40%)
	var ramp_target := randf_range(0.25, 0.4)
	var ramp_progress := 0.0
	var ramp_speed := randf_range(0.3, 0.8)
	var ramp_seg := 0.0
	while ramp_progress < ramp_target:
		var dt: float = _main.get_process_delta_time()
		ramp_seg += dt
		if ramp_seg > randf_range(0.05, 0.2):
			ramp_seg = 0.0
			if randf() < 0.25:
				ramp_speed = randf_range(0.02, 0.08)
			elif randf() < 0.4:
				ramp_speed = randf_range(0.8, 2.0)
			else:
				ramp_speed = randf_range(0.2, 0.6)
		var jitter := randf_range(0.8, 1.3)
		ramp_progress = minf(ramp_progress + dt * ramp_speed * jitter, ramp_target)
		set_loading_progress(ramp_progress)
		await _main.get_tree().process_frame

	_main.current_scene.queue_free()

	# Phase 1: real loading (ramp_target → 70%)
	var progress: Array = []
	while ResourceLoader.load_threaded_get_status(scene_path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var real_p: float = progress[0] if progress.size() > 0 else 0.0
		set_loading_progress(ramp_target + real_p * (0.7 - ramp_target))
		await _main.get_tree().process_frame

	# Phase 2: instantiate scene
	var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	var next_scene: Node = packed.instantiate()
	set_loading_progress(randf_range(0.7, 0.78))
	_main.get_node("CurrentScene").add_child(next_scene)
	_main.current_scene = next_scene

	# Pre-load the other common scene
	var preload_target := ""
	if scene_path == "res://scenes/main_menu/main_menu.tscn":
		preload_target = "res://scenes/game/game_table.tscn"
	else:
		preload_target = "res://scenes/main_menu/main_menu.tscn"
	var pl_status := ResourceLoader.load_threaded_get_status(preload_target)
	if pl_status != ResourceLoader.THREAD_LOAD_LOADED and pl_status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		ResourceLoader.load_threaded_request(preload_target)

	await _main.get_tree().process_frame

	# Phase 3: chaotic fake progress → 100%
	var fake_p: float = _loading_bar_fill.size.x / _loading_bar_bg.size.x
	var min_duration := randf_range(1.8, 3.2)
	var elapsed := 0.0
	var seg_timer := 0.0
	var seg_speed := randf_range(0.05, 0.15)
	var stall_cooldown := 0.0
	while fake_p < 1.0:
		var dt: float = _main.get_process_delta_time()
		elapsed += dt
		seg_timer += dt
		stall_cooldown -= dt
		if seg_timer > randf_range(0.08, 0.4):
			seg_timer = 0.0
			var roll := randf()
			if roll < 0.2 and stall_cooldown <= 0.0:
				seg_speed = 0.0
				stall_cooldown = randf_range(0.3, 0.6)
			elif roll < 0.35:
				seg_speed = randf_range(0.005, 0.03)
			elif roll < 0.6:
				seg_speed = randf_range(0.03, 0.12)
			elif roll < 0.85:
				seg_speed = randf_range(0.12, 0.35)
			else:
				seg_speed = randf_range(0.35, 0.6)
		if stall_cooldown <= 0.0 and seg_speed == 0.0:
			seg_speed = randf_range(0.08, 0.25)
		var jitter := randf_range(0.6, 1.5)
		if elapsed > min_duration * 0.9:
			seg_speed = maxf(seg_speed, 0.4)
			jitter = randf_range(1.0, 1.5)
		fake_p = minf(fake_p + dt * seg_speed * jitter, 1.0)
		set_loading_progress(fake_p)
		await _main.get_tree().process_frame

	set_loading_progress(1.0)

	# Fade out overlay
	var tween := _main.create_tween()
	tween.tween_property(_transition_overlay, "color:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_loading_bar_bg, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_loading_label, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_tip_label, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		_transition_overlay.visible = false
		hide_loading()
		_loading_bar_bg.modulate.a = 1.0
		_loading_label.modulate.a = 1.0
		_tip_label.modulate.a = 1.0
	)


func switch_from_splash(scene_path: String) -> void:
	var intro_player: AudioStreamPlayer = _main.get_node("IntroMusic")
	var main_player: AudioStreamPlayer = _main.get_node("MainMusic")
	if intro_player.playing:
		intro_player.stop()
		main_player.play()

	var splash: Node = _main.current_scene
	var packed: PackedScene = get_scene(scene_path)
	var next_scene: Node = packed.instantiate()
	if next_scene is CanvasItem:
		next_scene.visible = false
	_main.get_node("CurrentScene").add_child(next_scene)
	_main.current_scene = next_scene

	_main.get_node("CurrentScene").move_child(splash, -1)
	if next_scene is CanvasItem:
		next_scene.visible = true

	await _main.get_tree().process_frame
	await _main.get_tree().process_frame

	var tween := splash.create_tween()
	tween.tween_property(splash, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(splash.queue_free)
