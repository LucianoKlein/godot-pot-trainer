extends Control
## ScatteredChips Component — 散布筹码布局组件
## 用于少量筹码（<5枚）的固定布局显示，保证每枚筹码可见（最多30%遮盖）

@export var area_width: float = 80.0
@export var area_height: float = 60.0
@export var chip_scale: float = 1.0
@export var spread_factor: float = 1.0
@export var seed_value: int = 0

var _chips: Array = []
var _chip_nodes: Array[TextureRect] = []

const MIN_VISIBLE_RATIO := 0.7


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(area_width, area_height)
	size = Vector2(area_width, area_height)
	_rebuild()


func set_chips(chips: Array) -> void:
	_chips = chips
	if is_node_ready():
		_rebuild()


func set_chip_scale(scale: float) -> void:
	chip_scale = scale
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
	ChipRenderUtils.clear_chips(_chip_nodes)
	if _chips.is_empty():
		return

	var n: int = _chips.size()
	var chip_size := ChipRenderUtils.CHIP_SIZE_BASE * chip_scale
	var chip_w := chip_size
	var ellipse_h := chip_w / ChipRenderUtils.CHIP_ASPECT

	var step_x := chip_w * MIN_VISIBLE_RATIO * spread_factor
	var step_y := ellipse_h * MIN_VISIBLE_RATIO * spread_factor

	var offsets := _get_layout_offsets(n, step_x, step_y)

	# 动态扩展 area
	var needed_w := chip_w
	var needed_h := chip_size
	for off in offsets:
		needed_w = maxf(needed_w, absf(off.x) * 2.0 + chip_w)
		needed_h = maxf(needed_h, absf(off.y) * 2.0 + chip_size)

	var actual_w := maxf(area_width, needed_w)
	var actual_h := maxf(area_height, needed_h)
	custom_minimum_size = Vector2(actual_w, actual_h)
	size = Vector2(actual_w, actual_h)

	var cx := actual_w / 2.0
	var cy := actual_h / 2.0

	# 遮盖关系 → 角度避让
	var avoid_angles: Dictionary = {}
	if n == 3:
		avoid_angles[2] = [0, 1]
	elif n >= 4:
		avoid_angles[2] = [0]
		avoid_angles[3] = [1]

	var placed_angles: Array = []
	for idx in range(n):
		var color: ChipUtils.ChipColor = _chips[idx]
		var off: Vector2 = offsets[idx]
		var raw_angle: int = ChipRenderUtils.ANGLES[int(ChipRenderUtils.seeded_random(idx * 7 + 3) * 4)]

		var angle: int = raw_angle
		if avoid_angles.has(idx):
			var excluded: Array = []
			for covered_idx in avoid_angles[idx]:
				if covered_idx < placed_angles.size():
					excluded.append(placed_angles[covered_idx])
			angle = ChipRenderUtils.pick_angle_avoiding(raw_angle, excluded, idx * 7 + 5)
		placed_angles.append(angle)

		var jx := (ChipRenderUtils.seeded_random(idx * 7 + 1) - 0.5) * step_x * 0.1
		var jy := (ChipRenderUtils.seeded_random(idx * 7 + 2) - 0.5) * step_y * 0.1

		var left := cx + off.x - chip_w / 2.0 + jx
		var top := cy + off.y - chip_size / 2.0 + jy

		var chip_node := ChipRenderUtils.create_chip(color, angle, ChipRenderUtils.CHIP_SIZE_BASE * chip_scale)
		add_child(chip_node)
		chip_node.position = Vector2(left, top)
		chip_node.z_index = idx + 1
		_chip_nodes.append(chip_node)


func _get_layout_offsets(count: int, step_x: float, step_y: float) -> Array:
	match count:
		1:
			return [Vector2(0, 0)]
		2:
			var dx := step_x / 2.0
			return [Vector2(-dx, 0), Vector2(dx, 0)]
		3:
			var dx := step_x / 2.0
			var dy := step_y / 2.0
			return [Vector2(-dx, dy), Vector2(dx, dy), Vector2(0, -dy)]
		_:
			var dx := step_x / 2.0
			var dy := step_y / 2.0
			return [Vector2(-dx, dy), Vector2(dx, dy), Vector2(-dx, -dy), Vector2(dx, -dy)]
