class_name LayoutAdminPanelUI
extends RefCounted
## LayoutAdminPanelUI — 布局编辑器管理员面板
## 仅PC端显示，包含玩家大小、单个玩家大小、玩家旋转、椅子大小、椅子旋转、手牌旋转

signal save_requested
signal reset_requested

var _parent: Control
var _panel: PanelContainer
var _content: VBoxContainer
var _collapsed: bool = false
var _collapse_btn: Button
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# Slider/selector refs for sync
var _global_sliders: Dictionary = {}  # config_key -> HSlider
var _per_seat_sliders: Dictionary = {}  # config_key -> {slider, selector}

# Data-driven slider definitions
# [label, config_key, min, max, step, default]
const GLOBAL_DEFS: Array = [
	["玩家大小", "avatar_scale", 0.3, 3.0, 0.05, 1.0],
	["椅子大小", "chair_scale", 0.3, 3.0, 0.05, 1.0],
]

# [label, config_key, min, max, step, default]
const PER_SEAT_DEFS: Array = [
	["单个玩家大小", "avatar_per_seat_scale", 0.3, 3.0, 0.05, 1.0],
	["玩家旋转", "avatar_rotation", -180.0, 180.0, 1.0, 0.0],
	["椅子旋转", "chair_rotation", -180.0, 180.0, 1.0, 0.0],
	["手牌旋转", "hole_card_rotation", -180.0, 180.0, 1.0, 0.0],
]

const DEFAULT_9 := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


static func is_pc() -> bool:
	return OS.get_name() in ["Windows", "macOS", "Linux"]


func setup(parent: Control) -> RefCounted:
	_parent = parent
	return self


func build() -> PanelContainer:
	_panel = PanelContainer.new()
	_panel.name = "AdminPanel"
	_panel.add_theme_stylebox_override("panel", UiFactory.make_stylebox(Color(0.1, 0.1, 0.18, 0.92), 8, 12))
	_panel.z_index = 200
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_parent.add_child(_panel)
	_panel.position = Vector2(50, 50)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_build_title_bar(vbox)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	vbox.add_child(_content)

	return _panel


func _build_title_bar(parent_vbox: VBoxContainer) -> void:
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 58)
	title_bar.add_theme_constant_override("separation", 6)
	title_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	parent_vbox.add_child(title_bar)

	var drag_area := Control.new()
	drag_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drag_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_area.gui_input.connect(_on_title_input)
	title_bar.add_child(drag_area)

	var title := UiFactory.make_label("管理员面板  (拖动此处)", 28, UiFactory.LAYOUT_FONT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_area.add_child(title)

	_collapse_btn = Button.new()
	_collapse_btn.text = "▲"
	_collapse_btn.custom_minimum_size = Vector2(60, 58)
	_collapse_btn.add_theme_font_size_override("font_size", 28)
	_collapse_btn.pressed.connect(_on_collapse_pressed)
	title_bar.add_child(_collapse_btn)


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_offset = _panel.position - mb.global_position
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_panel.position = (event as InputEventMouseMotion).global_position + _drag_offset


func _on_collapse_pressed() -> void:
	_collapsed = not _collapsed
	_content.visible = not _collapsed
	_collapse_btn.text = "▼" if _collapsed else "▲"
	_panel.reset_size()


func build_sliders() -> void:
	# Global scale sliders
	for def in GLOBAL_DEFS:
		var label: String = def[0]
		var key: String = def[1]
		var k := key  # capture
		_global_sliders[key] = UiFactory.make_slider_row(_content, label, def[2], def[3],
			GameManager.layout_config.get(key, def[5]),
			func(v: float) -> void: GameManager.set_layout_scale(k, v), 160.0, def[4])

	# Per-seat sliders
	for def in PER_SEAT_DEFS:
		var label: String = def[0]
		var key: String = def[1]
		var default_val: float = def[5]
		var k := key
		var dv := default_val
		var values: Array = GameManager.layout_config.get(key, DEFAULT_9.duplicate())
		var result := UiFactory.make_per_seat_slider_row(_content, label, key, values, def[2], def[3], def[4], default_val,
			func(seat: int, v: float) -> void: GameManager.set_per_seat_value(k, seat, v))
		_per_seat_sliders[key] = result


func build_action_buttons() -> void:
	_content.add_child(UiFactory.make_layout_btn("保存到文件", Color(0.25, 0.55, 0.30), func() -> void: save_requested.emit()))
	_content.add_child(UiFactory.make_layout_btn("重置布局", Color(0.55, 0.25, 0.15), func() -> void: reset_requested.emit()))


func sync_sliders() -> void:
	for def in GLOBAL_DEFS:
		var key: String = def[1]
		if _global_sliders.has(key):
			_global_sliders[key].value = GameManager.layout_config.get(key, def[5])
	for def in PER_SEAT_DEFS:
		var key: String = def[1]
		var default_val: float = def[5]
		if _per_seat_sliders.has(key):
			var ps: Dictionary = _per_seat_sliders[key]
			var arr: Array = GameManager.layout_config.get(key, [])
			var idx: int = ps["selector"].selected
			ps["slider"].set_value_no_signal(arr[idx] if idx < arr.size() else default_val)


func set_visible(visible: bool) -> void:
	if _panel:
		_panel.visible = visible
