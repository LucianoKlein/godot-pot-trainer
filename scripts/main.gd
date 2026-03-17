extends Node

@onready var current_scene: Node = $CurrentScene.get_child(0)
@onready var _intro_player: AudioStreamPlayer = $IntroMusic
@onready var _main_player: AudioStreamPlayer = $MainMusic
@onready var _sfx_player: AudioStreamPlayer = $SfxPlayer

const SFX_BUTTON := "res://assets/music/sounds_effect/button.ogg"
const SFX_SHUFFLE := "res://assets/music/sounds_effect/shuffle sounds.ogg"
const SFX_RIGHT := "res://assets/music/sounds_effect/right.ogg"
const SFX_WRONG := "res://assets/music/sounds_effect/wrong.ogg"


func play_sfx(path: String) -> void:
	if not sfx_enabled:
		return
	_sfx_player.stream = load(path)
	_sfx_player.play()

const SETTINGS_PATH := "user://settings.json"

# Volume: 0.0 ~ 1.0
var music_volume: float = 1.0:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		_apply_volume()
		_save_settings()

var sfx_enabled: bool = true:
	set(v):
		sfx_enabled = v
		_save_settings()


func _ready() -> void:
	_load_settings()
	_intro_player.stream = load("res://assets/music/intro_music.ogg")
	_main_player.stream = load("res://assets/music/main_music.ogg")
	(_main_player.stream as AudioStreamOggVorbis).loop = true
	_apply_volume()
	_intro_player.play()


func _apply_volume() -> void:
	var db := linear_to_db(music_volume) if music_volume > 0.0 else -80.0
	if _intro_player:
		_intro_player.volume_db = db
	if _main_player:
		_main_player.volume_db = db


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
		if data.has("sfx_enabled"):
			sfx_enabled = bool(data["sfx_enabled"])


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"music_volume": music_volume, "sfx_enabled": sfx_enabled}))
	f.close()


func switch_scene(scene_path: String) -> void:
	# Switch from intro to main music when leaving main menu
	if _intro_player.playing:
		_intro_player.stop()
		_main_player.play()

	current_scene.queue_free()
	var next_scene: Node = load(scene_path).instantiate()
	$CurrentScene.add_child(next_scene)
	current_scene = next_scene
