extends RefCounted
## Layout Editor — handles, sliders, preview, export/import for the table layout system.

const CardDisplayScene := preload("res://scenes/game/components/card_display.tscn")

const HANDLE_DEFS := [
	["seats", 0, "S1", Color(0.2, 0.6, 0.9)],
	["seats", 1, "S2", Color(0.2, 0.6, 0.9)],
	["seats", 2, "S3", Color(0.2, 0.6, 0.9)],
	["seats", 3, "S4", Color(0.2, 0.6, 0.9)],
	["seats", 4, "S5", Color(0.2, 0.6, 0.9)],
	["seats", 5, "S6", Color(0.2, 0.6, 0.9)],
	["seats", 6, "S7", Color(0.2, 0.6, 0.9)],
	["seats", 7, "S8", Color(0.2, 0.6, 0.9)],
	["seats", 8, "S9", Color(0.2, 0.6, 0.9)],
	["cards", 0, "C1", Color(0.9, 0.3, 0.2)],
	["cards", 1, "C2", Color(0.9, 0.3, 0.2)],
	["cards", 2, "C3", Color(0.9, 0.3, 0.2)],
	["cards", 3, "C4", Color(0.9, 0.3, 0.2)],
	["cards", 4, "C5", Color(0.9, 0.3, 0.2)],
	["cards", 5, "C6", Color(0.9, 0.3, 0.2)],
	["cards", 6, "C7", Color(0.9, 0.3, 0.2)],
	["cards", 7, "C8", Color(0.9, 0.3, 0.2)],
	["cards", 8, "C9", Color(0.9, 0.3, 0.2)],
	["stacks", 0, "$1", Color(0.2, 0.8, 0.4)],
	["stacks", 1, "$2", Color(0.2, 0.8, 0.4)],
	["stacks", 2, "$3", Color(0.2, 0.8, 0.4)],
	["stacks", 3, "$4", Color(0.2, 0.8, 0.4)],
	["stacks", 4, "$5", Color(0.2, 0.8, 0.4)],
	["stacks", 5, "$6", Color(0.2, 0.8, 0.4)],
	["stacks", 6, "$7", Color(0.2, 0.8, 0.4)],
	["stacks", 7, "$8", Color(0.2, 0.8, 0.4)],
	["stacks", 8, "$9", Color(0.2, 0.8, 0.4)],
	["bets", 0, "B1", Color(0.95, 0.77, 0.06)],
	["bets", 1, "B2", Color(0.95, 0.77, 0.06)],
	["bets", 2, "B3", Color(0.95, 0.77, 0.06)],
	["bets", 3, "B4", Color(0.95, 0.77, 0.06)],
	["bets", 4, "B5", Color(0.95, 0.77, 0.06)],
	["bets", 5, "B6", Color(0.95, 0.77, 0.06)],
	["bets", 6, "B7", Color(0.95, 0.77, 0.06)],
	["bets", 7, "B8", Color(0.95, 0.77, 0.06)],
	["bets", 8, "B9", Color(0.95, 0.77, 0.06)],
	["dealer_buttons", 0, "D1", Color.WHITE],
	["dealer_buttons", 1, "D2", Color.WHITE],
	["dealer_buttons", 2, "D3", Color.WHITE],
	["dealer_buttons", 3, "D4", Color.WHITE],
	["dealer_buttons", 4, "D5", Color.WHITE],
	["dealer_buttons", 5, "D6", Color.WHITE],
	["dealer_buttons", 6, "D7", Color.WHITE],
	["dealer_buttons", 7, "D8", Color.WHITE],
	["dealer_buttons", 8, "D9", Color.WHITE],
	["chairs", 0, "Ch1", Color(0.6, 0.4, 0.2)],
	["chairs", 1, "Ch2", Color(0.6, 0.4, 0.2)],
	["chairs", 2, "Ch3", Color(0.6, 0.4, 0.2)],
	["chairs", 3, "Ch4", Color(0.6, 0.4, 0.2)],
	["chairs", 4, "Ch5", Color(0.6, 0.4, 0.2)],
	["chairs", 5, "Ch6", Color(0.6, 0.4, 0.2)],
	["chairs", 6, "Ch7", Color(0.6, 0.4, 0.2)],
	["chairs", 7, "Ch8", Color(0.6, 0.4, 0.2)],
	["chairs", 8, "Ch9", Color(0.6, 0.4, 0.2)],
	["pot", -1, "POT", Color(0.6, 0.35, 0.7)],
	["muck", -1, "MUCK", Color(0.6, 0.35, 0.7)],
	["community_cards", -1, "CC", Color(0.6, 0.35, 0.7)],
	["pitch_hand", -1, "PH", Color(0.9, 0.6, 0.2)],
]

var _parent: Control
var _table_overlay: Control

# UI nodes
var _layout_panel: PanelContainer
var _layout_handles_container: Control
var _layout_handles: Array[Control] = []
var _avatar_scale_slider: HSlider
var _dealer_scale_slider: HSlider
var _hole_card_scale_slider: HSlider
var _hole_card_gap_slider: HSlider
var _community_card_scale_slider: HSlider
var _muck_card_scale_slider: HSlider
var _pitch_hand_scale_slider: HSlider
var _pitch_hand_rotation_slider: HSlider
var _dragging_handle: Control = null
var _handle_drag_offset: Vector2 = Vector2.ZERO
var _dragging_layout_panel: bool = false
var _layout_panel_drag_offset: Vector2 = Vector2.ZERO
var _preview_cards: Array[Control] = []

# Reference to the layout toggle button (owned by control panel, passed in)
var _layout_btn: Button


func _init(parent: Control, table_overlay: Control, layout_btn: Button) -> void:
	_parent = parent
	_table_overlay = table_overlay
	_layout_btn = layout_btn


func build() -> void:
	# Layout handles container (hidden by default)
	_layout_handles_container = Control.new()
	_layout_handles_container.name = "LayoutHandles"
	_layout_handles_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout_handles_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_handles_container.z_index = 150
	_layout_handles_container.visible = false
	_parent.add_child(_layout_handles_container)

	# Create handles
	for def in HANDLE_DEFS:
		_create_handle(def[0], def[1], def[2], def[3])

	# Layout panel (draggable)
	_layout_panel = PanelContainer.new()
	_layout_panel.name = "LayoutPanel"
	var lp_style := StyleBoxFlat.new()
	lp_style.bg_color = Color(0.1, 0.1, 0.18, 0.92)
	lp_style.set_corner_radius_all(8)
	lp_style.set_content_margin_all(12)
	_layout_panel.add_theme_stylebox_override("panel", lp_style)
	_layout_panel.z_index = 200
	_layout_panel.visible = false
	_layout_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_parent.add_child(_layout_panel)
	_layout_panel.position = Vector2(1550, 50)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_layout_panel.add_child(vbox)

	# Draggable title bar
	var title_bar := Control.new()
	title_bar.custom_minimum_size = Vector2(0, 28)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_input)
	vbox.add_child(title_bar)
	var title := _make_label("Layout Editor  (drag here)", 14, Color(0.8, 0.8, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_bar.add_child(title)

	# Sliders
	_avatar_scale_slider = _make_scale_row(vbox, "Avatar", 0.3, 3.0,
		GameManager.layout_config.get("avatar_scale", 1.0),
		func(v: float) -> void: GameManager.set_avatar_scale(v))

	_dealer_scale_slider = _make_scale_row(vbox, "Dealer Btn", 0.5, 3.0,
		GameManager.layout_config.get("dealer_button_scale", 1.0),
		func(v: float) -> void: GameManager.set_dealer_button_scale(v))

	_hole_card_scale_slider = _make_scale_row(vbox, "Hole Cards", 0.3, 3.0,
		GameManager.layout_config.get("hole_card_scale", 1.0),
		func(v: float) -> void: GameManager.set_hole_card_scale(v))

	_hole_card_gap_slider = _make_scale_row(vbox, "Card Gap", 0.0, 1.5,
		GameManager.layout_config.get("hole_card_gap", 0.6),
		func(v: float) -> void: GameManager.set_hole_card_gap(v))

	_community_card_scale_slider = _make_scale_row(vbox, "Comm Cards", 0.3, 3.0,
		GameManager.layout_config.get("community_card_scale", 1.0),
		func(v: float) -> void: GameManager.set_community_card_scale(v))

	_muck_card_scale_slider = _make_scale_row(vbox, "Muck Cards", 0.3, 3.0,
		GameManager.layout_config.get("muck_card_scale", 1.0),
		func(v: float) -> void: GameManager.set_muck_card_scale(v))

	_pitch_hand_scale_slider = _make_scale_row(vbox, "Pitch Hand", 0.3, 3.0,
		GameManager.layout_config.get("pitch_hand_scale", 1.0),
		func(v: float) -> void: GameManager.set_pitch_hand_scale(v))

	_pitch_hand_rotation_slider = _make_scale_row(vbox, "PH Rotation", -180.0, 180.0,
		GameManager.layout_config.get("pitch_hand_rotation", 0.0),
		func(v: float) -> void: GameManager.set_pitch_hand_rotation(v))
	_pitch_hand_rotation_slider.step = 1.0

	# Buttons
	var export_btn := _make_btn("Export to Console", Color(0.3, 0.5, 0.8), _on_export)
	vbox.add_child(export_btn)
	var save_btn := _make_btn("Save to File", Color(0.2, 0.7, 0.3), _on_save)
	vbox.add_child(save_btn)
	var load_btn := _make_btn("Load from File", Color(0.6, 0.5, 0.2), _on_load)
	vbox.add_child(load_btn)
	var reset_btn := _make_btn("Reset Layout", Color(0.7, 0.2, 0.2), _on_reset)
	vbox.add_child(reset_btn)
	var exit_btn := _make_btn("Exit Layout", Color(0.5, 0.5, 0.5), func() -> void: toggle())
	vbox.add_child(exit_btn)


# =============================================================================
# PUBLIC API
# =============================================================================

func toggle() -> void:
	GameManager.toggle_layout_mode()
	var active := GameManager.layout_mode
	_layout_handles_container.visible = active
	_layout_panel.visible = active
	if active:
		_layout_btn.text = "Exit Layout"
		sync_sliders()
		update_handles()
		show_preview()
	else:
		_layout_btn.text = "Layout"
		hide_preview()


func on_layout_changed() -> void:
	if GameManager.layout_mode:
		update_handles()
		show_preview()


func sync_sliders() -> void:
	_avatar_scale_slider.value = GameManager.layout_config.get("avatar_scale", 1.0)
	_dealer_scale_slider.value = GameManager.layout_config.get("dealer_button_scale", 1.0)
	_hole_card_scale_slider.value = GameManager.layout_config.get("hole_card_scale", 1.0)
	_hole_card_gap_slider.value = GameManager.layout_config.get("hole_card_gap", 0.6)
	_community_card_scale_slider.value = GameManager.layout_config.get("community_card_scale", 1.0)
	_muck_card_scale_slider.value = GameManager.layout_config.get("muck_card_scale", 1.0)
	_pitch_hand_scale_slider.value = GameManager.layout_config.get("pitch_hand_scale", 1.0)
	_pitch_hand_rotation_slider.value = GameManager.layout_config.get("pitch_hand_rotation", 0.0)


func update_handles() -> void:
	var db_scale: float = GameManager.layout_config.get("dealer_button_scale", 1.0)
	var db_handle_size := Vector2(24, 24) * db_scale
	for handle in _layout_handles:
		var category: String = handle.get_meta("category")
		var idx: int = handle.get_meta("index")
		var pos: Vector2
		if idx >= 0:
			pos = GameManager.get_layout_position_px(category, idx)
		else:
			pos = GameManager.get_layout_position_px(category)
		if category == "dealer_buttons":
			handle.custom_minimum_size = db_handle_size
			handle.size = db_handle_size
			handle.position = pos - db_handle_size / 2
			var bg_label: Label = handle.get_child(0)
			bg_label.custom_minimum_size = db_handle_size
			bg_label.size = db_handle_size
			var bg_style: StyleBoxFlat = bg_label.get_theme_stylebox("normal")
			bg_style.set_corner_radius_all(int(db_handle_size.x / 2))
		else:
			handle.position = pos - Vector2(12, 12)


func show_preview() -> void:
	hide_preview()
	var hc_scale: float = GameManager.layout_config.get("hole_card_scale", 1.0)
	var cc_scale: float = GameManager.layout_config.get("community_card_scale", 1.0)
	var hc_size := Vector2(48, 66) * hc_scale
	var cc_size := Vector2(48, 66) * cc_scale
	var hc_gap: float = GameManager.layout_config.get("hole_card_gap", 0.6)

	# Preview hole cards: 2 face-down cards per seat
	for i in range(9):
		var card_pos: Vector2 = GameManager.get_layout_position_px("cards", i)
		var total_w: float = hc_size.x + hc_size.x * hc_gap
		var start_x: float = card_pos.x - total_w / 2
		for c in range(2):
			var card_node: TextureRect = CardDisplayScene.instantiate()
			card_node.custom_minimum_size = hc_size
			card_node.size = hc_size
			card_node.position = Vector2(start_x + c * hc_size.x * hc_gap, card_pos.y - hc_size.y / 2)
			card_node.z_index = 5
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_table_overlay.add_child(card_node)
			card_node.set_face_down()
			_preview_cards.append(card_node)

	# Preview community cards: 5 face-up sample cards
	var sample_cards: Array[CardData] = [
		CardData.new(CardData.Suit.SPADES, CardData.Rank.ACE, true),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.KING, true),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.QUEEN, true),
		CardData.new(CardData.Suit.CLUBS, CardData.Rank.JACK, true),
		CardData.new(CardData.Suit.SPADES, CardData.Rank.TEN, true),
	]
	var comm_pos: Vector2 = GameManager.get_layout_position_px("community_cards", -1)
	for c in range(5):
		var card_node: TextureRect = CardDisplayScene.instantiate()
		card_node.custom_minimum_size = cc_size
		card_node.size = cc_size
		card_node.position = comm_pos - Vector2(cc_size.x * 2.5 + 8, cc_size.y / 2) + Vector2(c * (cc_size.x + 4), 0)
		card_node.z_index = 5
		card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_table_overlay.add_child(card_node)
		card_node.set_card(sample_cards[c])
		_preview_cards.append(card_node)


func hide_preview() -> void:
	for card in _preview_cards:
		if is_instance_valid(card):
			card.queue_free()
	_preview_cards.clear()


# =============================================================================
# INTERNAL
# =============================================================================

func _create_handle(category: String, idx: int, label_text: String, color: Color) -> void:
	var handle := Control.new()
	handle.custom_minimum_size = Vector2(24, 24)
	handle.size = Vector2(24, 24)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.set_meta("category", category)
	handle.set_meta("index", idx)

	var bg := Label.new()
	bg.text = label_text
	bg.add_theme_font_size_override("font_size", 9)
	bg.add_theme_color_override("font_color", Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE)
	bg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = color
	bg_style.set_corner_radius_all(12)
	bg.add_theme_stylebox_override("normal", bg_style)
	handle.add_child(bg)

	handle.gui_input.connect(_on_handle_input.bind(handle))

	var pos: Vector2
	if idx >= 0:
		pos = GameManager.get_layout_position_px(category, idx)
	else:
		pos = GameManager.get_layout_position_px(category)
	handle.position = pos - Vector2(12, 12)

	_layout_handles_container.add_child(handle)
	_layout_handles.append(handle)


func _on_handle_input(event: InputEvent, handle: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging_handle = handle
				_handle_drag_offset = handle.position - mb.global_position
			else:
				_dragging_handle = null
	elif event is InputEventMouseMotion and _dragging_handle == handle:
		var new_pos: Vector2 = (event as InputEventMouseMotion).global_position + _handle_drag_offset
		handle.position = new_pos
		var center := new_pos + Vector2(12, 12)
		var pct := TableLayout.px_to_pct(center)
		var category: String = handle.get_meta("category")
		var idx: int = handle.get_meta("index")
		GameManager.update_layout_position(category, idx, pct.x, pct.y)


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging_layout_panel = true
				_layout_panel_drag_offset = _layout_panel.position - mb.global_position
			else:
				_dragging_layout_panel = false
	elif event is InputEventMouseMotion and _dragging_layout_panel:
		_layout_panel.position = (event as InputEventMouseMotion).global_position + _layout_panel_drag_offset


func _on_export() -> void:
	var json := GameManager.export_layout()
	print("")
	print("========== LAYOUT EXPORT ==========")
	print(json)
	print("====================================")
	print("")


func _on_save() -> void:
	GameManager.save_layout_to_file()


func _on_load() -> void:
	GameManager.load_layout_from_file()
	sync_sliders()


func _on_reset() -> void:
	GameManager.reset_layout()
	sync_sliders()


func _make_scale_row(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, initial: float, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var lbl := _make_label(label_text, 12, Color(0.7, 0.7, 0.7))
	lbl.custom_minimum_size.x = 80
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size.x = 120
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return slider


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_btn(text: String, color: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.15)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(callback)
	return btn
