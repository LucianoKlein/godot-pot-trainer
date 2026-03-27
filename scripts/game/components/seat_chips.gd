class_name SeatChips
extends RefCounted
## SeatChips — 座位筹码显示组件
## 负责玩家筹码堆、下注筹码的创建、刷新和缩放

const ChipStack := preload("res://scripts/game/components/chip_stack.gd")
const BetChipStack := preload("res://scripts/game/components/bet_chip_stack.gd")
const OrderedChipStacks := preload("res://scripts/game/components/ordered_chip_stacks.gd")

var seat_index: int
var table_overlay: Control

var purple_stack: Node2D
var black_stack: Node2D
var green_stack: Node2D
var red_stack_1: Node2D
var red_stack_2: Node2D
var red_stack_3: Node2D
var white_stack: Node2D
var bet_chips_container: Control
var ordered_bet_chips: Node2D


func setup(index: int, overlay: Control) -> RefCounted:
	seat_index = index
	table_overlay = overlay
	return self


func build() -> void:
	var chip_scale: float = GameManager.layout_config.get("player_chip_scale", 1.0)
	var chip_size := 32.0 * chip_scale

	purple_stack = Node2D.new()
	purple_stack.set_script(ChipStack)
	purple_stack.name = "PurpleStack%d" % seat_index
	purple_stack.z_index = 12
	purple_stack.chip_color = ChipUtils.ChipColor.PURPLE500
	purple_stack.chip_count = 10
	purple_stack.chip_size = chip_size
	purple_stack.spacing = 6.0
	purple_stack.use_random_angles = true
	purple_stack.position = GameManager.get_layout_position_px("purple_stacks", seat_index)
	table_overlay.add_child(purple_stack)

	black_stack = Node2D.new()
	black_stack.set_script(ChipStack)
	black_stack.name = "BlackStack%d" % seat_index
	black_stack.z_index = 12
	black_stack.chip_color = ChipUtils.ChipColor.BLACK100
	black_stack.chip_count = 20
	black_stack.chip_size = chip_size
	black_stack.spacing = 6.0
	black_stack.use_random_angles = true
	black_stack.position = GameManager.get_layout_position_px("black_stacks", seat_index)
	table_overlay.add_child(black_stack)

	green_stack = Node2D.new()
	green_stack.set_script(ChipStack)
	green_stack.name = "GreenStack%d" % seat_index
	green_stack.z_index = 11
	green_stack.chip_color = ChipUtils.ChipColor.GREEN25
	green_stack.chip_count = 20
	green_stack.chip_size = chip_size
	green_stack.spacing = 6.0
	green_stack.use_random_angles = true
	green_stack.position = GameManager.get_layout_position_px("green_stacks", seat_index)
	table_overlay.add_child(green_stack)

	# 5/10 和 1/2 模式红色摞（默认隐藏）
	red_stack_1 = _build_stack_node("RedStack1_%d" % seat_index, ChipUtils.ChipColor.RED5, 20, chip_size, "red_stacks_1")
	red_stack_2 = _build_stack_node("RedStack2_%d" % seat_index, ChipUtils.ChipColor.RED5, 20, chip_size, "red_stacks_2")
	red_stack_3 = _build_stack_node("RedStack3_%d" % seat_index, ChipUtils.ChipColor.RED5, 20, chip_size, "red_stacks_3")
	red_stack_1.visible = false
	red_stack_2.visible = false
	red_stack_3.visible = false

	# 1/2 模式白色摞（默认隐藏，复用 green_stacks 位置偏移）
	white_stack = _build_stack_node("WhiteStack_%d" % seat_index, ChipUtils.ChipColor.WHITE1, 20, chip_size, "green_stacks")
	white_stack.visible = false

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
	var bm := GameManager.blinds_mode
	if bm == "1/2" or bm == "1/2/5":
		bet_chips_container.set_chips(TableLayout.get_default_bet_chips_12())
	elif bm == "5/10":
		bet_chips_container.set_chips(TableLayout.get_default_bet_chips_small())
	else:
		bet_chips_container.set_chips(TableLayout.get_default_bet_chips())

	ordered_bet_chips = Node2D.new()
	ordered_bet_chips.set_script(OrderedChipStacks)
	ordered_bet_chips.name = "OrderedBetChips%d" % seat_index
	ordered_bet_chips.z_index = 12
	var obc_scale: float = GameManager.layout_config.get("ordered_bet_chip_scale", 1.0)
	ordered_bet_chips.chip_size = 32.0 * obc_scale
	ordered_bet_chips.stack_gap_y = GameManager.layout_config.get("ordered_chip_v_gap", 6.0)
	ordered_bet_chips.position = GameManager.get_layout_position_px("ordered_bet_chips", seat_index)
	ordered_bet_chips.visible = false
	table_overlay.add_child(ordered_bet_chips)
	var bm2 := GameManager.blinds_mode
	if bm2 == "1/2" or bm2 == "1/2/5":
		ordered_bet_chips.set_chips(TableLayout.get_default_player_stack_chips_12())
	elif bm2 == "5/10":
		ordered_bet_chips.set_chips(TableLayout.get_default_player_stack_chips_small())
	else:
		ordered_bet_chips.set_chips(TableLayout.get_default_player_stack_chips())


func _build_stack_node(node_name: String, color: ChipUtils.ChipColor, count: int, chip_size: float, pos_key: String) -> Node2D:
	var stack := Node2D.new()
	stack.set_script(ChipStack)
	stack.name = node_name
	stack.z_index = 10
	stack.chip_color = color
	stack.chip_count = count
	stack.chip_size = chip_size
	stack.spacing = 6.0
	stack.use_random_angles = true
	stack.position = GameManager.get_layout_position_px(pos_key, seat_index)
	table_overlay.add_child(stack)
	return stack


func update_scale() -> void:
	var player_chip_scale: float = GameManager.layout_config.get("player_chip_scale", 1.0)
	var bet_chip_scale: float = GameManager.layout_config.get("bet_chip_scale", 1.0)
	var chip_size := 32.0 * player_chip_scale

	for stack in [purple_stack, black_stack, green_stack, red_stack_1, red_stack_2, red_stack_3, white_stack]:
		if is_instance_valid(stack):
			stack.chip_size = chip_size
			if stack.has_method("set_chip_size"):
				stack.set_chip_size(chip_size)
	if is_instance_valid(bet_chips_container):
		bet_chips_container.set_chip_scale(bet_chip_scale)
		bet_chips_container.set_spread_factor(GameManager.layout_config.get("bet_chip_spread", 1.0))
	if is_instance_valid(ordered_bet_chips):
		var obc_scale: float = GameManager.layout_config.get("ordered_bet_chip_scale", 1.0)
		ordered_bet_chips.set_chip_size(32.0 * obc_scale)
		ordered_bet_chips.set_v_gap(GameManager.layout_config.get("ordered_chip_v_gap", 6.0))


func set_default_display() -> void:
	var bm := GameManager.blinds_mode
	var is_12 := (bm == "1/2" or bm == "1/2/5")
	var is_small := (bm == "5/10")
	# 先全部隐藏，再按模式显示
	white_stack.visible = false
	red_stack_1.visible = false
	red_stack_2.visible = false
	red_stack_3.visible = false
	purple_stack.visible = false
	black_stack.visible = false
	green_stack.visible = true  # green 在所有模式都可见
	if is_12:
		# 1/2 模式：red5×60(3摞) + white1×20 + green25×8
		green_stack.set_stack(ChipUtils.ChipColor.GREEN25, 8)
		red_stack_1.set_stack(ChipUtils.ChipColor.RED5, 20)
		red_stack_2.set_stack(ChipUtils.ChipColor.RED5, 20)
		red_stack_3.set_stack(ChipUtils.ChipColor.RED5, 20)
		white_stack.set_stack(ChipUtils.ChipColor.WHITE1, 20)
		red_stack_1.visible = true
		red_stack_2.visible = true
		red_stack_3.visible = true
		white_stack.visible = true
		bet_chips_container.set_chips(TableLayout.get_default_bet_chips_12())
	elif is_small:
		# 5/10 模式：black100×5 + green25×20 + red5×60(3摞)
		black_stack.visible = true
		black_stack.set_stack(ChipUtils.ChipColor.BLACK100, 5)
		green_stack.set_stack(ChipUtils.ChipColor.GREEN25, 20)
		red_stack_1.set_stack(ChipUtils.ChipColor.RED5, 20)
		red_stack_2.set_stack(ChipUtils.ChipColor.RED5, 20)
		red_stack_3.set_stack(ChipUtils.ChipColor.RED5, 20)
		red_stack_1.visible = true
		red_stack_2.visible = true
		red_stack_3.visible = true
		bet_chips_container.set_chips(TableLayout.get_default_bet_chips_small())
	else:
		# 25/50 模式：purple500×10 + black100×20 + green25×20
		purple_stack.visible = true
		black_stack.visible = true
		purple_stack.set_stack(ChipUtils.ChipColor.PURPLE500, 10)
		black_stack.set_stack(ChipUtils.ChipColor.BLACK100, 20)
		green_stack.set_stack(ChipUtils.ChipColor.GREEN25, 20)
		bet_chips_container.set_chips(TableLayout.get_default_bet_chips())


func update_stack(amount: int) -> void:
	var bm := GameManager.blinds_mode
	var is_12 := (bm == "1/2" or bm == "1/2/5")
	var is_small := (bm == "5/10")
	if amount <= 0:
		_set_all_stacks_zero(is_small, is_12)
		return
	if is_12:
		_update_stack_12(amount)
	elif is_small:
		_update_stack_small(amount)
	else:
		_update_stack_normal(amount)


func _set_all_stacks_zero(is_small: bool, is_12: bool = false) -> void:
	if is_12:
		green_stack.set_stack(ChipUtils.ChipColor.GREEN25, 0)
		red_stack_1.set_stack(ChipUtils.ChipColor.RED5, 0)
		red_stack_2.set_stack(ChipUtils.ChipColor.RED5, 0)
		red_stack_3.set_stack(ChipUtils.ChipColor.RED5, 0)
		white_stack.set_stack(ChipUtils.ChipColor.WHITE1, 0)
	elif is_small:
		black_stack.set_stack(ChipUtils.ChipColor.BLACK100, 0)
		green_stack.set_stack(ChipUtils.ChipColor.GREEN25, 0)
		red_stack_1.set_stack(ChipUtils.ChipColor.RED5, 0)
		red_stack_2.set_stack(ChipUtils.ChipColor.RED5, 0)
		red_stack_3.set_stack(ChipUtils.ChipColor.RED5, 0)
	else:
		purple_stack.set_stack(ChipUtils.ChipColor.PURPLE500, 0)
		black_stack.set_stack(ChipUtils.ChipColor.BLACK100, 0)
		green_stack.set_stack(ChipUtils.ChipColor.GREEN25, 0)


func _update_stack_normal(amount: int) -> void:
	if amount == 7500:
		purple_stack.set_stack(ChipUtils.ChipColor.PURPLE500, 10)
		black_stack.set_stack(ChipUtils.ChipColor.BLACK100, 20)
		green_stack.set_stack(ChipUtils.ChipColor.GREEN25, 20)
		return
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


func _update_stack_small(amount: int) -> void:
	# 从初始分配（黑5×100 + 绿20×25 + 红60×5 = 1300）中扣减已花费金额
	var b_count := 5
	var g_count := 20
	var r_count := 60
	var spent := 1300 - amount
	if spent < 0:
		spent = 0
	# 从小面额优先扣除
	var r_remove := mini(spent / 5, r_count)
	spent -= r_remove * 5
	r_count -= r_remove
	var g_remove := mini(spent / 25, g_count)
	spent -= g_remove * 25
	g_count -= g_remove
	var b_remove := mini(spent / 100, b_count)
	b_count -= b_remove

	black_stack.set_stack(ChipUtils.ChipColor.BLACK100, b_count)
	green_stack.set_stack(ChipUtils.ChipColor.GREEN25, g_count)
	# 红色分3摞，每摞最多20
	var r1 := mini(r_count, 20)
	var r2 := mini(r_count - r1, 20)
	var r3 := maxi(r_count - r1 - r2, 0)
	red_stack_1.set_stack(ChipUtils.ChipColor.RED5, r1)
	red_stack_2.set_stack(ChipUtils.ChipColor.RED5, r2)
	red_stack_3.set_stack(ChipUtils.ChipColor.RED5, r3)


func _update_stack_12(amount: int) -> void:
	# 初始分配：green25×8 + red5×60 + white1×20 = 520
	var g_count := 8
	var r_count := 60
	var w_count := 20
	var spent := 520 - amount
	if spent < 0:
		spent = 0
	# 从小面额优先扣除
	var w_remove := mini(spent, w_count)
	spent -= w_remove
	w_count -= w_remove
	var r_remove := mini(spent / 5, r_count)
	spent -= r_remove * 5
	r_count -= r_remove
	var g_remove := mini(spent / 25, g_count)
	g_count -= g_remove

	green_stack.set_stack(ChipUtils.ChipColor.GREEN25, g_count)
	white_stack.set_stack(ChipUtils.ChipColor.WHITE1, w_count)
	var r1 := mini(r_count, 20)
	var r2 := mini(r_count - r1, 20)
	var r3 := maxi(r_count - r1 - r2, 0)
	red_stack_1.set_stack(ChipUtils.ChipColor.RED5, r1)
	red_stack_2.set_stack(ChipUtils.ChipColor.RED5, r2)
	red_stack_3.set_stack(ChipUtils.ChipColor.RED5, r3)


func update_bet(amount: int) -> void:
	if amount <= 0:
		bet_chips_container.set_chips([])
		return
	bet_chips_container.set_chips(ChipUtils.amount_to_chips_by_mode(amount, GameManager.blinds_mode))


func update_positions() -> void:
	purple_stack.position = GameManager.get_layout_position_px("purple_stacks", seat_index)
	black_stack.position = GameManager.get_layout_position_px("black_stacks", seat_index)
	green_stack.position = GameManager.get_layout_position_px("green_stacks", seat_index)
	red_stack_1.position = GameManager.get_layout_position_px("red_stacks_1", seat_index)
	red_stack_2.position = GameManager.get_layout_position_px("red_stacks_2", seat_index)
	red_stack_3.position = GameManager.get_layout_position_px("red_stacks_3", seat_index)
	white_stack.position = GameManager.get_layout_position_px("green_stacks", seat_index)
	var bet_pos: Vector2 = GameManager.get_layout_position_px("bets", seat_index)
	bet_chips_container.position = bet_pos - Vector2(40, 30)
	if is_instance_valid(ordered_bet_chips):
		ordered_bet_chips.position = GameManager.get_layout_position_px("ordered_bet_chips", seat_index)


func set_modulate(color: Color) -> void:
	for stack in [purple_stack, black_stack, green_stack, red_stack_1, red_stack_2, red_stack_3, white_stack]:
		stack.modulate = color
