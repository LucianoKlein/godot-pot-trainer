extends Node2D
## OrderedChipStacks Component — 整齐筹码堆叠布局组件
## 用于大量筹码（≥5枚）的整齐堆叠显示

const ChipStack = preload("res://scripts/game/components/chip_stack.gd")

@export var chip_size: float = 32.0
@export var stack_gap_x: float = 6.0  # 筹码堆横向间距
@export var stack_gap_y: float = 6.0  # 筹码堆纵向间距（行间距）

var _chips: Array = []  # ChipUtils.ChipColor array
var _stack_nodes: Array[Node2D] = []

const STACK_SPACING := 6.0  # 单个堆内垂直间距


func _ready() -> void:
	pass


func set_chips(chips: Array) -> void:
	_chips = chips
	if is_node_ready():
		_rebuild()


func set_chip_size(new_size: float) -> void:
	chip_size = new_size
	if is_node_ready():
		_rebuild()


func set_gaps(gap_x: float, gap_y: float) -> void:
	stack_gap_x = gap_x
	stack_gap_y = gap_y
	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	_clear_stacks()
	if _chips.is_empty():
		return

	# 按颜色分组
	var groups := _group_chips_by_color(_chips)

	# 将每组拆分为多个堆（purple500/green25 每堆4枚，black100 每堆5枚）
	var stacks: Array = []
	for group in groups:
		stacks.append_array(_split_into_stacks(group))

	# 布局：每行最多4堆
	var rows: Array = []
	for i in range(0, stacks.size(), 4):
		rows.append(stacks.slice(i, mini(i + 4, stacks.size())))

	# 创建堆节点
	var y_offset := 0.0
	for row in rows:
		var x_offset := 0.0
		var max_height := 0.0

		for stack_data in row:
			var stack_node := Node2D.new()
			stack_node.set_script(ChipStack)

			# 必须在 add_child 之前设置属性，否则 _ready() 用默认 PURPLE500
			stack_node.chip_color = stack_data.color
			stack_node.chip_count = stack_data.count
			stack_node.chip_size = chip_size
			stack_node.spacing = STACK_SPACING
			stack_node.use_random_angles = true

			add_child(stack_node)

			stack_node.position = Vector2(x_offset, y_offset)
			_stack_nodes.append(stack_node)

			var stack_height: float = stack_node.get_stack_height()
			max_height = maxf(max_height, stack_height)

			x_offset += chip_size + stack_gap_x

		y_offset += max_height + stack_gap_y


func _clear_stacks() -> void:
	for stack in _stack_nodes:
		stack.queue_free()
	_stack_nodes.clear()


## 按颜色分组（相同颜色连续的为一组）
func _group_chips_by_color(chips: Array) -> Array:
	var groups: Array = []
	var current_color = null
	var current_count := 0

	for chip_color in chips:
		if chip_color == current_color:
			current_count += 1
		else:
			if current_color != null:
				groups.append({"color": current_color, "count": current_count})
			current_color = chip_color
			current_count = 1

	if current_color != null:
		groups.append({"color": current_color, "count": current_count})

	return groups


## 将一组筹码拆分为多个堆
func _split_into_stacks(group: Dictionary) -> Array:
	var color: ChipUtils.ChipColor = group.color
	var count: int = group.count

	# purple500/green25 每堆4枚，black100 每堆5枚
	var stack_size := 5 if color == ChipUtils.ChipColor.BLACK100 else 4

	var stacks: Array = []
	var remaining := count

	while remaining > 0:
		var stack_count := mini(remaining, stack_size)
		stacks.append({"color": color, "count": stack_count})
		remaining -= stack_count

	return stacks


func get_total_size() -> Vector2:
	if _stack_nodes.is_empty():
		return Vector2.ZERO

	var max_x := 0.0
	var max_y := 0.0

	for stack in _stack_nodes:
		var pos := stack.position
		var height: float = stack.get_stack_height()
		max_x = maxf(max_x, pos.x + chip_size)
		max_y = maxf(max_y, pos.y + height)

	return Vector2(max_x, max_y)
