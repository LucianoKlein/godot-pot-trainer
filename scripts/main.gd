extends Node

const SceneSwitcherScript := preload("res://scripts/util/scene_switcher.gd")

@onready var current_scene: Node = $CurrentScene.get_child(0)
@onready var _intro_player: AudioStreamPlayer = $IntroMusic
@onready var _main_player: AudioStreamPlayer = $MainMusic
@onready var _sfx_player: AudioStreamPlayer = $SfxPlayer

var _transition_overlay: ColorRect
var _loading_bar_bg: ColorRect
var _loading_bar_fill: ColorRect
var _loading_label: Label
var _tip_label: Label
var _switcher: SceneSwitcher

const TIPS_EN := [
	"Deliberate practice is the key to mastery.",
	"Feeling tense? Try taking a deep breath.",
	"Every early mistake paves the way for future success.",
	"Stay focused — small details make big differences.",
	"Consistency beats intensity. Keep showing up.",
]
const TIPS_ZH := [
	"刻意练习是通往精通的关键。",
	"感到紧张？试着深呼吸，放松一下。",
	"前期的每个错误，都在为后面的成功铺路。",
	"保持专注——细节决定成败。",
	"坚持比强度更重要，持续就是胜利。",
]

const SFX_BUTTON := "res://assets/music/sounds_effect/button.ogg"
const SFX_SHUFFLE := "res://assets/music/sounds_effect/shuffle sounds.ogg"
const SFX_RIGHT := "res://assets/music/sounds_effect/right.ogg"
const SFX_WRONG := "res://assets/music/sounds_effect/wrong.ogg"


func play_sfx(path: String) -> void:
	if not sfx_enabled:
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

var sfx_enabled: bool = true:
	set(v):
		sfx_enabled = v
		_apply_sfx_volume()
		_save_settings()

var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_sfx_volume()
		_save_settings()


func _ready() -> void:
	if OS.get_name() in ["Android", "iOS"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

	_load_settings()
	_intro_player.stream = load("res://assets/music/intro_music.ogg")
	_main_player.stream = load("res://assets/music/main_music.ogg")
	(_main_player.stream as AudioStreamOggVorbis).loop = true
	_apply_volume()
	_apply_sfx_volume()
	_intro_player.play()

	# Persistent overlay for scene transitions (CanvasLayer so it's always on top)
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color(0.04, 0.03, 0.02, 1.0)
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.visible = false
	canvas.add_child(_transition_overlay)

	# Loading bar (screen center)
	var bar_w := 480
	var bar_h := 10
	_loading_bar_bg = ColorRect.new()
	_loading_bar_bg.color = Color(1, 1, 1, 0.15)
	_loading_bar_bg.custom_minimum_size = Vector2(bar_w, bar_h)
	_loading_bar_bg.set_anchors_preset(Control.PRESET_CENTER)
	_loading_bar_bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading_bar_bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading_bar_bg.offset_top = -bar_h / 2
	_loading_bar_bg.offset_bottom = bar_h / 2
	_loading_bar_bg.offset_left = -bar_w / 2
	_loading_bar_bg.offset_right = bar_w / 2
	_loading_bar_bg.visible = false
	canvas.add_child(_loading_bar_bg)

	_loading_bar_fill = ColorRect.new()
	_loading_bar_fill.color = Color(0.95, 0.75, 0.2, 1.0)
	_loading_bar_fill.size = Vector2(0, bar_h)
	_loading_bar_fill.position = Vector2.ZERO
	_loading_bar_bg.add_child(_loading_bar_fill)

	# Tip label (above progress bar)
	_tip_label = Label.new()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.add_theme_font_size_override("font_size", 20)
	_tip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_tip_label.set_anchors_preset(Control.PRESET_CENTER)
	_tip_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tip_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tip_label.offset_top = -bar_h / 2 - 40
	_tip_label.offset_bottom = -bar_h / 2 - 8
	_tip_label.offset_left = -bar_w / 2
	_tip_label.offset_right = bar_w / 2
	_tip_label.visible = false
	canvas.add_child(_tip_label)

	# "Loading..." label (below progress bar)
	_loading_label = Label.new()
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 14)
	_loading_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_loading_label.set_anchors_preset(Control.PRESET_CENTER)
	_loading_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading_label.offset_top = bar_h / 2 + 8
	_loading_label.offset_bottom = bar_h / 2 + 32
	_loading_label.offset_left = -bar_w / 2
	_loading_label.offset_right = bar_w / 2
	_loading_label.visible = false
	canvas.add_child(_loading_label)

	# Initialize scene switcher
	_switcher = SceneSwitcherScript.new().setup(self, _transition_overlay, _loading_bar_bg, _loading_bar_fill, _loading_label, _tip_label)

	# Background-load game table scene
	ResourceLoader.load_threaded_request("res://scenes/game/game_table.tscn")


func _apply_volume() -> void:
	var db := linear_to_db(music_volume) if music_volume > 0.0 else -80.0
	if _intro_player:
		_intro_player.volume_db = db
	if _main_player:
		_main_player.volume_db = db


func _apply_sfx_volume() -> void:
	if _sfx_player:
		var db := linear_to_db(sfx_volume) if sfx_volume > 0.0 else -80.0
		_sfx_player.volume_db = db


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
		if data.has("sfx_volume"):
			sfx_volume = float(data["sfx_volume"])
		if data.has("language"):
			GameManager.language = data["language"]


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"music_volume": music_volume,
		"sfx_enabled": sfx_enabled,
		"sfx_volume": sfx_volume,
		"language": GameManager.language,
	}))
	f.close()


func switch_scene(scene_path: String) -> void:
	_switcher.switch_scene(scene_path)


func switch_from_splash(scene_path: String) -> void:
	_switcher.switch_from_splash(scene_path)
