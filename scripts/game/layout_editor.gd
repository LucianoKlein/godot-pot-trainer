extends RefCounted
## Layout Editor — 布局编辑器协调器
## 使用子管理器组件协调布局编辑功能

const PinchZoomDetectorScript := preload("res://scripts/util/pinch_zoom_detector.gd")
const LayoutDragHandlerScript := preload("res://scripts/game/layout/layout_drag_handler.gd")
const LayoutPanelUIScript := preload("res://scripts/game/layout/layout_panel_ui.gd")
const LayoutPreviewManagerScript := preload("res://scripts/game/layout/layout_preview_manager.gd")
const LayoutVisibilityManagerScript := preload("res://scripts/game/layout/layout_visibility_manager.gd")

var _parent: Control
var _table_overlay: Control
var _control_panel: PanelContainer
var _back_to_menu_callback: Callable
var _layout_back_btn: Button
var _layout_btn: Button
var _refs: Dictionary  # All game UI element refs

# Sub-managers
var _drag_handler: RefCounted
var _panel_ui: RefCounted
var _preview_manager: RefCounted
var _visibility_manager: RefCounted
var _pinch_zoom: RefCounted

var is_dragging: bool:
	get: return _drag_handler.is_dragging if _drag_handler else false


func setup(parent: Control, table_overlay: Control, layout_btn: Button, control_panel: PanelContainer, back_to_menu_cb: Callable, refs: Dictionary) -> RefCounted:
	_parent = parent
	_table_overlay = table_overlay
	_layout_btn = layout_btn
	_control_panel = control_panel
	_back_to_menu_callback = back_to_menu_cb
	_refs = refs
	return self


func build() -> void:
	_drag_handler = LayoutDragHandlerScript.new().setup(_parent, _table_overlay)
	_drag_handler.drag_ended.connect(_on_drag_ended)
	_panel_ui = LayoutPanelUIScript.new().setup(_parent)
	_preview_manager = LayoutPreviewManagerScript.new().setup(_table_overlay)
	_visibility_manager = LayoutVisibilityManagerScript.new().setup(_refs)

	_pinch_zoom = PinchZoomDetectorScript.new()
	_pinch_zoom.zoom_changed.connect(_on_pinch_zoom)

	_panel_ui.build()
	_panel_ui.save_requested.connect(_on_save)
	_panel_ui.reset_requested.connect(_on_reset)
	_panel_ui.display_mode_changed.connect(_on_display_mode_changed)
	_panel_ui.blinds_mode_changed.connect(_on_blinds_mode_changed)

	var content: VBoxContainer = _panel_ui.get_content_container()
	_visibility_manager.build_select_all_checkbox(content)
	_panel_ui.build_sliders(_visibility_manager)
	_panel_ui.build_action_buttons()

	_layout_back_btn = _panel_ui.build_back_button(_back_to_menu_callback)
	_visibility_manager.visibility_changed.connect(_on_visibility_changed)


# =============================================================================
# PUBLIC API
# =============================================================================

func toggle() -> void:
	GameManager.toggle_layout_mode()
	var active: bool = GameManager.layout_mode
	_panel_ui.set_visible(active)
	_layout_back_btn.visible = active
	_control_panel.visible = not active

	var pot_chip_area = _refs.get("pot_chip_area")
	if pot_chip_area and is_instance_valid(pot_chip_area):
		pot_chip_area.is_editing = active
		pot_chip_area._rebuild()

	var chip_record = _refs.get("chip_record")
	if chip_record and is_instance_valid(chip_record):
		if active:
			chip_record.visible = true
			chip_record.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			chip_record.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mouse_mode: int = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	for av in _refs.get("avatars", []):
		av.mouse_filter = mouse_mode
	for ch in _refs.get("chairs", []):
		ch.mouse_filter = mouse_mode
	for ab in _refs.get("action_boxes", []):
		ab.mouse_filter = mouse_mode

	if active:
		_layout_btn.text = "退出布局"
		_refs.get("dealer_button").visible = false
		sync_sliders()
		_enable_drag()
		show_preview()
		_visibility_manager.select_all()
		_parent.gui_input.connect(_on_parent_input)
	else:
		GameManager.save_layout_to_file()
		_layout_btn.text = "布局"
		_refs.get("dealer_button").visible = true
		_disable_drag()
		hide_preview()
		_visibility_manager.restore_all_visibility()
		if _parent.gui_input.is_connected(_on_parent_input):
			_parent.gui_input.disconnect(_on_parent_input)
		_pinch_zoom.reset()


func on_layout_changed() -> void:
	if GameManager.layout_mode and not is_dragging:
		show_preview()


func rebuild_drag_connections() -> void:
	_disable_drag()
	_enable_drag()
	show_preview()


func sync_sliders() -> void:
	_panel_ui.sync_sliders()


func show_preview() -> void:
	_preview_manager.show_preview(_visibility_manager, _drag_handler)


func hide_preview() -> void:
	_preview_manager.hide_preview()


func apply_all_visibility() -> void:
	_visibility_manager.apply_all_visibility()


# =============================================================================
# INTERNAL — drag management
# =============================================================================

# element_key -> {drag_key: refs_key} mapping for drag registration
const DRAG_MAP: Dictionary = {
	"bet_labels": {"bets": "bet_labels"},
	"stack_labels": {"stacks": "stack_labels"},
	"player_chips": {
		"purple_stacks": "purple_stacks", "black_stacks": "black_stacks",
		"green_stacks": "green_stacks", "red_stacks_1": "red_stacks_1",
		"red_stacks_2": "red_stacks_2", "red_stacks_3": "red_stacks_3",
	},
	"bet_chips": {"bet_chips": "player_bet_chips"},
	"ordered_bet_chips": {"ordered_bet_chips": "ordered_bet_chips"},
	"pot_display": {"pot": "pot_display"},
	"pot_chips": {"pot_chips": "pot_chip_area"},
	"chip_record": {"chip_record": "chip_record"},
	"community_cards": {"community_cards": "community_cards_container"},
	"street_badge": {"street_badge": "street_badge"},
	"action_boxes": {"action_boxes": "action_boxes"},
}


func _enable_drag() -> void:
	_drag_handler.disable_drag()
	var nodes: Dictionary = {}
	nodes["seats"] = _refs.get("avatars", [])
	nodes["chairs"] = _refs.get("chairs", [])

	for element_key in DRAG_MAP:
		if not _visibility_manager.is_element_visible(element_key):
			continue
		for drag_key in DRAG_MAP[element_key]:
			var refs_key: String = DRAG_MAP[element_key][drag_key]
			var val = _refs.get(refs_key)
			if val != null:
				nodes[drag_key] = val

	_drag_handler.enable_drag(nodes)


func _disable_drag() -> void:
	_drag_handler.disable_drag()


func _enable_drag_for_element(element_key: String) -> void:
	if not GameManager.layout_mode or not DRAG_MAP.has(element_key):
		return
	for drag_key in DRAG_MAP[element_key]:
		var refs_key: String = DRAG_MAP[element_key][drag_key]
		var val = _refs.get(refs_key)
		if val != null:
			_drag_handler.enable_drag_for_element(drag_key, val)


func _disable_drag_for_element(element_key: String) -> void:
	if not GameManager.layout_mode or not DRAG_MAP.has(element_key):
		return
	var nodes_to_remove: Array[Node] = []
	for drag_key in DRAG_MAP[element_key]:
		var refs_key: String = DRAG_MAP[element_key][drag_key]
		var val = _refs.get(refs_key)
		if val is Array:
			for n in val:
				nodes_to_remove.append(n)
		elif val is Node:
			nodes_to_remove.append(val)
	_drag_handler.disable_drag_for_element(nodes_to_remove)


# =============================================================================
# Signal handlers
# =============================================================================

func _on_save() -> void:
	var success: bool = GameManager.save_layout_to_file()
	_show_toast("布局已保存" if success else "保存失败，请重试", success)


func _show_toast(text: String, is_success: bool) -> void:
	var toast := UiFactory.make_label(("✓ " if is_success else "✗ ") + text, 20, Color.WHITE)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bg_color := Color(0.15, 0.5, 0.25, 0.9) if is_success else Color(0.6, 0.2, 0.2, 0.9)
	toast.add_theme_stylebox_override("normal", UiFactory.make_stylebox(bg_color, 8, 12))
	toast.set_anchors_preset(Control.PRESET_CENTER)
	toast.offset_left = -80
	toast.offset_right = 80
	toast.offset_top = -20
	toast.offset_bottom = 20
	toast.z_index = 300
	_parent.add_child(toast)
	var tw := _parent.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)


func _on_reset() -> void:
	GameManager.reset_layout()
	sync_sliders()


func _on_drag_ended() -> void:
	GameManager.layout_changed.emit()


func _on_display_mode_changed(mode: String) -> void:
	_visibility_manager.apply_display_mode(mode)


func _on_blinds_mode_changed(mode: String) -> void:
	match mode:
		"1/2": GameManager.set_blinds(1, 2)
		"1/2/5": GameManager.set_blinds(1, 5)
		"5/10": GameManager.set_blinds(5, 10)
		_: GameManager.set_blinds(25, 50)
	GameManager.switch_layout_mode(mode)
	sync_sliders()
	GameManager.layout_changed.emit()


func _on_visibility_changed(element_key: String, _visible: bool) -> void:
	if not GameManager.layout_mode:
		return
	if element_key == "all":
		_disable_drag()
		_enable_drag()
		show_preview()
	else:
		if _visible:
			_enable_drag_for_element(element_key)
		else:
			_disable_drag_for_element(element_key)
		if element_key in ["hole_cards", "community_cards", "dealer_buttons", "answer_boxes"]:
			show_preview()


func _on_parent_input(event: InputEvent) -> void:
	_pinch_zoom.process_input(event)


func _on_pinch_zoom(zoom_factor: float) -> void:
	var active_slider: HSlider = _panel_ui.get_active_chip_slider()
	if not active_slider:
		return
	var new_value: float = clampf(active_slider.value * zoom_factor, active_slider.min_value, active_slider.max_value)
	if abs(new_value - active_slider.value) > 0.01:
		active_slider.value = new_value
