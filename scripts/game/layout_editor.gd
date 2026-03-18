extends RefCounted
## Layout Editor — 布局编辑器协调器
## 使用子管理器组件协调布局编辑功能

const PinchZoomDetector := preload("res://scripts/util/pinch_zoom_detector.gd")
const LayoutDragHandler := preload("res://scripts/game/layout/layout_drag_handler.gd")
const LayoutPanelUI := preload("res://scripts/game/layout/layout_panel_ui.gd")
const LayoutPreviewManager := preload("res://scripts/game/layout/layout_preview_manager.gd")
const LayoutVisibilityManager := preload("res://scripts/game/layout/layout_visibility_manager.gd")

var _parent: Control
var _table_overlay: Control
var _control_panel: PanelContainer
var _back_to_menu_callback: Callable
var _layout_back_btn: Button

# References to actual game UI elements (passed in from game_table)
var _avatars: Array[TextureRect]
var _chairs: Array[TextureRect]
var _bet_labels: Array[Label]
var _stack_labels: Array[Label]
var _dealer_button: Control
var _pot_display: VBoxContainer
var _community_cards_container: HBoxContainer
var _purple_stacks: Array[Node2D]
var _black_stacks: Array[Node2D]
var _green_stacks: Array[Node2D]
var _player_bet_chips: Array[Control]
var _ordered_bet_chips: Array[Node2D]
var _pot_chip_area: Control
var _chip_record: Control
var _action_boxes: Array[Label]

# Sub-managers
var _drag_handler: RefCounted  # LayoutDragHandler
var _panel_ui: RefCounted  # LayoutPanelUI
var _preview_manager: RefCounted  # LayoutPreviewManager
var _visibility_manager: RefCounted  # LayoutVisibilityManager

# Pinch-to-zoom support
var _pinch_zoom: RefCounted  # PinchZoomDetector

# Reference to the layout toggle button (owned by control panel, passed in)
var _layout_btn: Button

var is_dragging: bool:
	get: return _drag_handler.is_dragging if _drag_handler else false


func setup(parent: Control, table_overlay: Control, layout_btn: Button, control_panel: PanelContainer, back_to_menu_cb: Callable, refs: Dictionary) -> RefCounted:
	_parent = parent
	_table_overlay = table_overlay
	_layout_btn = layout_btn
	_control_panel = control_panel
	_back_to_menu_callback = back_to_menu_cb
	_avatars.assign(refs.get("avatars", []))
	_chairs.assign(refs.get("chairs", []))
	_bet_labels.assign(refs["bet_labels"])
	_stack_labels.assign(refs["stack_labels"])
	_dealer_button = refs["dealer_button"]
	_pot_display = refs["pot_display"]
	_community_cards_container = refs["community_cards_container"]
	_purple_stacks.assign(refs.get("purple_stacks", []))
	_black_stacks.assign(refs.get("black_stacks", []))
	_green_stacks.assign(refs.get("green_stacks", []))
	_player_bet_chips.assign(refs.get("player_bet_chips", []))
	_ordered_bet_chips.assign(refs.get("ordered_bet_chips", []))
	_pot_chip_area = refs.get("pot_chip_area", null)
	_chip_record = refs.get("chip_record", null)
	_action_boxes.assign(refs.get("action_boxes", []))
	return self


func build() -> void:
	# Initialize sub-managers
	_drag_handler = LayoutDragHandler.new().setup(_parent, _table_overlay)
	_drag_handler.drag_ended.connect(_on_drag_ended)
	_panel_ui = LayoutPanelUI.new().setup(_parent)
	_preview_manager = LayoutPreviewManager.new().setup(_table_overlay)
	_visibility_manager = LayoutVisibilityManager.new().setup({
		"bet_labels": _bet_labels,
		"stack_labels": _stack_labels,
		"dealer_button": _dealer_button,
		"pot_display": _pot_display,
		"community_cards_container": _community_cards_container,
		"purple_stacks": _purple_stacks,
		"black_stacks": _black_stacks,
		"green_stacks": _green_stacks,
		"player_bet_chips": _player_bet_chips,
		"ordered_bet_chips": _ordered_bet_chips,
		"pot_chip_area": _pot_chip_area,
		"chip_record": _chip_record,
		"action_boxes": _action_boxes,
	})

	# Initialize pinch-to-zoom detector
	_pinch_zoom = PinchZoomDetector.new()
	_pinch_zoom.zoom_changed.connect(_on_pinch_zoom)

	# Build panel UI
	_panel_ui.build()
	_panel_ui.save_requested.connect(_on_save)
	_panel_ui.reset_requested.connect(_on_reset)
	_panel_ui.display_mode_changed.connect(_on_display_mode_changed)

	# Build panel content
	var content: VBoxContainer = _panel_ui.get_content_container()
	_visibility_manager.build_select_all_checkbox(content)
	_panel_ui.build_sliders(_visibility_manager)
	_panel_ui.build_action_buttons()

	# Build back button
	_layout_back_btn = _panel_ui.build_back_button(_back_to_menu_callback)

	# Connect visibility manager signals
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

	# Toggle pot chip area editing mode
	if _pot_chip_area and is_instance_valid(_pot_chip_area):
		_pot_chip_area.is_editing = active
		_pot_chip_area._rebuild()

	# Show/hide chip record in layout mode
	if _chip_record and is_instance_valid(_chip_record):
		if active:
			_chip_record.visible = true
			_chip_record.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			_chip_record.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if active:
		_layout_btn.text = "退出布局"
		_dealer_button.visible = false
		# Enable mouse interaction on avatars and chairs for dragging
		for av in _avatars:
			av.mouse_filter = Control.MOUSE_FILTER_STOP
		for ch in _chairs:
			ch.mouse_filter = Control.MOUSE_FILTER_STOP
		# Enable mouse interaction on action boxes for dragging
		for ab in _action_boxes:
			ab.mouse_filter = Control.MOUSE_FILTER_STOP
		sync_sliders()
		_enable_drag()
		show_preview()
		# First select all, then apply display mode so chip/number visibility is correct
		_visibility_manager.select_all()
		_visibility_manager.apply_display_mode(_panel_ui.get_display_mode())
		# Enable pinch-to-zoom
		_parent.gui_input.connect(_on_parent_input)
	else:
		# Auto-save layout when exiting layout mode
		GameManager.save_layout_to_file()
		_layout_btn.text = "布局"
		_dealer_button.visible = true
		# Restore mouse filter on avatars and chairs
		for av in _avatars:
			av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ch in _chairs:
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Restore mouse filter on action boxes
		for ab in _action_boxes:
			ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_drag()
		hide_preview()
		_visibility_manager.restore_all_visibility()
		# Disable pinch-to-zoom
		if _parent.gui_input.is_connected(_on_parent_input):
			_parent.gui_input.disconnect(_on_parent_input)
		_pinch_zoom.reset()


func on_layout_changed() -> void:
	if GameManager.layout_mode and not is_dragging:
		show_preview()


func rebuild_drag_connections() -> void:
	_disable_drag()
	_enable_drag()
	# Re-show preview so that preview elements (hole cards, dealer buttons,
	# answer boxes, community cards) get re-registered as draggable
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

func _enable_drag() -> void:
	_drag_handler.disable_drag()

	var nodes: Dictionary = {}
	# Seats (avatars) and chairs are always draggable in layout mode
	nodes["seats"] = _avatars
	nodes["chairs"] = _chairs
	if _visibility_manager.is_element_visible("bet_labels"):
		nodes["bets"] = _bet_labels
	if _visibility_manager.is_element_visible("stack_labels"):
		nodes["stacks"] = _stack_labels
	if _visibility_manager.is_element_visible("player_chips"):
		nodes["purple_stacks"] = _purple_stacks
		nodes["black_stacks"] = _black_stacks
		nodes["green_stacks"] = _green_stacks
	if _visibility_manager.is_element_visible("bet_chips"):
		nodes["bet_chips"] = _player_bet_chips
	if _visibility_manager.is_element_visible("ordered_bet_chips"):
		nodes["ordered_bet_chips"] = _ordered_bet_chips
	if _visibility_manager.is_element_visible("pot_display"):
		nodes["pot"] = _pot_display
	if _visibility_manager.is_element_visible("pot_chips") and _pot_chip_area:
		nodes["pot_chips"] = _pot_chip_area
	if _visibility_manager.is_element_visible("chip_record") and _chip_record:
		nodes["chip_record"] = _chip_record
	if _visibility_manager.is_element_visible("community_cards"):
		nodes["community_cards"] = _community_cards_container
	if _visibility_manager.is_element_visible("action_boxes"):
		nodes["action_boxes"] = _action_boxes

	_drag_handler.enable_drag(nodes)


func _disable_drag() -> void:
	_drag_handler.disable_drag()


func _on_save() -> void:
	var success: bool = GameManager.save_layout_to_file()
	if success:
		_show_save_dialog("布局已保存")
	else:
		_show_save_dialog("保存失败，请重试")


func _show_save_dialog(text: String) -> void:
	var toast := Label.new()
	toast.text = "✓ " + text if "保存" in text else "✗ " + text
	toast.add_theme_font_size_override("font_size", 20)
	toast.add_theme_color_override("font_color", Color.WHITE)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.5, 0.25, 0.9) if "保存" in text else Color(0.6, 0.2, 0.2, 0.9)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(12)
	toast.add_theme_stylebox_override("normal", bg)
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
	# After drag ends, emit layout_changed to refresh dependent elements
	# (e.g., name_label, action_box positions relative to avatar)
	GameManager.layout_changed.emit()


func _on_display_mode_changed(mode: String) -> void:
	_visibility_manager.apply_display_mode(mode)


func _on_visibility_changed(element_key: String, visible: bool) -> void:
	if element_key == "all":
		# Rebuild all drag connections and preview
		if GameManager.layout_mode:
			_disable_drag()
			_enable_drag()
			show_preview()
	else:
		# Handle individual element visibility change
		if GameManager.layout_mode:
			if visible:
				_enable_drag_for_element(element_key)
			else:
				_disable_drag_for_element(element_key)
			# Rebuild preview for elements that use preview nodes
			if element_key in ["hole_cards", "community_cards", "dealer_buttons", "answer_boxes"]:
				show_preview()


func _enable_drag_for_element(element_key: String) -> void:
	if not GameManager.layout_mode:
		return
	match element_key:
		"bet_labels":
			_drag_handler.enable_drag_for_element("bets", _bet_labels)
		"stack_labels":
			_drag_handler.enable_drag_for_element("stacks", _stack_labels)
		"player_chips":
			_drag_handler.enable_drag_for_element("purple_stacks", _purple_stacks)
			_drag_handler.enable_drag_for_element("black_stacks", _black_stacks)
			_drag_handler.enable_drag_for_element("green_stacks", _green_stacks)
		"bet_chips":
			_drag_handler.enable_drag_for_element("bet_chips", _player_bet_chips)
		"ordered_bet_chips":
			_drag_handler.enable_drag_for_element("ordered_bet_chips", _ordered_bet_chips)
		"pot_display":
			_drag_handler.enable_drag_for_element("pot", _pot_display)
		"pot_chips":
			if _pot_chip_area:
				_drag_handler.enable_drag_for_element("pot_chips", _pot_chip_area)
		"chip_record":
			if _chip_record:
				_drag_handler.enable_drag_for_element("chip_record", _chip_record)
		"community_cards":
			_drag_handler.enable_drag_for_element("community_cards", _community_cards_container)
		"action_boxes":
			_drag_handler.enable_drag_for_element("action_boxes", _action_boxes)


func _disable_drag_for_element(element_key: String) -> void:
	if not GameManager.layout_mode:
		return
	var nodes_to_remove: Array[Node] = []
	match element_key:
		"bet_labels":
			for l in _bet_labels:
				nodes_to_remove.append(l)
		"stack_labels":
			for l in _stack_labels:
				nodes_to_remove.append(l)
		"player_chips":
			for s in _purple_stacks:
				nodes_to_remove.append(s)
			for s in _black_stacks:
				nodes_to_remove.append(s)
			for s in _green_stacks:
				nodes_to_remove.append(s)
		"bet_chips":
			for b in _player_bet_chips:
				nodes_to_remove.append(b)
		"ordered_bet_chips":
			for obc in _ordered_bet_chips:
				nodes_to_remove.append(obc)
		"pot_display":
			nodes_to_remove.append(_pot_display)
		"pot_chips":
			if _pot_chip_area:
				nodes_to_remove.append(_pot_chip_area)
		"chip_record":
			if _chip_record:
				nodes_to_remove.append(_chip_record)
		"community_cards":
			nodes_to_remove.append(_community_cards_container)
		"action_boxes":
			for ab in _action_boxes:
				nodes_to_remove.append(ab)

	_drag_handler.disable_drag_for_element(nodes_to_remove)


func _on_parent_input(event: InputEvent) -> void:
	if _pinch_zoom.process_input(event):
		# Pinch gesture detected, adjust active chip slider
		var active_slider: HSlider = _panel_ui.get_active_chip_slider()
		if active_slider:
			pass  # Slider will be adjusted in _on_pinch_zoom


func _on_pinch_zoom(zoom_factor: float) -> void:
	var active_slider: HSlider = _panel_ui.get_active_chip_slider()
	if not active_slider:
		return

	var current_value: float = active_slider.value
	var new_value: float = clampf(current_value * zoom_factor, active_slider.min_value, active_slider.max_value)

	if abs(new_value - current_value) > 0.01:
		active_slider.value = new_value
