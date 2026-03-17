class_name SeatUI
extends RefCounted
## SeatUI Component — 单个座位的所有 UI 元素管理
## 封装座位相关的构建、刷新、位置更新逻辑

const OutlineShader := preload("res://assets/shaders/outline.gdshader")
const ChipStack := preload("res://scripts/game/components/chip_stack.gd")
const BetChipStack := preload("res://scripts/game/components/bet_chip_stack.gd")
const CardDisplayScene := preload("res://scenes/game/components/card_display.tscn")

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
# Hole cards
var hole_cards_container: Control
var _hole_card_displays: Array = []  # Array of CardDisplay nodes
# 3 separate chip stacks (purple, black, green) — each independently draggable
var purple_stack: Node2D
var black_stack: Node2D
var green_stack: Node2D
var bet_chips_container: Control


func _init(index: int, overlay: Control) -> void:
	seat_index = index
	table_overlay = overlay


func build() -> void:
	_build_avatar()
	_build_labels()
	_build_hole_cards_container()
	_build_chip_containers()


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

	# Name label (below avatar)
	name_label = Label.new()
	name_label.text = "玩家%d" % (seat_index + 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.size = Vector2(av_size.x + 20, 16)
	name_label.position = avatar.position + Vector2(-10, av_size.y + 2)
	table_overlay.add_child(name_label)

	# Stack label (independent position from layout)
	stack_label = Label.new()
	stack_label.text = "7500"
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack_label.add_theme_font_size_override("font_size", 11)
	stack_label.add_theme_color_override("font_color", Color.WHITE)
	var stack_bg := StyleBoxFlat.new()
	stack_bg.bg_color = Color(0.1, 0.5, 0.1, 0.85)
	stack_bg.set_corner_radius_all(4)
	stack_bg.set_content_margin_all(3)
	stack_label.add_theme_stylebox_override("normal", stack_bg)
	stack_label.size = Vector2(60, 20)
	stack_label.z_index = 15
	var stack_pos: Vector2 = GameManager.get_layout_position_px("stacks", seat_index)
	stack_label.position = stack_pos - stack_label.size * 0.5
	table_overlay.add_child(stack_label)

	# Bet label (at bet position from layout)
	bet_label = Label.new()
	bet_label.text = ""
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bet_label.add_theme_font_size_override("font_size", 11)
	bet_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	var bet_bg := StyleBoxFlat.new()
	bet_bg.bg_color = Color(0.15, 0.15, 0.25, 0.85)
	bet_bg.set_corner_radius_all(4)
	bet_bg.set_content_margin_all(3)
	bet_label.add_theme_stylebox_override("normal", bet_bg)
	bet_label.size = Vector2(60, 20)
	bet_label.z_index = 15
	var bet_pos: Vector2 = GameManager.get_layout_position_px("bets", seat_index)
	bet_label.position = bet_pos - bet_label.size * 0.5
	table_overlay.add_child(bet_label)

	# Action box (independent position from layout)
	action_box = Label.new()
	action_box.name = "ActionBox%d" % seat_index
	action_box.text = ""
	action_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_box.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_box.add_theme_font_size_override("font_size", 22)
	action_box.add_theme_color_override("font_color", Color.WHITE)
	_action_style = StyleBoxFlat.new()
	_action_style.bg_color = Color(0.4, 0.4, 0.4, 0.85)
	_action_style.set_corner_radius_all(6)
	_action_style.set_content_margin_all(8)
	action_box.add_theme_stylebox_override("normal", _action_style)
	action_box.size = Vector2(160, 48)
	action_box.z_index = 16
	action_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_box.visible = false
	var action_box_pos: Vector2 = GameManager.get_layout_position_px("action_boxes", seat_index)
	action_box.position = action_box_pos - action_box.size * 0.5
	table_overlay.add_child(action_box)

	# Fold label (centered on avatar)
	fold_label = Label.new()
	fold_label.text = "弃牌"
	fold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fold_label.add_theme_font_size_override("font_size", 14)
	fold_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	fold_label.size = av_size
	fold_label.position = avatar.position
	fold_label.visible = false
	table_overlay.add_child(fold_label)

	# Seat badge (top-left of avatar)
	seat_badge = Label.new()
	seat_badge.text = "座%d" % (seat_index + 1)
	seat_badge.add_theme_font_size_override("font_size", 9)
	seat_badge.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	seat_badge.position = avatar.position + Vector2(0, -12)
	table_overlay.add_child(seat_badge)


func _build_hole_cards_container() -> void:
	hole_cards_container = Control.new()
	hole_cards_container.name = "HoleCards%d" % seat_index
	hole_cards_container.z_index = 6
	hole_cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_pos: Vector2 = GameManager.get_layout_position_px("cards", seat_index)
	hole_cards_container.position = card_pos
	table_overlay.add_child(hole_cards_container)


func _build_chip_containers() -> void:
	var chip_scale: float = GameManager.layout_config.get("player_chip_scale", 1.0)
	var chip_size := 32.0 * chip_scale

	# Purple stack (10 chips)
	purple_stack = Node2D.new()
	purple_stack.set_script(ChipStack)
	purple_stack.name = "PurpleStack%d" % seat_index
	purple_stack.z_index = 10
	purple_stack.chip_color = ChipUtils.ChipColor.PURPLE500
	purple_stack.chip_count = 10
	purple_stack.chip_size = chip_size
	purple_stack.spacing = 6.0
	purple_stack.use_random_angles = true
	var purple_pos: Vector2 = GameManager.get_layout_position_px("purple_stacks", seat_index)
	purple_stack.position = purple_pos
	table_overlay.add_child(purple_stack)

	# Black stack (20 chips)
	black_stack = Node2D.new()
	black_stack.set_script(ChipStack)
	black_stack.name = "BlackStack%d" % seat_index
	black_stack.z_index = 10
	black_stack.chip_color = ChipUtils.ChipColor.BLACK100
	black_stack.chip_count = 20
	black_stack.chip_size = chip_size
	black_stack.spacing = 6.0
	black_stack.use_random_angles = true
	var black_pos: Vector2 = GameManager.get_layout_position_px("black_stacks", seat_index)
	black_stack.position = black_pos
	table_overlay.add_child(black_stack)

	# Green stack (20 chips)
	green_stack = Node2D.new()
	green_stack.set_script(ChipStack)
	green_stack.name = "GreenStack%d" % seat_index
	green_stack.z_index = 10
	green_stack.chip_color = ChipUtils.ChipColor.GREEN25
	green_stack.chip_count = 20
	green_stack.chip_size = chip_size
	green_stack.spacing = 6.0
	green_stack.use_random_angles = true
	var green_pos: Vector2 = GameManager.get_layout_position_px("green_stacks", seat_index)
	green_stack.position = green_pos
	table_overlay.add_child(green_stack)

	# Player bet chips container (auto-switches scattered/ordered based on chip count)
	bet_chips_container = Control.new()
	bet_chips_container.set_script(BetChipStack)
	bet_chips_container.name = "PlayerBetChips%d" % seat_index
	bet_chips_container.z_index = 12
	var bet_pos: Vector2 = GameManager.get_layout_position_px("bets", seat_index)
	bet_chips_container.position = bet_pos - Vector2(40, 30)
	bet_chips_container.area_width = 80.0
	bet_chips_container.area_height = 60.0
	bet_chips_container.chip_scale = GameManager.layout_config.get("bet_chip_scale", 1.0)
	bet_chips_container.spread_factor = GameManager.layout_config.get("bet_chip_spread", 1.0)
	table_overlay.add_child(bet_chips_container)
	bet_chips_container.set_chips(TableLayout.get_default_bet_chips())


## 刷新座位显示（根据玩家数据或布局模式）
func refresh(player_data: PlayerData = null, layout_mode: bool = false) -> void:
	var visible_seat: bool = layout_mode or (player_data != null)

	avatar.visible = visible_seat
	name_label.visible = visible_seat
	fold_label.visible = false
	seat_badge.visible = visible_seat

	# In layout mode, chip/label visibility is controlled by LayoutVisibilityManager
	# In game mode, respect display_mode setting
	if not layout_mode:
		var is_numbers := GameManager.display_mode == "numbers"
		var has_bet: bool = player_data != null and player_data.round_contribution > 0
		stack_label.visible = visible_seat and is_numbers
		bet_label.visible = visible_seat and is_numbers and has_bet
		purple_stack.visible = visible_seat and not is_numbers
		black_stack.visible = visible_seat and not is_numbers
		green_stack.visible = visible_seat and not is_numbers
		bet_chips_container.visible = visible_seat and not is_numbers and has_bet
	else:
		stack_label.visible = visible_seat
		bet_label.visible = visible_seat

	if not visible_seat:
		return

	if layout_mode:
		# Layout mode: use fixed default chip presets
		if player_data:
			name_label.text = player_data.player_name
			stack_label.text = "%d" % player_data.chips
		else:
			name_label.text = "玩家%d" % (seat_index + 1)
			stack_label.text = "7500"
		bet_label.text = "100"
		_set_action_box("call", 200)
		action_box.visible = visible_seat
		avatar.modulate = Color.WHITE if player_data else Color(0.6, 0.6, 0.6, 0.7)
		_set_default_chip_display()
	elif player_data:
		# Real player data
		name_label.text = player_data.player_name
		stack_label.text = "%d" % player_data.chips

		# Update player chip stack display
		_update_chip_stack(player_data.chips)

		# Round contribution display
		if player_data.round_contribution > 0:
			bet_label.text = "%d" % player_data.round_contribution
			_update_bet_chips(player_data.round_contribution)
		else:
			bet_label.text = ""
			_update_bet_chips(0)

		# Action box
		if player_data.last_action != "":
			_set_action_box(player_data.last_action, player_data.round_contribution)
			action_box.visible = true
		else:
			action_box.visible = false

		# Fold overlay — dim avatar and chip stacks
		if player_data.folded:
			fold_label.visible = true
			var dim := Color(0.4, 0.4, 0.4)
			avatar.modulate = dim
			purple_stack.modulate = dim
			black_stack.modulate = dim
			green_stack.modulate = dim
		else:
			avatar.modulate = Color.WHITE
			purple_stack.modulate = Color.WHITE
			black_stack.modulate = Color.WHITE
			green_stack.modulate = Color.WHITE

	# Refresh hole cards display
	_refresh_hole_cards(player_data)


## 更新位置（响应布局变化）
func update_position() -> void:
	var avatar_scale: float = GameManager.layout_config.get("avatar_scale", 1.0)
	var per_seat_scales: Array = GameManager.layout_config.get("avatar_per_seat_scale", [])
	var seat_scale: float = per_seat_scales[seat_index] if seat_index < per_seat_scales.size() else 1.0
	var av_size := Vector2(70, 70) * avatar_scale * seat_scale
	var bet_scale: float = GameManager.layout_config.get("bet_label_scale", 1.0)
	var stack_scale: float = GameManager.layout_config.get("stack_label_scale", 1.0)
	var bet_font_size: int = int(11 * bet_scale)
	var stack_font_size: int = int(11 * stack_scale)

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

	# Stack label — independent position from layout
	var stack_pos: Vector2 = GameManager.get_layout_position_px("stacks", seat_index)
	stack_label.add_theme_font_size_override("font_size", stack_font_size)
	stack_label.size = Vector2(60 * stack_scale, 20 * stack_scale)
	stack_label.position = stack_pos - stack_label.size * 0.5

	# Bet label — independent position + scale
	var bet_pos: Vector2 = GameManager.get_layout_position_px("bets", seat_index)
	bet_label.add_theme_font_size_override("font_size", bet_font_size)
	bet_label.size = Vector2(60 * bet_scale, 20 * bet_scale)
	bet_label.position = bet_pos - bet_label.size * 0.5

	# Action box — independent position from layout
	var action_box_scale: float = GameManager.layout_config.get("action_box_scale", 1.0)
	var action_box_pos: Vector2 = GameManager.get_layout_position_px("action_boxes", seat_index)
	var ab_font_size: int = int(22 * action_box_scale)
	action_box.add_theme_font_size_override("font_size", ab_font_size)
	action_box.size = Vector2(160 * action_box_scale, 48 * action_box_scale)
	action_box.position = action_box_pos - action_box.size * 0.5

	fold_label.size = av_size
	fold_label.position = avatar.position

	seat_badge.position = avatar.position + Vector2(0, -12)

	# Update chip positions
	purple_stack.position = GameManager.get_layout_position_px("purple_stacks", seat_index)
	black_stack.position = GameManager.get_layout_position_px("black_stacks", seat_index)
	green_stack.position = GameManager.get_layout_position_px("green_stacks", seat_index)
	bet_chips_container.position = bet_pos - Vector2(40, 30)

	# Update hole cards position
	var card_pos: Vector2 = GameManager.get_layout_position_px("cards", seat_index)
	hole_cards_container.position = card_pos


## 设置当前玩家高亮
func set_current_player(is_current: bool, is_folded: bool = false) -> void:
	var mat: ShaderMaterial = avatar.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("enabled", is_current and not is_folded)


## 更新筹码缩放
func update_chip_scale() -> void:
	var player_chip_scale: float = GameManager.layout_config.get("player_chip_scale", 1.0)
	var bet_chip_scale: float = GameManager.layout_config.get("bet_chip_scale", 1.0)
	var chip_size := 32.0 * player_chip_scale

	if is_instance_valid(purple_stack):
		purple_stack.chip_size = chip_size
		if purple_stack.has_method("set_chip_size"):
			purple_stack.set_chip_size(chip_size)

	if is_instance_valid(black_stack):
		black_stack.chip_size = chip_size
		if black_stack.has_method("set_chip_size"):
			black_stack.set_chip_size(chip_size)

	if is_instance_valid(green_stack):
		green_stack.chip_size = chip_size
		if green_stack.has_method("set_chip_size"):
			green_stack.set_chip_size(chip_size)

	if is_instance_valid(bet_chips_container):
		bet_chips_container.set_chip_scale(bet_chip_scale)
		var bet_chip_spread: float = GameManager.layout_config.get("bet_chip_spread", 1.0)
		bet_chips_container.set_spread_factor(bet_chip_spread)


func _set_default_chip_display() -> void:
	# Default: 10 purple, 20 black, 20 green
	purple_stack.set_stack(ChipUtils.ChipColor.PURPLE500, 10)
	black_stack.set_stack(ChipUtils.ChipColor.BLACK100, 20)
	green_stack.set_stack(ChipUtils.ChipColor.GREEN25, 20)

	# Bet chips (BetChipStack always has set_chips)
	bet_chips_container.set_chips(TableLayout.get_default_bet_chips())


func _update_chip_stack(amount: int) -> void:
	if amount <= 0:
		purple_stack.set_stack(ChipUtils.ChipColor.PURPLE500, 0)
		black_stack.set_stack(ChipUtils.ChipColor.BLACK100, 0)
		green_stack.set_stack(ChipUtils.ChipColor.GREEN25, 0)
		return

	# Convert amount to chips and count per color
	var chips := ChipUtils.amount_to_chips(amount)
	var p_count := 0
	var b_count := 0
	var g_count := 0
	for c in chips:
		match c:
			ChipUtils.ChipColor.PURPLE500: p_count += 1
			ChipUtils.ChipColor.BLACK100: b_count += 1
			ChipUtils.ChipColor.GREEN25: g_count += 1

	purple_stack.set_stack(ChipUtils.ChipColor.PURPLE500, p_count)
	black_stack.set_stack(ChipUtils.ChipColor.BLACK100, b_count)
	green_stack.set_stack(ChipUtils.ChipColor.GREEN25, g_count)


func _update_bet_chips(amount: int) -> void:
	if amount <= 0:
		bet_chips_container.set_chips([])
		return

	var chips := ChipUtils.amount_to_chips(amount)
	bet_chips_container.set_chips(chips)


func _format_action(action: String) -> String:
	match action:
		"blind": return "盲注"
		"fold": return "弃牌"
		"check": return "过牌"
		"call": return "跟注"
		"bet": return "下注"
		"raise": return "加注"
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
	var text := "座%d " % (seat_index + 1) + _format_action(action)
	if amount > 0 and action not in ["fold", "check"]:
		text += " %d" % amount
	action_box.text = text
	_action_style.bg_color = _get_action_color(action)


func _refresh_hole_cards(player_data: PlayerData = null) -> void:
	# Clear existing
	for child in hole_cards_container.get_children():
		child.queue_free()
	_hole_card_displays.clear()

	if player_data == null or player_data.hole_cards.is_empty():
		hole_cards_container.visible = false
		return

	if player_data.folded:
		hole_cards_container.visible = false
		return

	hole_cards_container.visible = true
	var hc_scale: float = GameManager.layout_config.get("hole_card_scale", 0.55)
	var hc_gap: float = GameManager.layout_config.get("hole_card_gap", 0.6)
	var card_size := Vector2(48, 66) * hc_scale
	var rotation_deg: float = 0.0
	var rotations: Array = GameManager.layout_config.get("hole_card_rotation", [])
	if seat_index < rotations.size():
		rotation_deg = rotations[seat_index]

	var card_count := player_data.hole_cards.size()
	var total_w: float = card_size.x + (card_count - 1) * card_size.x * hc_gap
	var total_h: float = card_size.y

	# Create a container for all hole cards, rotate the container instead of individual cards
	var group := Control.new()
	group.custom_minimum_size = Vector2(total_w, total_h)
	group.size = Vector2(total_w, total_h)
	group.position = Vector2(-total_w / 2.0, -total_h / 2.0)
	group.pivot_offset = Vector2(total_w / 2.0, total_h / 2.0)
	group.rotation_degrees = rotation_deg
	hole_cards_container.add_child(group)

	for i in range(card_count):
		var display = CardDisplayScene.instantiate()
		display.custom_minimum_size = card_size
		display.size = card_size
		display.position = Vector2(i * card_size.x * hc_gap, 0)
		display.z_index = i
		display.seat_index = seat_index
		display.card_index = i
		group.add_child(display)
		if display.has_method("set_card"):
			display.set_card(player_data.hole_cards[i])
		_hole_card_displays.append(display)
