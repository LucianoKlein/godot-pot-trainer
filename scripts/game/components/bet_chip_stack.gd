extends Control
## BetChipStack Component — 下注筹码自动切换组件
## 筹码总数 < 5 → 散落显示（ScatteredChips）
## 筹码总数 ≥ 5 → 整齐码放（OrderedChipStacks）

const ScatteredChips = preload("res://scripts/game/components/scattered_chips.gd")
const OrderedChipStacks = preload("res://scripts/game/components/ordered_chip_stacks.gd")

const THRESHOLD := 5  # 切换阈值

@export var area_width: float = 80.0
@export var area_height: float = 60.0
@export var chip_scale: float = 1.0
@export var spread_factor: float = 1.0  # 散落筹码间距倍率
@export var seed_value: int = 0

var _chips: Array = []
var _current_child: Node = null  # 当前显示的子组件
var _is_scattered: bool = true   # 当前是否散落模式


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(area_width, area_height)
	size = Vector2(area_width, area_height)


func set_chips(chips: Array) -> void:
	_chips = chips
	if is_node_ready():
		_rebuild()


func set_chip_scale(new_scale: float) -> void:
	chip_scale = new_scale
	if is_node_ready():
		_rebuild()


func set_spread_factor(factor: float) -> void:
	spread_factor = factor
	if is_node_ready():
		_rebuild()


func set_area_size(width: float, height: float) -> void:
	area_width = width
	area_height = height
	custom_minimum_size = Vector2(width, height)
	size = Vector2(width, height)
	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	var should_scatter := _chips.size() < THRESHOLD

	# 模式切换时销毁旧组件
	if _current_child != null and should_scatter != _is_scattered:
		_current_child.queue_free()
		_current_child = null

	_is_scattered = should_scatter

	if _chips.is_empty():
		if _current_child != null:
			_current_child.queue_free()
			_current_child = null
		return

	if _is_scattered:
		_rebuild_scattered()
	else:
		_rebuild_ordered()


func _rebuild_scattered() -> void:
	if _current_child == null or not is_instance_valid(_current_child):
		var node := Control.new()
		node.set_script(ScatteredChips)
		node.area_width = area_width
		node.area_height = area_height
		node.chip_scale = chip_scale
		node.spread_factor = spread_factor
		node.seed_value = seed_value
		add_child(node)
		_current_child = node
	else:
		_current_child.chip_scale = chip_scale
		_current_child.spread_factor = spread_factor
		_current_child.set_area_size(area_width, area_height)

	_current_child.set_chips(_chips)


func _rebuild_ordered() -> void:
	if _current_child == null or not is_instance_valid(_current_child):
		var node := Node2D.new()
		node.set_script(OrderedChipStacks)
		node.chip_size = 32.0 * chip_scale
		node.stack_gap_x = 6.0
		node.stack_gap_y = 6.0
		add_child(node)
		_current_child = node
	else:
		_current_child.set_chip_size(32.0 * chip_scale)

	_current_child.set_chips(_chips)
