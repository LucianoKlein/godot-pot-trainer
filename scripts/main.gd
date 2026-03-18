extends Node

@onready var current_scene: Node = $CurrentScene.get_child(0)
@onready var _intro_player: AudioStreamPlayer = $IntroMusic
@onready var _main_player: AudioStreamPlayer = $MainMusic
@onready var _sfx_player: AudioStreamPlayer = $SfxPlayer

var _transition_overlay: ColorRect

const SFX_BUTTON := "res://assets/music/sounds_effect/button.ogg"
const SFX_SHUFFLE := "res://assets/music/sounds_effect/shuffle sounds.ogg"
const SFX_RIGHT := "res://assets/music/sounds_effect/right.ogg"
const SFX_WRONG := "res://assets/music/sounds_effect/wrong.ogg"


func play_sfx(path: String) -> void:
	if sfx_volume <= 0.0:
		return
	_sfx_player.stream = load(path)
	_sfx_player.volume_db = linear_to_db(sfx_volume)
	_sfx_player.play()


const SETTINGS_PATH := "user://settings.json"

# Volume: 0.0 ~ 1.0
var music_volume: float = 1.0:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		_apply_volume()
		_save_settings()

var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_sfx_volume()
		_save_settings()


func _ready() -> void:
	_load_settings()
	_intro_player.stream = load("res://assets/music/intro_music.ogg")
	_main_player.stream = load("res://assets/music/main_music.ogg")
	(_main_player.stream as AudioStreamOggVorbis).loop = true
	_apply_volume()
	_apply_sfx_volume()
	_intro_player.play()

	# Persistent overlay for non-splash scene transitions (CanvasLayer so it's always on top)
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color(0.04, 0.03, 0.02, 1.0)
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.visible = false
	canvas.add_child(_transition_overlay)

	# Background-load both main scenes while splash animation plays
	ResourceLoader.load_threaded_request("res://scenes/main_menu/main_menu.tscn")
	ResourceLoader.load_threaded_request("res://scenes/game/game_table.tscn")


func _get_scene(scene_path: String) -> PackedScene:
	var status := ResourceLoader.load_threaded_get_status(scene_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return ResourceLoader.load_threaded_get(scene_path) as PackedScene
	return load(scene_path) as PackedScene


func _apply_volume() -> void:
	var db: float = linear_to_db(music_volume) if music_volume > 0.0 else -80.0
	if _intro_player:
		_intro_player.volume_db = db
	if _main_player:
		_main_player.volume_db = db


func _apply_sfx_volume() -> void:
	if _sfx_player:
		_sfx_player.volume_db = linear_to_db(sfx_volume) if sfx_volume > 0.0 else -80.0


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		if data.has("music_volume"):
			music_volume = float(data["music_volume"])
		if data.has("sfx_volume"):
			sfx_volume = float(data["sfx_volume"])
		elif data.has("sfx_enabled"):
			sfx_volume = 1.0 if bool(data["sfx_enabled"]) else 0.0
		if data.has("language"):
			Locale.current_language = data["language"]


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"language": Locale.current_language,
	}))
	f.close()


func switch_scene(scene_path: String) -> void:
	# Switch from intro to main music when leaving splash screen
	if _intro_player.playing:
		_intro_player.stop()
		_main_player.play()

	# Pre-load the scene in background before showing overlay
	var status := ResourceLoader.load_threaded_get_status(scene_path)
	if status != ResourceLoader.THREAD_LOAD_LOADED and status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		ResourceLoader.load_threaded_request(scene_path)

	# Show overlay to cover the transition
	_transition_overlay.color.a = 1.0
	_transition_overlay.visible = true

	# Wait two frames: one for overlay to enter the render queue, one for it to appear on screen
	await get_tree().process_frame
	await get_tree().process_frame

	current_scene.queue_free()

	# Wait until threaded load is complete
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	var next_scene: Node = packed.instantiate()
	$CurrentScene.add_child(next_scene)
	current_scene = next_scene

	# Pre-load the other common scene so the next transition is instant
	var preload_target := ""
	if scene_path == "res://scenes/main_menu/main_menu.tscn":
		preload_target = "res://scenes/game/game_table.tscn"
	else:
		preload_target = "res://scenes/main_menu/main_menu.tscn"
	var pl_status := ResourceLoader.load_threaded_get_status(preload_target)
	if pl_status != ResourceLoader.THREAD_LOAD_LOADED and pl_status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		ResourceLoader.load_threaded_request(preload_target)

	# Wait for new scene to finish layout
	await get_tree().process_frame

	# Fade out overlay
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		_transition_overlay.visible = false
	)


# Special transition from splash: splash stays visible while new scene loads behind it,
# then splash fades out to reveal the ready scene. No black frame possible.
func switch_from_splash(scene_path: String) -> void:
	if _intro_player.playing:
		_intro_player.stop()
		_main_player.play()

	var splash := current_scene

	# Load new scene hidden, so it doesn't flash on screen before splash covers it
	var packed := _get_scene(scene_path)
	var next_scene: Node = packed.instantiate()
	if next_scene is CanvasItem:
		next_scene.visible = false
	$CurrentScene.add_child(next_scene)
	current_scene = next_scene

	# Ensure splash renders on top, then reveal the new scene
	$CurrentScene.move_child(splash, -1)
	if next_scene is CanvasItem:
		next_scene.visible = true

	# Wait two frames so the new scene finishes layout + render
	await get_tree().process_frame
	await get_tree().process_frame

	# Fade out splash to reveal the already-rendered main menu underneath
	var tween := splash.create_tween()
	tween.tween_property(splash, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(splash.queue_free)
