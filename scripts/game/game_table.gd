extends Control

const CardDisplayScene := preload("res://scenes/game/components/card_display.tscn")
const OutlineShader := preload("res://assets/shaders/outline.gdshader")
const LayoutEditor := preload("res://scripts/game/layout_editor.gd")

# --- Node references ---
var _bg: TextureRect
var _chairs: Array[TextureRect] = []
var _table_overlay: Control

# --- Control Panel ---
var _control_panel: PanelContainer
var _new_hand_btn: Button
var _reset_btn: Button
var _move_dealer_btn: Button
var _undo_btn: Button
var _out_of_turn_check: CheckBox
var _show_action_check: CheckBox
var _show_aggressor_check: CheckBox
var _game_mode_option: OptionButton
var _blinds_option: OptionButton

# --- Per-seat UI (arrays of 9) ---
var _name_labels: Array[Label] = []
var _seat_badges: Array[Label] = []
var _fold_labels: Array[Label] = []
var _action_indicators: Array[PanelContainer] = []
var _aggressor_indicators: Array[PanelContainer] = []
var _stack_labels: Array[Label] = []
var _bet_labels: Array[Label] = []
var _dealer_button: Control
var _dealer_tween: Tween

# --- Player avatars ---
var _avatars: Array[TextureRect] = []

# --- Table center ---
var _pot_display: VBoxContainer
var _pot_amount_label: Label
var _community_cards_container: HBoxContainer
var _muck_pile: Control
var _muck_count_label: Label
var _street_badge: Label
var _last_action_label: Label

# --- Hand cards ---
var _card_slots: Array[Control] = []
var _arrived_cards: Dictionary = {}

# --- Pitch phase ---
var _pitch_hand: TextureRect
var _pitch_zones: Array[Control] = []
var _pitch_remaining_label: Label
var _auto_pitch_btn: Button
var _auto_pitch_timer: Timer
var _mispitch_cards: Array[TextureRect] = []

# --- Misdeal ---
var _misdeal_x: Button
var _misdeal_x_tween: Tween
var _misdeal_menu: PanelContainer

# --- Context menu ---
var _context_overlay: Control
var _click_catcher: Control
var _context_menu: PanelContainer
var _context_menu_vbox: VBoxContainer

# --- Raise dialog ---
var _raise_overlay: Control
var _raise_title: Label
var _raise_info: Label
var _raise_input: LineEdit
var _raise_confirm_btn: Button
var _raise_cancel_btn: Button

# --- Out-of-turn warning ---
var _oot_warning: Control
var _oot_tween: Tween
var _oot_menu: PanelContainer

# --- Action arrow ---
var _action_arrow: Control
var _action_arrow_tween: Tween

# --- Layout editor ---
var _layout_btn: Button
var _layout_editor: RefCounted  # LayoutEditor


func _ready() -> void:
	_bg = $Background
	for i in range(1, 10):
		_chairs.append(get_node("Chair%d" % i) as TextureRect)
	GameManager.init_game()
	_build_table_overlay()
	_build_avatars()
	_build_seat_ui()
	_build_dealer_button()
	_build_table_center()
	_build_card_slots()
	_build_pitch_ui()
	_build_misdeal_overlay()
	_build_context_menu()
	_build_raise_dialog()
	_build_oot_warning()
	_build_action_arrow()
	_build_control_panel()
	_layout_editor = LayoutEditor.new(self, _table_overlay, _layout_btn)
	_layout_editor.build()
	_connect_signals()
	GameManager.load_layout_from_file()
	_refresh_all()


func _build_table_overlay() -> void:
	_table_overlay = Control.new()
	_table_overlay.name = "TableOverlay"
	_table_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_table_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_table_overlay)


# =============================================================================
# PLAYER AVATARS (draggable)
# =============================================================================

func _build_avatars() -> void:
	for i in range(9):
		var avatar := TextureRect.new()
		avatar.name = "Avatar%d" % i
		avatar.texture = load("res://assets/players/player %d.png" % (i + 1))
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.custom_minimum_size = Vector2(70, 70)
		avatar.size = Vector2(70, 70)
		avatar.mouse_filter = Control.MOUSE_FILTER_STOP
		# Outline shader for current player highlight
		var mat := ShaderMaterial.new()
		mat.shader = OutlineShader
		mat.set_shader_parameter("enabled", false)
		mat.set_shader_parameter("outline_color", Color(1.0, 0.84, 0.0, 1.0))
		mat.set_shader_parameter("outline_width", 20.0)
		avatar.material = mat
		var seat_pos: Vector2 = GameManager.get_layout_position_px("seats", i)
		avatar.position = seat_pos - Vector2(35, 55)
		var idx := i
		avatar.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameManager.open_context_menu(GameManager.players[idx].id)
		)
		_table_overlay.add_child(avatar)
		_avatars.append(avatar)

func _build_seat_ui() -> void:
	for i in range(9):
		var seat_pos: Vector2 = GameManager.get_layout_position_px("seats", i)
		var stack_pos: Vector2 = GameManager.get_layout_position_px("stacks", i)
		var bet_pos: Vector2 = GameManager.get_layout_position_px("bets", i)

		# Name label (clickable)
		var name_lbl := _make_label(GameManager.players[i].player_name, 14, Color.WHITE)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		var name_bg := StyleBoxFlat.new()
		name_bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
		name_bg.set_content_margin_all(4)
		name_bg.set_corner_radius_all(3)
		name_lbl.add_theme_stylebox_override("normal", name_bg)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = seat_pos - Vector2(40, 10)
		name_lbl.custom_minimum_size = Vector2(80, 0)
		var idx := i
		name_lbl.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameManager.open_context_menu(GameManager.players[idx].id)
		)
		_table_overlay.add_child(name_lbl)
		_name_labels.append(name_lbl)

		# Seat badge
		var badge := _make_label("#%d" % (i + 1), 11, Color.WHITE)
		var badge_bg := StyleBoxFlat.new()
		badge_bg.bg_color = Color(0.9, 0.5, 0.1)
		badge_bg.set_corner_radius_all(10)
		badge_bg.set_content_margin_all(2)
		badge.add_theme_stylebox_override("normal", badge_bg)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.position = seat_pos - Vector2(52, 10)
		badge.custom_minimum_size = Vector2(22, 0)
		_table_overlay.add_child(badge)
		_seat_badges.append(badge)

		# Fold label
		var fold_lbl := _make_label("FOLD", 13, Color(1, 0.2, 0.2))
		fold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fold_lbl.position = seat_pos - Vector2(25, -14)
		fold_lbl.visible = false
		_table_overlay.add_child(fold_lbl)
		_fold_labels.append(fold_lbl)

		# Action indicator
		var action_ind := PanelContainer.new()
		var action_style := StyleBoxFlat.new()
		action_style.bg_color = Color(0.8, 0.15, 0.15)
		action_style.set_corner_radius_all(3)
		action_style.set_content_margin_all(3)
		action_ind.add_theme_stylebox_override("panel", action_style)
		var action_lbl := Label.new()
		action_lbl.text = "Action"
		action_lbl.add_theme_font_size_override("font_size", 11)
		action_lbl.add_theme_color_override("font_color", Color.WHITE)
		action_ind.add_child(action_lbl)
		action_ind.position = seat_pos - Vector2(28, 28)
		action_ind.visible = false
		_table_overlay.add_child(action_ind)
		_action_indicators.append(action_ind)

		# Aggressor indicator
		var agg_ind := PanelContainer.new()
		var agg_style := StyleBoxFlat.new()
		agg_style.bg_color = Color(0.9, 0.55, 0.1)
		agg_style.set_corner_radius_all(3)
		agg_style.set_content_margin_all(3)
		agg_ind.add_theme_stylebox_override("panel", agg_style)
		var agg_lbl := Label.new()
		agg_lbl.text = "Aggressor"
		agg_lbl.add_theme_font_size_override("font_size", 11)
		agg_lbl.add_theme_color_override("font_color", Color.WHITE)
		agg_ind.add_child(agg_lbl)
		agg_ind.position = seat_pos - Vector2(35, 44)
		agg_ind.visible = false
		_table_overlay.add_child(agg_ind)
		_aggressor_indicators.append(agg_ind)

		# Stack label
		var stack_lbl := _make_label("$%d" % GameManager.players[i].chips, 13, Color(0.3, 0.9, 0.3))
		var stack_bg := StyleBoxFlat.new()
		stack_bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
		stack_bg.set_content_margin_all(3)
		stack_bg.set_corner_radius_all(3)
		stack_lbl.add_theme_stylebox_override("normal", stack_bg)
		stack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack_lbl.position = stack_pos - Vector2(30, 8)
		stack_lbl.custom_minimum_size = Vector2(60, 0)
		_table_overlay.add_child(stack_lbl)
		_stack_labels.append(stack_lbl)

		# Bet label
		var bet_lbl := _make_label("", 13, Color(0.95, 0.82, 0.2))
		var bet_bg := StyleBoxFlat.new()
		bet_bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
		bet_bg.set_content_margin_all(3)
		bet_bg.set_corner_radius_all(3)
		bet_lbl.add_theme_stylebox_override("normal", bet_bg)
		bet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bet_lbl.position = bet_pos - Vector2(25, 8)
		bet_lbl.custom_minimum_size = Vector2(50, 0)
		bet_lbl.visible = false
		_table_overlay.add_child(bet_lbl)
		_bet_labels.append(bet_lbl)


func _build_dealer_button() -> void:
	_dealer_button = Control.new()
	_dealer_button.custom_minimum_size = Vector2(26, 26)
	_dealer_button.size = Vector2(26, 26)
	var d_label := Label.new()
	d_label.text = "D"
	d_label.add_theme_font_size_override("font_size", 14)
	d_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.2))
	d_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	d_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	var d_bg := StyleBoxFlat.new()
	d_bg.bg_color = Color.WHITE
	d_bg.set_corner_radius_all(13)
	d_bg.set_content_margin_all(0)
	d_bg.border_color = Color.BLACK
	d_bg.set_border_width_all(2)
	d_label.add_theme_stylebox_override("normal", d_bg)
	_dealer_button.add_child(d_label)
	var pos: Vector2 = GameManager.get_layout_position_px("dealer_buttons", GameManager.dealer_index)
	_dealer_button.position = pos - Vector2(13, 13)
	_table_overlay.add_child(_dealer_button)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


# =============================================================================
# STEP 3: TABLE CENTER UI
# =============================================================================

func _build_table_center() -> void:
	var pot_pos: Vector2 = GameManager.get_layout_position_px("pot", -1)
	var comm_pos: Vector2 = GameManager.get_layout_position_px("community_cards", -1)
	var muck_pos: Vector2 = GameManager.get_layout_position_px("muck", -1)

	# Pot display
	_pot_display = VBoxContainer.new()
	_pot_display.alignment = BoxContainer.ALIGNMENT_CENTER
	var pot_title := _make_label("POT", 12, Color(0.95, 0.77, 0.06))
	pot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pot_display.add_child(pot_title)
	_pot_amount_label = _make_label("$0", 18, Color(0.95, 0.77, 0.06))
	_pot_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pot_display.add_child(_pot_amount_label)
	_pot_display.position = pot_pos - Vector2(30, 20)
	_table_overlay.add_child(_pot_display)

	# Community cards
	_community_cards_container = HBoxContainer.new()
	_community_cards_container.add_theme_constant_override("separation", 4)
	_community_cards_container.position = comm_pos - Vector2(130, 33)
	_table_overlay.add_child(_community_cards_container)

	# Muck pile
	_muck_pile = Control.new()
	_muck_pile.position = muck_pos - Vector2(20, 20)
	_muck_pile.custom_minimum_size = Vector2(40, 40)
	_muck_count_label = _make_label("0", 12, Color(0.7, 0.7, 0.7))
	_muck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_muck_count_label.position = Vector2(10, 42)
	_muck_pile.add_child(_muck_count_label)
	_muck_pile.visible = false
	_table_overlay.add_child(_muck_pile)

	# Street badge
	_street_badge = _make_label("", 14, Color(0.15, 0.15, 0.2))
	var street_bg := StyleBoxFlat.new()
	street_bg.bg_color = Color(0.95, 0.77, 0.06)
	street_bg.set_corner_radius_all(4)
	street_bg.set_content_margin_all(5)
	_street_badge.add_theme_stylebox_override("normal", street_bg)
	_street_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_street_badge.position = pot_pos - Vector2(40, 50)
	_street_badge.custom_minimum_size = Vector2(80, 0)
	_street_badge.visible = false
	_table_overlay.add_child(_street_badge)

	# Last action label
	_last_action_label = _make_label("", 13, Color(0.65, 0.65, 0.65))
	_last_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_action_label.position = Vector2(TableLayout.BG_OFFSET.x + TableLayout.BG_SIZE.x * 0.5 - 200, TableLayout.BG_OFFSET.y + TableLayout.BG_SIZE.y - 30)
	_last_action_label.custom_minimum_size = Vector2(400, 0)
	_table_overlay.add_child(_last_action_label)


# =============================================================================
# STEP 4: HAND CARDS
# =============================================================================

func _build_card_slots() -> void:
	for i in range(9):
		var slot := Control.new()
		var card_pos: Vector2 = GameManager.get_layout_position_px("cards", i)
		slot.position = card_pos - Vector2(30, 18)
		slot.custom_minimum_size = Vector2(60, 36)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_table_overlay.add_child(slot)
		_card_slots.append(slot)


func _refresh_hand_cards() -> void:
	var hc_scale: float = GameManager.layout_config.get("hole_card_scale", 1.0)
	var hc_gap: float = GameManager.layout_config.get("hole_card_gap", 0.6)
	var card_size := Vector2(48, 66) * hc_scale
	var card_gap := card_size.x * hc_gap


	for i in range(9):
		var slot: Control = _card_slots[i]
		for child in slot.get_children():
			child.queue_free()

		var player: PlayerData = GameManager.players[i]
		if player.folded:
			continue

		if GameManager.street == GameManager.Street.PITCH:
			var key := str(i)
			var count: int = _arrived_cards.get(key, 0)
			for c_idx in range(mini(count, player.hole_cards.size())):
				var cd: CardData = player.hole_cards[c_idx]
				var card_node: TextureRect = CardDisplayScene.instantiate()
				card_node.custom_minimum_size = card_size
				card_node.size = card_size
				card_node.position = Vector2(c_idx * card_gap, 0)
				slot.add_child(card_node)
				card_node.set_card(cd)
		else:
			for c_idx in range(player.hole_cards.size()):
				var card_node: TextureRect = CardDisplayScene.instantiate()
				card_node.custom_minimum_size = card_size
				card_node.size = card_size
				card_node.position = Vector2(c_idx * card_gap, 0)
				slot.add_child(card_node)
				card_node.set_card(player.hole_cards[c_idx])
				if not player.hole_cards[c_idx].face_up:
					card_node.set_face_down()


func _refresh_community_cards() -> void:
	var cc_scale: float = GameManager.layout_config.get("community_card_scale", 1.0)
	var cc_size := Vector2(48.0 * cc_scale, 66.0 * cc_scale)
	for child in _community_cards_container.get_children():
		child.queue_free()
	for card: CardData in GameManager.community_cards:
		var card_node: TextureRect = CardDisplayScene.instantiate()
		card_node.custom_minimum_size = cc_size
		card_node.size = cc_size
		_community_cards_container.add_child(card_node)
		card_node.set_card(card)


# =============================================================================
# STEP 5: PITCH PHASE
# =============================================================================

const PITCH_HAND_BASE_SIZE := Vector2(57, 80)  # 400:562 aspect ratio

func _build_pitch_ui() -> void:
	# Pitching hand
	_pitch_hand = TextureRect.new()
	_pitch_hand.texture = load("res://assets/ui/pitching_hand.png")
	_pitch_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pitch_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ph_scale: float = GameManager.layout_config.get("pitch_hand_scale", 1.0)
	var ph_size := PITCH_HAND_BASE_SIZE * ph_scale
	_pitch_hand.custom_minimum_size = ph_size
	_pitch_hand.size = ph_size
	_pitch_hand.pivot_offset = ph_size / 2
	var hand_pct: Vector2 = GameManager.layout_config.get("pitch_hand", TableLayout.DEFAULT_PITCH_HAND_PCT)
	var hand_pos: Vector2 = TableLayout.pct_to_px(hand_pct)
	_pitch_hand.position = hand_pos - ph_size / 2
	_pitch_hand.rotation_degrees = GameManager.layout_config.get("pitch_hand_rotation", 0.0)
	_pitch_hand.visible = false
	_pitch_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pitch_hand)

	# Remaining cards label
	_pitch_remaining_label = _make_label("52", 12, Color.WHITE)
	_pitch_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pitch_remaining_label.position = hand_pos + Vector2(-15, ph_size.y / 2 + 2)
	_pitch_remaining_label.custom_minimum_size = Vector2(30, 0)
	_pitch_remaining_label.visible = false
	add_child(_pitch_remaining_label)

	# Pitch zones
	for i in range(9):
		var zone := Control.new()
		zone.name = "PitchZone%d" % i
		var card_pos: Vector2 = GameManager.get_layout_position_px("cards", i)
		var _hc_scale: float = GameManager.layout_config.get("hole_card_scale", 0.55)
		var _hc_gap: float = GameManager.layout_config.get("hole_card_gap", 0.6)
		var _hc_sz := Vector2(48, 66) * _hc_scale
		var _hc_tw: float = _hc_sz.x + _hc_sz.x * _hc_gap
		var _zpad := Vector2(3, 3)
		var _zsz := Vector2(_hc_tw, _hc_sz.y) + _zpad * 2
		zone.position = card_pos - _zsz / 2
		zone.custom_minimum_size = _zsz
		zone.size = _zsz
		zone.mouse_filter = Control.MOUSE_FILTER_STOP
		zone.visible = false
		var idx := i
		zone.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var face_up := Input.is_key_pressed(KEY_U)
				GameManager.pitch_card_to_player(idx, face_up)
		)
		zone.mouse_entered.connect(func() -> void: zone.queue_redraw())
		zone.mouse_exited.connect(func() -> void: zone.queue_redraw())
		zone.draw.connect(_draw_pitch_zone.bind(zone, i))
		_table_overlay.add_child(zone)
		_pitch_zones.append(zone)

	# Auto-pitch button
	_auto_pitch_btn = Button.new()
	_auto_pitch_btn.text = "Auto Pitch"
	_auto_pitch_btn.add_theme_font_size_override("font_size", 12)
	var ap_style := StyleBoxFlat.new()
	ap_style.bg_color = Color(0.3, 0.6, 0.3)
	ap_style.set_corner_radius_all(4)
	ap_style.set_content_margin_all(4)
	_auto_pitch_btn.add_theme_stylebox_override("normal", ap_style)
	_auto_pitch_btn.position = hand_pos + Vector2(-45, ph_size.y / 2 + 18)
	_auto_pitch_btn.visible = false
	_auto_pitch_btn.pressed.connect(_on_auto_pitch_pressed)
	add_child(_auto_pitch_btn)

	# Auto-pitch timer
	_auto_pitch_timer = Timer.new()
	_auto_pitch_timer.wait_time = 0.15
	_auto_pitch_timer.one_shot = false
	_auto_pitch_timer.timeout.connect(_on_auto_pitch_tick)
	add_child(_auto_pitch_timer)

	# Table overlay click for mispitch
	_table_overlay.gui_input.connect(_on_table_overlay_input)


func _draw_pitch_zone(zone: Control, idx: int) -> void:
	var rect := Rect2(Vector2.ZERO, zone.size)
	var ps: PitchState = GameManager.pitch_state
	var count: int = ps.player_card_counts[idx]
	var color := Color.WHITE

	if ps.replacement_phase and ps.replacement_player_index == idx:
		color = Color(1, 0.3, 0.3)
	elif count >= 2:
		color = Color(0.4, 0.4, 0.4, 0.4)
	elif count == 1:
		color = Color(0.3, 0.9, 0.3)
	elif zone.get_global_rect().has_point(zone.get_global_mouse_position()):
		color = Color(1, 0.9, 0.2)

	# Dashed border
	var dash_len := 6.0
	var gap_len := 4.0
	_draw_dashed_rect(zone, rect, color, dash_len, gap_len)


func _draw_dashed_rect(canvas: Control, rect: Rect2, color: Color, dash: float, gap: float) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in range(4):
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		_draw_dashed_line(canvas, from, to, color, dash, gap)


func _draw_dashed_line(canvas: Control, from: Vector2, to: Vector2, color: Color, dash: float, gap: float) -> void:
	var length := from.distance_to(to)
	var dir := (to - from).normalized()
	var pos := 0.0
	var drawing := true
	while pos < length:
		var seg := dash if drawing else gap
		seg = minf(seg, length - pos)
		if drawing:
			canvas.draw_line(from + dir * pos, from + dir * (pos + seg), color, 1.5)
		pos += seg
		drawing = not drawing


func _on_table_overlay_input(event: InputEvent) -> void:
	if GameManager.street != GameManager.Street.PITCH:
		return
	if GameManager.pitch_state.has_mispitch:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click is on a pitch zone
		for zone in _pitch_zones:
			if zone.visible and zone.get_global_rect().has_point(event.global_position):
				return
		# Mispitch — convert to percentage
		var click_pos: Vector2 = event.position
		var pct: Vector2 = TableLayout.px_to_pct(click_pos)
		GameManager.mispitch(pct.x, pct.y)


func _on_auto_pitch_pressed() -> void:
	if _auto_pitch_timer.is_stopped():
		_auto_pitch_timer.start()
		_auto_pitch_btn.text = "Stop Auto"
	else:
		_auto_pitch_timer.stop()
		_auto_pitch_btn.text = "Auto Pitch"


func _on_auto_pitch_tick() -> void:
	if GameManager.street != GameManager.Street.PITCH:
		_auto_pitch_timer.stop()
		_auto_pitch_btn.text = "Auto Pitch"
		return
	if GameManager.pitch_state.has_mispitch or GameManager.pitch_state.replacement_phase:
		_auto_pitch_timer.stop()
		_auto_pitch_btn.text = "Auto Pitch"
		return
	GameManager.pitch_card_to_player(GameManager.pitch_state.expected_player_index, false)


func _animate_card_flight(player_index: int, face_up: bool, card: CardData) -> void:
	var hc_scale: float = GameManager.layout_config.get("hole_card_scale", 0.55)
	var hc_gap: float = GameManager.layout_config.get("hole_card_gap", 0.6)
	var card_size := Vector2(48, 66) * hc_scale
	var card_node: TextureRect = CardDisplayScene.instantiate()
	card_node.custom_minimum_size = card_size
	card_node.size = card_size
	card_node.pivot_offset = card_size / 2
	card_node.set_card(card)
	if not face_up:
		card_node.set_face_down()

	var is_mispitch := GameManager.pitch_state.has_mispitch

	var start_pos: Vector2 = _pitch_hand.position + _pitch_hand.pivot_offset - card_size / 2
	var card_center: Vector2 = GameManager.get_layout_position_px("cards", player_index)
	var total_w: float = card_size.x + card_size.x * hc_gap
	var target_pos := Vector2(card_center.x - total_w / 2, card_center.y - card_size.y / 2)
	var existing: int = _arrived_cards.get(str(player_index), 0)
	target_pos.x += existing * card_size.x * hc_gap

	card_node.position = start_pos
	card_node.z_index = 10
	add_child(card_node)

	# Linear flight + continuous rotation
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_node, "position", target_pos, 0.6).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(card_node, "rotation", TAU * 4, 0.6).set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(func() -> void:
		card_node.rotation = 0.0
		if is_mispitch:
			_mispitch_cards.append(card_node)
		else:
			card_node.queue_free()
			_arrived_cards[str(player_index)] = _arrived_cards.get(str(player_index), 0) + 1
			_refresh_hand_cards()
	)


func _clear_pitched_cards() -> void:
	_arrived_cards.clear()
	for card_node in _mispitch_cards:
		if is_instance_valid(card_node):
			card_node.queue_free()
	_mispitch_cards.clear()


func _animate_mispitch_flight(target_pct: Vector2, card: CardData) -> void:
	var hc_scale: float = GameManager.layout_config.get("hole_card_scale", 0.55)
	var card_size := Vector2(48, 66) * hc_scale
	var card_node: TextureRect = CardDisplayScene.instantiate()
	card_node.custom_minimum_size = card_size
	card_node.size = card_size
	card_node.pivot_offset = card_size / 2
	card_node.set_card(card)
	card_node.set_face_down()

	var start_pos: Vector2 = _pitch_hand.position + _pitch_hand.pivot_offset - card_size / 2
	var target_px: Vector2 = TableLayout.pct_to_px(target_pct)
	var target_pos: Vector2 = target_px - card_size / 2

	card_node.position = start_pos
	card_node.z_index = 10
	add_child(card_node)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_node, "position", target_pos, 0.6).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(card_node, "rotation", TAU * 4, 0.6).set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(func() -> void:
		card_node.rotation = 0.0
		_mispitch_cards.append(card_node)
	)


func _update_pitch_ui() -> void:
	var is_pitch := GameManager.street == GameManager.Street.PITCH
	_pitch_hand.visible = is_pitch
	_pitch_remaining_label.visible = is_pitch
	_auto_pitch_btn.visible = is_pitch
	for zone in _pitch_zones:
		zone.visible = is_pitch
		zone.queue_redraw()
	if is_pitch:
		_pitch_remaining_label.text = "%d" % GameManager.deck.size()
		# Enable table overlay click capture during pitch
		_table_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		_table_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _auto_pitch_timer and not _auto_pitch_timer.is_stopped():
			_auto_pitch_timer.stop()
			_auto_pitch_btn.text = "Auto Pitch"


func _process(_delta: float) -> void:
	if _pitch_hand.visible:
		var mouse_pos := get_global_mouse_position()
		var hand_center := _pitch_hand.position + _pitch_hand.pivot_offset
		var base_rot: float = deg_to_rad(GameManager.layout_config.get("pitch_hand_rotation", 0.0))
		var angle := hand_center.angle_to_point(mouse_pos) + PI
		_pitch_hand.rotation = base_rot + angle


# =============================================================================
# STEP 5b: MISDEAL OVERLAY
# =============================================================================

func _build_misdeal_overlay() -> void:
	_misdeal_x = Button.new()
	_misdeal_x.text = "X"
	_misdeal_x.custom_minimum_size = Vector2(80, 80)
	_misdeal_x.size = Vector2(80, 80)
	_misdeal_x.add_theme_font_size_override("font_size", 36)
	_misdeal_x.add_theme_color_override("font_color", Color.WHITE)
	var x_style := StyleBoxFlat.new()
	x_style.bg_color = Color(0.85, 0.1, 0.1)
	x_style.set_corner_radius_all(40)
	x_style.set_content_margin_all(0)
	_misdeal_x.add_theme_stylebox_override("normal", x_style)
	var x_hover := StyleBoxFlat.new()
	x_hover.bg_color = Color(1.0, 0.2, 0.2)
	x_hover.set_corner_radius_all(40)
	x_hover.set_content_margin_all(0)
	_misdeal_x.add_theme_stylebox_override("hover", x_hover)
	_misdeal_x.z_index = 100
	_misdeal_x.position = Vector2(TableLayout.BG_OFFSET.x + TableLayout.BG_SIZE.x * 0.5 - 40, TableLayout.BG_OFFSET.y + TableLayout.BG_SIZE.y * 0.5 - 40)
	_misdeal_x.pivot_offset = Vector2(40, 40)
	_misdeal_x.visible = false
	_misdeal_x.pressed.connect(_on_misdeal_x_pressed)
	add_child(_misdeal_x)

	# Misdeal menu (appears above the X button)
	_misdeal_menu = PanelContainer.new()
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	menu_style.set_corner_radius_all(6)
	menu_style.set_content_margin_all(8)
	_misdeal_menu.add_theme_stylebox_override("panel", menu_style)
	_misdeal_menu.z_index = 101
	_misdeal_menu.visible = false

	var misdeal_btn := Button.new()
	misdeal_btn.text = "Misdeal"
	misdeal_btn.add_theme_font_size_override("font_size", 16)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.85, 0.1, 0.1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(6)
	misdeal_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 0.2, 0.2)
	btn_hover.set_corner_radius_all(4)
	btn_hover.set_content_margin_all(6)
	misdeal_btn.add_theme_stylebox_override("hover", btn_hover)
	misdeal_btn.pressed.connect(_on_misdeal_btn_pressed)
	_misdeal_menu.add_child(misdeal_btn)

	add_child(_misdeal_menu)


func _on_misdeal_x_pressed() -> void:
	_misdeal_menu.visible = not _misdeal_menu.visible
	if _misdeal_menu.visible:
		# Position menu above the X button
		var x_center_x: float = _misdeal_x.position.x + 40
		_misdeal_menu.position = Vector2(x_center_x - _misdeal_menu.size.x / 2, _misdeal_x.position.y - _misdeal_menu.size.y - 8)


func _on_misdeal_btn_pressed() -> void:
	_misdeal_menu.visible = false
	GameManager.declare_misdeal()
	_clear_pitched_cards()
	_refresh_hand_cards()
	_update_pitch_ui()


func _start_misdeal_pulse() -> void:
	if _misdeal_x_tween:
		_misdeal_x_tween.kill()
	_misdeal_x_tween = create_tween().set_loops()
	_misdeal_x_tween.tween_property(_misdeal_x, "scale", Vector2(1.15, 1.15), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_misdeal_x_tween.tween_property(_misdeal_x, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_misdeal_pulse() -> void:
	if _misdeal_x_tween:
		_misdeal_x_tween.kill()
		_misdeal_x_tween = null
	_misdeal_x.scale = Vector2.ONE


# =============================================================================
# STEP 6: CONTEXT MENU + RAISE DIALOG
# =============================================================================

func _build_context_menu() -> void:
	_context_overlay = Control.new()
	_context_overlay.name = "ContextOverlay"
	_context_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_context_overlay.z_index = 50
	_context_overlay.visible = false
	add_child(_context_overlay)

	_click_catcher = Control.new()
	_click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_context_menu()
	)
	_context_overlay.add_child(_click_catcher)

	_context_menu = PanelContainer.new()
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.16, 0.16, 0.24)
	menu_style.set_corner_radius_all(6)
	menu_style.set_content_margin_all(8)
	_context_menu.add_theme_stylebox_override("panel", menu_style)
	_context_menu.custom_minimum_size = Vector2(120, 0)
	_context_overlay.add_child(_context_menu)

	_context_menu_vbox = VBoxContainer.new()
	_context_menu_vbox.add_theme_constant_override("separation", 4)
	_context_menu.add_child(_context_menu_vbox)


func _show_context_menu(player_id: int) -> void:
	# Clear old buttons
	for child in _context_menu_vbox.get_children():
		child.queue_free()

	var has_bet := GameManager.has_bet_to_match()
	var player: PlayerData = null
	var player_idx := -1
	for i in range(GameManager.players.size()):
		if GameManager.players[i].id == player_id:
			player = GameManager.players[i]
			player_idx = i
			break
	if player == null:
		return

	if has_bet:
		var call_amt: int = GameManager.current_bet - player.current_bet
		_context_menu_vbox.add_child(_make_menu_btn("Fold", Color(0.8, 0.2, 0.2), func() -> void:
			GameManager.player_action(player_id, "fold")
			_close_context_menu()
		))
		_context_menu_vbox.add_child(_make_menu_btn("Call $%d" % call_amt, Color(0.2, 0.7, 0.3), func() -> void:
			GameManager.player_action(player_id, "call")
			_close_context_menu()
		))
		_context_menu_vbox.add_child(_make_menu_btn("Raise", Color(0.9, 0.55, 0.1), func() -> void:
			_close_context_menu()
			GameManager.open_raise_dialog(player_id)
		))
	else:
		_context_menu_vbox.add_child(_make_menu_btn("Check", Color(0.3, 0.5, 0.8), func() -> void:
			GameManager.player_action(player_id, "check")
			_close_context_menu()
		))
		_context_menu_vbox.add_child(_make_menu_btn("Bet", Color(0.9, 0.55, 0.1), func() -> void:
			_close_context_menu()
			GameManager.open_raise_dialog(player_id)
		))
		_context_menu_vbox.add_child(_make_menu_btn("Fold", Color(0.8, 0.2, 0.2), func() -> void:
			GameManager.player_action(player_id, "fold")
			_close_context_menu()
		))

	# Position near player seat
	var seat_pos: Vector2 = GameManager.get_layout_position_px("seats", player_idx)
	var menu_pos := seat_pos + Vector2(50, -20)
	# Clamp to viewport
	var vp_size := get_viewport_rect().size
	menu_pos.x = clampf(menu_pos.x, 10, vp_size.x - 140)
	menu_pos.y = clampf(menu_pos.y, 10, vp_size.y - 120)
	_context_menu.position = menu_pos

	_context_overlay.visible = true


func _close_context_menu() -> void:
	_context_overlay.visible = false
	GameManager.close_context_menu()


func _make_menu_btn(text: String, color: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.2)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	btn.pressed.connect(callback)
	return btn


# --- Raise Dialog ---

func _build_raise_dialog() -> void:
	_raise_overlay = Control.new()
	_raise_overlay.name = "RaiseOverlay"
	_raise_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raise_overlay.z_index = 60
	_raise_overlay.visible = false
	add_child(_raise_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_raise_overlay.add_child(dim)

	var dialog := PanelContainer.new()
	var dlg_style := StyleBoxFlat.new()
	dlg_style.bg_color = Color(0.16, 0.16, 0.24)
	dlg_style.set_corner_radius_all(8)
	dlg_style.set_content_margin_all(16)
	dialog.add_theme_stylebox_override("panel", dlg_style)
	dialog.custom_minimum_size = Vector2(280, 0)
	dialog.anchor_left = 0.5
	dialog.anchor_top = 0.5
	dialog.anchor_right = 0.5
	dialog.anchor_bottom = 0.5
	dialog.offset_left = -140
	dialog.offset_top = -100
	dialog.offset_right = 140
	dialog.offset_bottom = 100
	dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_raise_overlay.add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)

	_raise_title = _make_label("Raise", 18, Color.WHITE)
	_raise_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_raise_title)

	_raise_info = _make_label("", 13, Color(0.7, 0.7, 0.7))
	_raise_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_raise_info)

	_raise_input = LineEdit.new()
	_raise_input.placeholder_text = "Enter amount..."
	_raise_input.add_theme_font_size_override("font_size", 16)
	_raise_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_raise_input)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_raise_cancel_btn = _make_menu_btn("Cancel", Color(0.5, 0.5, 0.5), _on_raise_cancel)
	btn_row.add_child(_raise_cancel_btn)

	_raise_confirm_btn = _make_menu_btn("Confirm", Color(0.2, 0.7, 0.3), _on_raise_confirm)
	btn_row.add_child(_raise_confirm_btn)


func _show_raise_dialog(player_id: int) -> void:
	var player: PlayerData = null
	for p in GameManager.players:
		if p.id == player_id:
			player = p
			break
	if player == null:
		return

	var has_bet := GameManager.current_bet > 0
	var min_raise: int
	if has_bet:
		min_raise = GameManager.current_bet + maxi(GameManager.last_raise_increment, GameManager.big_blind)
		_raise_title.text = "Raise - %s" % player.player_name
	else:
		min_raise = GameManager.big_blind
		_raise_title.text = "Bet - %s" % player.player_name

	_raise_info.text = "Min: $%d  |  Stack: $%d" % [min_raise, player.chips]
	_raise_input.text = str(min_raise)
	_raise_input.grab_focus()
	_raise_overlay.visible = true


func _on_raise_cancel() -> void:
	_raise_overlay.visible = false
	GameManager.close_raise_dialog()


func _on_raise_confirm() -> void:
	var amount := _raise_input.text.to_int()
	if amount <= 0:
		return
	var player_id: int = GameManager.raise_dialog_player_id
	var has_bet := GameManager.current_bet > 0
	var action := "raise" if has_bet else "bet"
	GameManager.player_action(player_id, action, amount)
	_raise_overlay.visible = false
	GameManager.close_raise_dialog()


# =============================================================================
# STEP 7: KEYBOARD SHORTCUTS + OOT WARNING + CONTROL PANEL
# =============================================================================

func _build_oot_warning() -> void:
	_oot_warning = Control.new()
	_oot_warning.custom_minimum_size = Vector2(36, 36)
	_oot_warning.size = Vector2(36, 36)
	_oot_warning.z_index = 40
	_oot_warning.visible = false
	_oot_warning.mouse_filter = Control.MOUSE_FILTER_STOP
	_oot_warning.pivot_offset = Vector2(18, 18)

	var oot_label := Label.new()
	oot_label.text = "!"
	oot_label.add_theme_font_size_override("font_size", 20)
	oot_label.add_theme_color_override("font_color", Color.WHITE)
	oot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	oot_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	var oot_bg := StyleBoxFlat.new()
	oot_bg.bg_color = Color(0.85, 0.1, 0.1)
	oot_bg.set_corner_radius_all(18)
	oot_label.add_theme_stylebox_override("normal", oot_bg)
	_oot_warning.add_child(oot_label)

	_oot_warning.gui_input.connect(_on_oot_warning_input)
	_oot_warning.position = Vector2(TableLayout.BG_OFFSET.x + TableLayout.BG_SIZE.x * 0.5 - 18, TableLayout.BG_OFFSET.y + TableLayout.BG_SIZE.y * 0.5 - 18)
	add_child(_oot_warning)

	# OOT menu (appears below the "!" indicator)
	_oot_menu = PanelContainer.new()
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	menu_style.set_corner_radius_all(6)
	menu_style.set_content_margin_all(8)
	_oot_menu.add_theme_stylebox_override("panel", menu_style)
	_oot_menu.z_index = 41
	_oot_menu.visible = false

	var redo_btn := Button.new()
	redo_btn.text = "Redo"
	redo_btn.add_theme_font_size_override("font_size", 16)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.7, 0.2, 0.2)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(6)
	redo_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.9, 0.3, 0.3)
	btn_hover.set_corner_radius_all(4)
	btn_hover.set_content_margin_all(6)
	redo_btn.add_theme_stylebox_override("hover", btn_hover)
	redo_btn.add_theme_color_override("font_color", Color.WHITE)
	redo_btn.pressed.connect(_on_oot_redo_pressed)
	_oot_menu.add_child(redo_btn)

	add_child(_oot_menu)


func _on_oot_warning_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_oot_menu.visible = not _oot_menu.visible
			if _oot_menu.visible:
				var warn_center_x: float = _oot_warning.position.x + 18
				_oot_menu.position = Vector2(warn_center_x - _oot_menu.size.x / 2, _oot_warning.position.y + 40)


func _on_oot_redo_pressed() -> void:
	_oot_menu.visible = false
	GameManager.undo_last_action()
	_update_button_states()
	_refresh_seat_data()
	_refresh_hand_cards()
	_refresh_indicators()
	_update_oot_warning()


func _start_oot_pulse() -> void:
	if _oot_tween:
		_oot_tween.kill()
	_oot_tween = create_tween().set_loops()
	_oot_tween.tween_property(_oot_warning, "scale", Vector2(1.15, 1.15), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_oot_tween.tween_property(_oot_warning, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_oot_pulse() -> void:
	if _oot_tween:
		_oot_tween.kill()
		_oot_tween = null
	_oot_warning.scale = Vector2.ONE


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if not GameManager.is_hand_in_progress:
		return
	if GameManager.street == GameManager.Street.PITCH:
		return
	if _raise_overlay.visible or _context_overlay.visible:
		return

	var cp: PlayerData = GameManager.get_current_player()
	if cp == null:
		return

	var key: Key = (event as InputEventKey).keycode
	match key:
		KEY_F:
			GameManager.player_action(cp.id, "fold")
		KEY_C:
			if GameManager.has_bet_to_match():
				GameManager.player_action(cp.id, "call")
			else:
				GameManager.player_action(cp.id, "check")
		KEY_R, KEY_B:
			GameManager.open_raise_dialog(cp.id)


# =============================================================================
# CONTROL PANEL (Step 1)
# =============================================================================

func _build_control_panel() -> void:
	_control_panel = PanelContainer.new()
	_control_panel.name = "ControlPanel"
	_control_panel.z_index = 30
	_control_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(6)
	_control_panel.add_theme_stylebox_override("panel", panel_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	_control_panel.add_child(hbox)

	_new_hand_btn = _make_button("New Hand", Color(0.2, 0.7, 0.3))
	_new_hand_btn.pressed.connect(_on_new_hand)
	hbox.add_child(_new_hand_btn)

	_reset_btn = _make_button("Reset", Color(0.7, 0.2, 0.2))
	_reset_btn.pressed.connect(_on_reset)
	hbox.add_child(_reset_btn)

	_move_dealer_btn = _make_button("Move Dealer", Color(0.3, 0.5, 0.8))
	_move_dealer_btn.pressed.connect(_on_move_dealer)
	hbox.add_child(_move_dealer_btn)

	_undo_btn = _make_button("Undo", Color(0.6, 0.5, 0.2))
	_undo_btn.pressed.connect(_on_undo)
	hbox.add_child(_undo_btn)

	var sep := VSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	hbox.add_child(sep)

	_out_of_turn_check = _make_checkbox("Out of Turn")
	_out_of_turn_check.toggled.connect(func(v: bool) -> void: GameManager.out_of_turn_mode = v)
	hbox.add_child(_out_of_turn_check)

	_show_action_check = _make_checkbox("Show Action")
	_show_action_check.toggled.connect(func(v: bool) -> void:
		GameManager.show_action = v
		_refresh_indicators()
	)
	hbox.add_child(_show_action_check)

	_show_aggressor_check = _make_checkbox("Show Aggressor")
	_show_aggressor_check.toggled.connect(func(v: bool) -> void:
		GameManager.show_aggressor = v
		_refresh_indicators()
	)
	hbox.add_child(_show_aggressor_check)

	var sep2 := VSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	hbox.add_child(sep2)

	# Game mode dropdown
	var mode_label := _make_label("Mode:", 13, Color(0.7, 0.7, 0.7))
	hbox.add_child(mode_label)
	_game_mode_option = OptionButton.new()
	_game_mode_option.add_item("Cash Game", 0)
	_game_mode_option.add_item("Tournament", 1)
	_game_mode_option.selected = 0 if GameManager.game_mode == GameManager.GameMode.CASH else 1
	_game_mode_option.add_theme_font_size_override("font_size", 13)
	_game_mode_option.item_selected.connect(_on_game_mode_selected)
	hbox.add_child(_game_mode_option)

	# Blinds dropdown
	var blinds_label := _make_label("Blinds:", 13, Color(0.7, 0.7, 0.7))
	hbox.add_child(blinds_label)
	_blinds_option = OptionButton.new()
	_blinds_option.add_theme_font_size_override("font_size", 13)
	_populate_blinds_options()
	_blinds_option.item_selected.connect(_on_blinds_selected)
	hbox.add_child(_blinds_option)

	# Layout button
	var sep3 := VSeparator.new()
	sep3.add_theme_constant_override("separation", 8)
	hbox.add_child(sep3)

	_layout_btn = _make_button("Layout", Color(0.5, 0.3, 0.7))
	_layout_btn.pressed.connect(func() -> void: _layout_editor.toggle())
	hbox.add_child(_layout_btn)

	add_child(_control_panel)
	_control_panel.position = Vector2(10, 5)
	_control_panel.size = Vector2(0, 0)
	_control_panel.z_index = 200
	_update_button_states()


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.2)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color.darkened(0.2)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", 14)
	return btn


func _make_checkbox(text: String) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.add_theme_color_override("font_color", Color.WHITE)
	cb.add_theme_font_size_override("font_size", 13)
	return cb


func _update_button_states() -> void:
	var in_hand := GameManager.is_hand_in_progress
	_new_hand_btn.disabled = in_hand
	_move_dealer_btn.disabled = in_hand
	_undo_btn.disabled = GameManager._action_history.is_empty() and not in_hand


func _on_new_hand() -> void:
	_clear_pitched_cards()
	GameManager.start_hand()

func _on_reset() -> void:
	_clear_pitched_cards()
	GameManager.reset_game()

func _on_move_dealer() -> void:
	GameManager.move_dealer_button()

func _on_undo() -> void:
	GameManager.undo_last_action()
	_update_button_states()
	_refresh_seat_data()
	_refresh_hand_cards()
	_refresh_indicators()
	_update_oot_warning()


func _on_game_mode_selected(index: int) -> void:
	var mode: GameManager.GameMode = GameManager.GameMode.CASH if index == 0 else GameManager.GameMode.TOURNAMENT
	GameManager.set_game_mode(mode)
	_populate_blinds_options()


func _on_blinds_selected(index: int) -> void:
	var presets: Array = GameManager.CASH_BLINDS if GameManager.game_mode == GameManager.GameMode.CASH else GameManager.TOURNAMENT_BLINDS
	if index >= 0 and index < presets.size():
		GameManager.set_blinds(presets[index][0], presets[index][1])


func _populate_blinds_options() -> void:
	_blinds_option.clear()
	var presets: Array = GameManager.CASH_BLINDS if GameManager.game_mode == GameManager.GameMode.CASH else GameManager.TOURNAMENT_BLINDS
	for pair in presets:
		_blinds_option.add_item("%d / %d" % [pair[0], pair[1]])
	# Select current blinds if they match a preset
	for i in range(presets.size()):
		if presets[i][0] == GameManager.small_blind and presets[i][1] == GameManager.big_blind:
			_blinds_option.selected = i
			return
	_blinds_option.selected = 0


# =============================================================================
# SIGNAL CONNECTIONS + HANDLERS
# =============================================================================

func _connect_signals() -> void:
	GameManager.hand_started.connect(_on_hand_started)
	GameManager.hand_ended.connect(_on_hand_ended)
	GameManager.game_reset.connect(_on_game_reset)
	GameManager.street_changed.connect(_on_street_changed)
	GameManager.player_acted.connect(_on_player_acted)
	GameManager.pot_changed.connect(_on_pot_changed)
	GameManager.community_cards_changed.connect(_on_community_cards_changed)
	GameManager.pitch_state_changed.connect(_on_pitch_state_changed)
	GameManager.pitch_card_animated.connect(_on_pitch_card_animated)
	GameManager.context_menu_requested.connect(_on_context_menu_requested)
	GameManager.raise_dialog_requested.connect(_on_raise_dialog_requested)
	GameManager.dealer_moved.connect(_on_dealer_moved)
	GameManager.current_player_changed.connect(_on_current_player_changed)
	GameManager.muck_changed.connect(_on_muck_changed)
	GameManager.last_action_changed.connect(_on_last_action_changed)
	GameManager.misdeal_x_changed.connect(_on_misdeal_x_changed)
	GameManager.mispitch_animated.connect(_on_mispitch_animated)
	GameManager.layout_changed.connect(_on_layout_changed)


func _on_hand_started() -> void:
	_update_button_states()
	_refresh_all()

func _on_hand_ended(_winner: String, _pot_amt: int) -> void:
	_update_button_states()
	_refresh_hand_cards()
	_update_pitch_ui()

func _on_game_reset() -> void:
	_clear_pitched_cards()
	_update_button_states()
	_refresh_all()

func _on_street_changed(_new_street: GameManager.Street) -> void:
	_update_pitch_ui()
	_refresh_street_badge()
	_refresh_hand_cards()
	if _new_street != GameManager.Street.PITCH:
		_clear_pitched_cards()

func _on_player_acted(_pid: int, _action: String, _amount: int) -> void:
	_refresh_seat_data()
	_refresh_hand_cards()
	_update_button_states()
	_refresh_indicators()
	_update_oot_warning()

func _on_pot_changed(new_pot: int) -> void:
	_pot_amount_label.text = "$%d" % new_pot

func _on_community_cards_changed() -> void:
	_refresh_community_cards()

func _on_pitch_state_changed() -> void:
	_update_pitch_ui()
	for zone in _pitch_zones:
		zone.queue_redraw()

func _on_pitch_card_animated(player_index: int, face_up: bool, card: CardData) -> void:
	_animate_card_flight(player_index, face_up, card)
	_pitch_remaining_label.text = "%d" % GameManager.deck.size()

func _on_mispitch_animated(target_pct: Vector2, card: CardData) -> void:
	_animate_mispitch_flight(target_pct, card)
	_pitch_remaining_label.text = "%d" % GameManager.deck.size()

func _on_context_menu_requested(player_id: int) -> void:
	_show_context_menu(player_id)

func _on_raise_dialog_requested(player_id: int) -> void:
	_show_raise_dialog(player_id)

func _on_dealer_moved(index: int) -> void:
	var db_scale: float = GameManager.layout_config.get("dealer_button_scale", 1.0)
	var db_size := Vector2(26, 26) * db_scale
	var target: Vector2 = GameManager.get_layout_position_px("dealer_buttons", index) - db_size / 2
	if _dealer_tween:
		_dealer_tween.kill()
	_dealer_tween = create_tween()
	_dealer_tween.tween_property(_dealer_button, "position", target, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _on_current_player_changed(_index: int) -> void:
	_refresh_indicators()

func _on_muck_changed() -> void:
	_refresh_muck()
	_refresh_hand_cards()

func _on_last_action_changed(text: String) -> void:
	_last_action_label.text = text

func _on_misdeal_x_changed(vis: bool) -> void:
	_misdeal_x.visible = vis
	if vis:
		_start_misdeal_pulse()
	else:
		_stop_misdeal_pulse()
		_misdeal_menu.visible = false


# =============================================================================
# REFRESH HELPERS
# =============================================================================

func _refresh_all() -> void:
	_reposition_all()
	_refresh_seat_data()
	_refresh_hand_cards()
	_refresh_community_cards()
	_refresh_muck()
	_refresh_street_badge()
	_refresh_indicators()
	_update_pitch_ui()
	_update_oot_warning()
	_pot_amount_label.text = "$%d" % GameManager.pot
	_last_action_label.text = GameManager.last_action


func _refresh_seat_data() -> void:
	for i in range(9):
		var p: PlayerData = GameManager.players[i]
		_name_labels[i].text = p.player_name
		_stack_labels[i].text = "$%d" % p.chips
		_fold_labels[i].visible = p.folded
		if p.current_bet > 0:
			_bet_labels[i].text = "$%d" % p.current_bet
			_bet_labels[i].visible = true
		else:
			_bet_labels[i].visible = false


func _refresh_indicators() -> void:
	for i in range(9):
		var p: PlayerData = GameManager.players[i]
		# Gold outline on current player's avatar
		var is_current := GameManager.current_player_index == i
		var show_outline := is_current and GameManager.is_hand_in_progress and GameManager.street != GameManager.Street.PITCH
		if i < _avatars.size():
			var mat: ShaderMaterial = _avatars[i].material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("enabled", show_outline)
		# Hide old action indicator (kept for compatibility but not shown)
		_action_indicators[i].visible = false
		# Aggressor indicator
		_aggressor_indicators[i].visible = GameManager.show_aggressor and GameManager.aggressor_player_id == p.id and GameManager.is_hand_in_progress

	# Action arrow — same condition as gold outline
	var cp := GameManager.current_player_index
	var show_arrow := cp >= 0 and GameManager.is_hand_in_progress and GameManager.street != GameManager.Street.PITCH
	if show_arrow:
		_position_action_arrow(cp)
		_action_arrow.visible = true
		_start_action_arrow_bounce()
	else:
		_action_arrow.visible = false
		_stop_action_arrow_bounce()


func _refresh_muck() -> void:
	var mk_scale: float = GameManager.layout_config.get("muck_card_scale", 1.0)
	var mk_size := Vector2(48, 66) * mk_scale
	var count := GameManager.muck_pile.size()
	_muck_pile.visible = count > 0
	_muck_count_label.text = "%d" % count
	# Draw fan of card backs
	for child in _muck_pile.get_children():
		if child != _muck_count_label:
			child.queue_free()
	var fan_count := mini(count, 5)
	for i in range(fan_count):
		var back: TextureRect = CardDisplayScene.instantiate()
		back.custom_minimum_size = mk_size
		back.size = mk_size
		back.position = Vector2(i * mk_size.x * 0.15, i * mk_size.y * 0.05)
		back.rotation = deg_to_rad(randf_range(-10, 10))
		back.set_face_down()
		_muck_pile.add_child(back)
	_muck_pile.move_child(_muck_count_label, _muck_pile.get_child_count() - 1)


func _refresh_street_badge() -> void:
	if GameManager.is_hand_in_progress:
		_street_badge.text = GameManager.STREET_NAMES[GameManager.street].to_upper()
		_street_badge.visible = true
	else:
		_street_badge.visible = false


func _update_oot_warning() -> void:
	var show := GameManager.has_out_of_turn_action
	_oot_warning.visible = show
	if show:
		_start_oot_pulse()
	else:
		_stop_oot_pulse()
		_oot_menu.visible = false


# =============================================================================
# ACTION ARROW INDICATOR
# =============================================================================

func _build_action_arrow() -> void:
	_action_arrow = Control.new()
	_action_arrow.name = "ActionArrow"
	_action_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_arrow.z_index = 5
	_action_arrow.visible = false
	_action_arrow.draw.connect(_draw_action_arrow)
	_table_overlay.add_child(_action_arrow)


func _draw_action_arrow() -> void:
	var arrow_color := Color(1.0, 0.55, 0.0)
	var body_w := 80.0
	var body_h := 18.0
	var head_w := 30.0
	var head_h := 36.0
	# Arrow body (rectangle) — drawn so the tip points right (+X)
	_action_arrow.draw_rect(Rect2(0, -body_h / 2, body_w, body_h), arrow_color)
	# Arrow head (triangle)
	var tip := Vector2(body_w + head_w, 0)
	var top := Vector2(body_w, -head_h / 2)
	var bot := Vector2(body_w, head_h / 2)
	_action_arrow.draw_polygon([tip, top, bot], [arrow_color, arrow_color, arrow_color])
	# "Action" text
	var font := ThemeDB.fallback_font
	var font_size := 13
	var text_w := font.get_string_size("Action", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	_action_arrow.draw_string(font, Vector2((body_w - text_w) / 2, body_h / 2 - 4), "Action", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _position_action_arrow(seat_index: int) -> void:
	var table_center := TableLayout.BG_OFFSET + TableLayout.BG_SIZE / 2
	var seat_pos: Vector2 = GameManager.get_layout_position_px("seats", seat_index)
	var direction := (seat_pos - table_center).normalized()
	var dist := table_center.distance_to(seat_pos)
	_action_arrow.position = table_center + direction * dist * 0.45
	_action_arrow.rotation = direction.angle()
	_action_arrow.queue_redraw()


func _start_action_arrow_bounce() -> void:
	_stop_action_arrow_bounce()
	_action_arrow_tween = create_tween().set_loops()
	var base_pos := _action_arrow.position
	var direction := Vector2.from_angle(_action_arrow.rotation)
	_action_arrow_tween.tween_property(_action_arrow, "position", base_pos + direction * 12, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_action_arrow_tween.tween_property(_action_arrow, "position", base_pos, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_action_arrow_bounce() -> void:
	if _action_arrow_tween and _action_arrow_tween.is_valid():
		_action_arrow_tween.kill()
		_action_arrow_tween = null


# =============================================================================
# LAYOUT EDITOR (delegated to LayoutEditor)
# =============================================================================

func _on_layout_changed() -> void:
	_reposition_all()
	_layout_editor.on_layout_changed()
	_refresh_hand_cards()
	_refresh_community_cards()
	_refresh_muck()


# =============================================================================
# REPOSITION ALL ELEMENTS
# =============================================================================

func _reposition_all() -> void:
	var avatar_scale: float = GameManager.layout_config.get("avatar_scale", 1.0)
	var db_scale: float = GameManager.layout_config.get("dealer_button_scale", 1.0)
	var avatar_size := Vector2(70, 70) * avatar_scale
	var db_size := Vector2(26, 26) * db_scale

	var hc_scale: float = GameManager.layout_config.get("hole_card_scale", 0.55)
	var hc_gap: float = GameManager.layout_config.get("hole_card_gap", 0.6)
	var hc_size := Vector2(48, 66) * hc_scale
	var hc_total_w: float = hc_size.x + hc_size.x * hc_gap  # 2 cards with gap
	var hc_total_h: float = hc_size.y
	var zone_padding := Vector2(3, 3)
	var zone_size := Vector2(hc_total_w, hc_total_h) + zone_padding * 2

	for i in range(9):
		var seat_pos: Vector2 = GameManager.get_layout_position_px("seats", i)
		var stack_pos: Vector2 = GameManager.get_layout_position_px("stacks", i)
		var bet_pos: Vector2 = GameManager.get_layout_position_px("bets", i)
		var card_pos: Vector2 = GameManager.get_layout_position_px("cards", i)

		# Avatars
		if i < _avatars.size():
			_avatars[i].custom_minimum_size = avatar_size
			_avatars[i].size = avatar_size
			_avatars[i].position = seat_pos - avatar_size / 2 - Vector2(0, avatar_size.y * 0.3)

		# Name labels
		if i < _name_labels.size():
			_name_labels[i].position = seat_pos - Vector2(40, 10)

		# Seat badges
		if i < _seat_badges.size():
			_seat_badges[i].position = seat_pos - Vector2(52, 10)

		# Fold labels
		if i < _fold_labels.size():
			_fold_labels[i].position = seat_pos - Vector2(25, -14)

		# Action indicators
		if i < _action_indicators.size():
			_action_indicators[i].position = seat_pos - Vector2(28, 28)

		# Aggressor indicators
		if i < _aggressor_indicators.size():
			_aggressor_indicators[i].position = seat_pos - Vector2(35, 44)

		# Stack labels
		if i < _stack_labels.size():
			_stack_labels[i].position = stack_pos - Vector2(30, 8)

		# Bet labels
		if i < _bet_labels.size():
			_bet_labels[i].position = bet_pos - Vector2(25, 8)

		# Card slots — centered on card_pos
		if i < _card_slots.size():
			_card_slots[i].position = card_pos - Vector2(hc_total_w / 2, hc_size.y / 2)
			_card_slots[i].custom_minimum_size = Vector2(hc_total_w, hc_total_h)
			_card_slots[i].size = Vector2(hc_total_w, hc_total_h)

		# Pitch zones — wrap around hole cards with padding
		if i < _pitch_zones.size():
			_pitch_zones[i].position = card_pos - zone_size / 2
			_pitch_zones[i].custom_minimum_size = zone_size
			_pitch_zones[i].size = zone_size

		# Chairs
		if GameManager.layout_config.has("chairs"):
			var chair_pos: Vector2 = GameManager.get_layout_position_px("chairs", i)
			if i < _chairs.size():
				_chairs[i].position = chair_pos - _chairs[i].size / 2

	# Dealer button
	var dealer_pos: Vector2 = GameManager.get_layout_position_px("dealer_buttons", GameManager.dealer_index)
	_dealer_button.custom_minimum_size = db_size
	_dealer_button.size = db_size
	_dealer_button.position = dealer_pos - db_size / 2
	var d_label: Label = _dealer_button.get_child(0)
	d_label.custom_minimum_size = db_size
	d_label.size = db_size
	d_label.add_theme_font_size_override("font_size", int(14 * db_scale))
	var d_bg: StyleBoxFlat = d_label.get_theme_stylebox("normal")
	d_bg.set_corner_radius_all(int(db_size.x / 2))
	d_bg.set_border_width_all(maxi(2, int(2 * db_scale)))

	# Pot
	var pot_pos: Vector2 = GameManager.get_layout_position_px("pot", -1)
	_pot_display.position = pot_pos - Vector2(30, 20)

	# Street badge
	_street_badge.position = pot_pos - Vector2(40, 50)

	# Community cards
	var comm_pos: Vector2 = GameManager.get_layout_position_px("community_cards", -1)
	_community_cards_container.position = comm_pos - Vector2(130, 33)

	# Muck
	var muck_pos: Vector2 = GameManager.get_layout_position_px("muck", -1)
	_muck_pile.position = muck_pos - Vector2(20, 20)

	# Pitch hand
	var ph_scale: float = GameManager.layout_config.get("pitch_hand_scale", 1.0)
	var ph_size := PITCH_HAND_BASE_SIZE * ph_scale
	var hand_pct: Vector2 = GameManager.layout_config.get("pitch_hand", TableLayout.DEFAULT_PITCH_HAND_PCT)
	var hand_pos: Vector2 = TableLayout.pct_to_px(hand_pct)
	_pitch_hand.custom_minimum_size = ph_size
	_pitch_hand.size = ph_size
	_pitch_hand.pivot_offset = ph_size / 2
	_pitch_hand.position = hand_pos - ph_size / 2
	_pitch_remaining_label.position = hand_pos + Vector2(-15, ph_size.y / 2 + 2)

	# Auto-pitch button
	_auto_pitch_btn.position = hand_pos + Vector2(-45, ph_size.y / 2 + 18)

	# Refresh cards with new scale if in layout mode
	if GameManager.layout_mode:
		_layout_editor.show_preview()

	# Action arrow — reposition if visible
	if _action_arrow.visible and GameManager.current_player_index >= 0:
		_stop_action_arrow_bounce()
		_position_action_arrow(GameManager.current_player_index)
		_start_action_arrow_bounce()
