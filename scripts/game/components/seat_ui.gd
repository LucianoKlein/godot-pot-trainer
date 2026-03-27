class_name SeatUI
extends RefCounted
## SeatUI Component — 单个座位的所有 UI 元素管理
## 封装座位相关的构建、刷新、位置更新逻辑

const OutlineShader := preload("res://assets/shaders/outline.gdshader")
const SeatChipsScript := preload("res://scripts/game/components/seat_chips.gd")
const SeatHoleCardsScript := preload("res://scripts/game/components/seat_hole_cards.gd")

# Fixed player images per seat (座位1→Image 3, 座位2→Image 4, etc.)
static var _player_image_ids: Array = [3, 4, 6, 7, 9, 10, 11, 12, 13]

static func _get_image_id_for_seat(seat_index: int) -> int:
	return _player_image_ids[seat_index % _player_image_ids.size()]

var seat_index: int
var table_overlay: Control

# UI 节点
var avatar: TextureRect
var name_label: Label
var stack_label: Label
var bet_label: Label
var action_box: Label
var _action_style: StyleBoxFlat
var fold_label: Label
var seat_badge: Label
# Delegated components
var _chips: SeatChips
var _hole_cards: SeatHoleCards

# Proxy accessors for external code (layout_editor, seat_manager, etc.)
var hole_cards_container: Control:
	get: return _hole_cards.container
var purple_stack: Node2D:
	get: return _chips.purple_stack
var black_stack: Node2D:
	get: return _chips.black_stack
var green_stack: Node2D:
	get: return _chips.green_stack
var bet_chips_container: Control:
	get: return _chips.bet_chips_container
var ordered_bet_chips: Node2D:
	get: return _chips.ordered_bet_chips
var red_stack_1: Node2D:
	get: return _chips.red_stack_1
var red_stack_2: Node2D:
	get: return _chips.red_stack_2
var red_stack_3: Node2D:
	get: return _chips.red_stack_3
var white_stack: Node2D:
	get: return _chips.white_stack


func setup(index: int, overlay: Control) -> RefCounted:
	seat_index = index
	table_overlay = overlay
	return self


func build() -> void:
	_build_avatar()
	_build_labels()
	_hole_cards = SeatHoleCardsScript.new().setup(seat_index, table_overlay)
	_hole_cards.build()
	_chips = SeatChipsScript.new().setup(seat_index, table_overlay)
	_chips.build()


func _build_avatar() -> void:
	avatar = TextureRect.new()
	avatar.name = "Avatar%d" % seat_index
	var img_id: int = _get_image_id_for_seat(seat_index)
	avatar.texture = load("res://assets/new_plays/Image %d.png" % img_id)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2(70, 70)
	avatar.size = Vector2(70, 70)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Outline shader for current player highlight
	var mat := ShaderMaterial.new()
	mat.shader = OutlineShader
	mat.set_shader_parameter("enabled", false)
	mat.set_shader_parameter("outline_color", Color(1.0, 0.84, 0.0, 1.0))
	mat.set_shader_parameter("outline_width", 20.0)
	avatar.material = mat

	var seat_pos: Vector2 = GameManager.get_layout_position_px("seats", seat_index)
	avatar.position = seat_pos - avatar.size * 0.5
	table_overlay.add_child(avatar)


func _build_labels() -> void:
	var av_size := Vector2(70, 70)
	var seat_pos: Vector2 = GameManager.get_layout_position_px("seats", seat_index)

	# Name label
	name_label = Label.new()
	name_label.name = "Name%d" % seat_index
	name_label.text = Locale.tr_key("player_n") % (seat_index + 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size.x = av_size.x + 20
	name_label.position = seat_pos - av_size * 0.5 + Vector2(-10, av_size.y + 2)
	name_label.z_index = 5
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_overlay.add_child(name_label)

	# Stack label
	var stack_scale: float = GameManager.layout_config.get("stack_label_scale", 1.0)
	stack_label = Label.new()
	stack_label.name = "Stack%d" % seat_index
	stack_label.text = "7500"
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack_label.add_theme_font_size_override("font_size", int(11 * stack_scale))
	stack_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	var stack_pos: Vector2 = GameManager.get_layout_position_px("stacks", seat_index)
	stack_label.size = Vector2(60 * stack_scale, 20 * stack_scale)
	stack_label.position = stack_pos - stack_label.size * 0.5
	stack_label.z_index = 5
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_overlay.add_child(stack_label)

	# Bet label
	var bet_scale: float = GameManager.layout_config.get("bet_label_scale", 1.0)
	bet_label = Label.new()
	bet_label.name = "Bet%d" % seat_index
	bet_label.text = ""
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet_label.add_theme_font_size_override("font_size", int(11 * bet_scale))
	bet_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	var bet_pos: Vector2 = GameManager.get_layout_position_px("bets", seat_index)
	bet_label.size = Vector2(60 * bet_scale, 20 * bet_scale)
	bet_label.position = bet_pos - bet_label.size * 0.5
	bet_label.z_index = 5
	bet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_overlay.add_child(bet_label)

	# Action box
	var action_box_scale: float = GameManager.layout_config.get("action_box_scale", 1.0)
	action_box = Label.new()
	action_box.name = "ActionBox%d" % seat_index
	action_box.text = ""
	action_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_box.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_box.add_theme_font_size_override("font_size", int(22 * action_box_scale))
	action_box.add_theme_color_override("font_color", Color.WHITE)
	_action_style = UiFactory.make_stylebox(Color(0.2, 0.4, 0.7, 0.85), 8, 6)
	action_box.add_theme_stylebox_override("normal", _action_style)
	var action_box_pos: Vector2 = GameManager.get_layout_position_px("action_boxes", seat_index)
	action_box.size = Vector2(160 * action_box_scale, 48 * action_box_scale)
	action_box.position = action_box_pos - action_box.size * 0.5
	action_box.z_index = 15
	action_box.visible = false
	action_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_overlay.add_child(action_box)

	# Fold label
	fold_label = Label.new()
	fold_label.name = "Fold%d" % seat_index
	fold_label.text = Locale.tr_key("action_fold")
	fold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fold_label.add_theme_font_size_override("font_size", 16)
	fold_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	fold_label.size = av_size
	fold_label.position = seat_pos - av_size * 0.5
	fold_label.z_index = 7
	fold_label.visible = false
	fold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_overlay.add_child(fold_label)

	# Seat badge
	seat_badge = Label.new()
	seat_badge.name = "SeatBadge%d" % seat_index
	seat_badge.text = "%d" % (seat_index + 1)
	seat_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seat_badge.add_theme_font_size_override("font_size", 9)
	seat_badge.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.6))
	seat_badge.position = seat_pos - av_size * 0.5 + Vector2(0, -12)
	seat_badge.z_index = 5
	seat_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_overlay.add_child(seat_badge)


## 刷新座位显示（根据玩家数据或布局模式）
func refresh(player_data: RefCounted = null, layout_mode: bool = false) -> void:
	var visible_seat: bool = layout_mode or (player_data != null)

	avatar.visible = visible_seat
	name_label.visible = visible_seat
	fold_label.visible = false
	seat_badge.visible = visible_seat

	if not layout_mode:
		var is_numbers: bool = GameManager.display_mode == "numbers"
		var bm: String = GameManager.blinds_mode
		var is_12: bool = (bm == "1/2" or bm == "1/2/5")
		var is_small: bool = (bm == "5/10")
		var has_bet: bool = player_data != null and player_data.round_contribution > 0
		stack_label.visible = visible_seat and is_numbers
		bet_label.visible = visible_seat and is_numbers and has_bet
		var show_chips: bool = visible_seat and not is_numbers
		_chips.purple_stack.visible = show_chips and not is_small and not is_12
		_chips.black_stack.visible = show_chips and not is_12
		_chips.green_stack.visible = show_chips
		_chips.red_stack_1.visible = show_chips and (is_small or is_12)
		_chips.red_stack_2.visible = show_chips and (is_small or is_12)
		_chips.red_stack_3.visible = show_chips and (is_small or is_12)
		_chips.white_stack.visible = show_chips and is_12
		_chips.bet_chips_container.visible = show_chips and has_bet
	else:
		stack_label.visible = visible_seat
		bet_label.visible = visible_seat

	if not visible_seat:
		return

	if layout_mode:
		var bm_layout: String = GameManager.blinds_mode
		var default_stack: int = 520 if (bm_layout == "1/2" or bm_layout == "1/2/5") else (1300 if bm_layout == "5/10" else 7500)
		if player_data:
			name_label.text = player_data.player_name
			stack_label.text = "%d" % player_data.chips
		else:
			name_label.text = Locale.tr_key("player_n") % (seat_index + 1)
			stack_label.text = "%d" % default_stack
		bet_label.text = "100"
		_set_action_box("call", 200)
		action_box.visible = visible_seat
		avatar.modulate = Color.WHITE if player_data else Color(0.6, 0.6, 0.6, 0.7)
		_chips.set_default_display()
	elif player_data:
		name_label.text = player_data.player_name
		stack_label.text = "%d" % player_data.chips
		_chips.update_stack(player_data.chips)

		if player_data.round_contribution > 0:
			bet_label.text = "%d" % player_data.round_contribution
			_chips.update_bet(player_data.round_contribution)
		else:
			bet_label.text = ""
			_chips.update_bet(0)

		if player_data.last_action != "":
			_set_action_box(player_data.last_action, player_data.round_contribution)
			if GameManager.config.training_mode != "game":
				action_box.visible = true
		else:
			action_box.visible = false

		if player_data.folded:
			fold_label.visible = true
			var dim := Color(0.4, 0.4, 0.4)
			avatar.modulate = dim
			_chips.set_modulate(dim)
		else:
			avatar.modulate = Color.WHITE
			_chips.set_modulate(Color.WHITE)

	_hole_cards.refresh(player_data)


## 更新位置（响应布局变化）
func update_position() -> void:
	var avatar_scale: float = GameManager.layout_config.get("avatar_scale", 1.0)
	var per_seat_scales: Array = GameManager.layout_config.get("avatar_per_seat_scale", [])
	var seat_scale: float = per_seat_scales[seat_index] if seat_index < per_seat_scales.size() else 1.0
	var av_size := Vector2(70, 70) * avatar_scale * seat_scale
	var bet_scale: float = GameManager.layout_config.get("bet_label_scale", 1.0)
	var stack_scale: float = GameManager.layout_config.get("stack_label_scale", 1.0)

	var seat_pos: Vector2 = GameManager.get_layout_position_px("seats", seat_index)
	avatar.custom_minimum_size = av_size
	avatar.size = av_size
	avatar.position = seat_pos - av_size * 0.5
	avatar.pivot_offset = av_size * 0.5
	var avatar_rotations: Array = GameManager.layout_config.get("avatar_rotation", [])
	if seat_index < avatar_rotations.size():
		avatar.rotation_degrees = avatar_rotations[seat_index]
	else:
		avatar.rotation_degrees = 0.0

	name_label.size.x = av_size.x + 20
	name_label.position = avatar.position + Vector2(-10, av_size.y + 2)

	var stack_pos: Vector2 = GameManager.get_layout_position_px("stacks", seat_index)
	stack_label.add_theme_font_size_override("font_size", int(11 * stack_scale))
	stack_label.size = Vector2(60 * stack_scale, 20 * stack_scale)
	stack_label.position = stack_pos - stack_label.size * 0.5

	var bet_pos: Vector2 = GameManager.get_layout_position_px("bets", seat_index)
	bet_label.add_theme_font_size_override("font_size", int(11 * bet_scale))
	bet_label.size = Vector2(60 * bet_scale, 20 * bet_scale)
	bet_label.position = bet_pos - bet_label.size * 0.5

	var action_box_scale: float = GameManager.layout_config.get("action_box_scale", 1.0)
	var action_box_pos: Vector2 = GameManager.get_layout_position_px("action_boxes", seat_index)
	action_box.add_theme_font_size_override("font_size", int(22 * action_box_scale))
	action_box.size = Vector2(160 * action_box_scale, 48 * action_box_scale)
	action_box.position = action_box_pos - action_box.size * 0.5

	fold_label.size = av_size
	fold_label.position = avatar.position
	seat_badge.position = avatar.position + Vector2(0, -12)

	_chips.update_positions()
	_hole_cards.update_position()


## 设置当前玩家高亮
func set_current_player(is_current: bool, is_folded: bool = false) -> void:
	var mat: ShaderMaterial = avatar.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("enabled", is_current and not is_folded)


## 更新筹码缩放
func update_chip_scale() -> void:
	_chips.update_scale()


func _format_action(action: String) -> String:
	match action:
		"blind": return Locale.tr_key("action_blind")
		"fold": return Locale.tr_key("action_fold")
		"check": return Locale.tr_key("action_check")
		"call": return Locale.tr_key("action_call")
		"bet": return Locale.tr_key("action_bet")
		"raise": return Locale.tr_key("action_raise")
		_: return ""


func _get_action_color(action: String) -> Color:
	match action:
		"fold": return Color(0.7, 0.2, 0.2, 0.85)
		"check": return Color(0.4, 0.4, 0.4, 0.85)
		"call": return Color(0.2, 0.4, 0.7, 0.85)
		"bet", "raise": return Color(0.2, 0.6, 0.3, 0.85)
		"blind": return Color(0.7, 0.5, 0.1, 0.85)
		_: return Color(0.4, 0.4, 0.4, 0.85)


func _set_action_box(action: String, amount: int = 0) -> void:
	var text := Locale.tr_key("seat_action_prefix") % (seat_index + 1) + _format_action(action)
	if amount > 0 and action not in ["fold", "check"]:
		text += " %d" % amount
	action_box.text = text
	_action_style.bg_color = _get_action_color(action)
