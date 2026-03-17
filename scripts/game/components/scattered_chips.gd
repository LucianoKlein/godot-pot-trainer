extends Control
## ScatteredChips Component — 散布筹码布局组件
## 用于少量筹码（<5枚）的固定布局显示，保证每枚筹码可见（最多30%遮盖）

const Chip = preload("res://scripts/game/components/chip.gd")

@export var area_width: float = 80.0
@export var area_height: float = 60.0
@export var chip_scale: float = 1.0
@export var spread_factor: float = 1.0  # 间距倍率，1.0=默认，>1拉大间距
@export var seed_value: int = 0

var _chips: Array = []  # ChipUtils.ChipColor array
var _chip_nodes: Array[TextureRect] = []

# SVG viewBox 210.38 x 79.98，宽高比约 2.63:1
const CHIP_ASPECT := 210.38 / 79.98
const ANGLES := [0, 1, 2, 3]  # ang1-4
const CHIP_SIZE_BASE := 32.0
# 最大遮盖30% → 最小露出70% → 步长 = 尺寸 * 0.7
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
	_clear_chips()
	if _chips.is_empty():
		return

	var n := _chips.size()
	var chip_size := CHIP_SIZE_BASE * chip_scale
	var chip_w := chip_size
	var ellipse_h := chip_w / CHIP_ASPECT

	# 步长：保证最多30%遮盖，spread_factor 进一步拉大间距
	var step_x := chip_w * MIN_VISIBLE_RATIO * spread_factor
	var step_y := ellipse_h * MIN_VISIBLE_RATIO * spread_factor

	# 根据筹码数量计算固定布局位置（相对于中心的偏移）
	var offsets := _get_layout_offsets(n, step_x, step_y)

	# 计算布局所需的实际尺寸，动态扩展 area
	var needed_w := chip_w
	var needed_h := chip_size  # 用 chip_size（正方形包围盒高度）
	for off in offsets:
		needed_w = maxf(needed_w, absf(off.x) * 2.0 + chip_w)
		needed_h = maxf(needed_h, absf(off.y) * 2.0 + chip_size)

	var actual_w := maxf(area_width, needed_w)
	var actual_h := maxf(area_height, needed_h)
	custom_minimum_size = Vector2(actual_w, actual_h)
	size = Vector2(actual_w, actual_h)

	var cx := actual_w / 2.0
	var cy := actual_h / 2.0

	for idx in range(n):
		var color: ChipUtils.ChipColor = _chips[idx]
		var off: Vector2 = offsets[idx]
		var angle: int = ANGLES[int(_seeded_random(idx * 7 + 3) * 4)]

		# 小幅抖动（不超过步长的10%，保证不会额外遮盖）
		var jx := (_seeded_random(idx * 7 + 1) - 0.5) * step_x * 0.1
		var jy := (_seeded_random(idx * 7 + 2) - 0.5) * step_y * 0.1

		var left := cx + off.x - chip_w / 2.0 + jx
		var top := cy + off.y - chip_size / 2.0 + jy

		_create_chip_at(color, angle, left, top, idx + 1)


## 根据筹码数量返回每枚筹码相对于中心的偏移量
func _get_layout_offsets(count: int, step_x: float, step_y: float) -> Array:
	match count:
		1:
			return [Vector2(0, 0)]
		2:
			# 水平并排
			var dx := step_x / 2.0
			return [Vector2(-dx, 0), Vector2(dx, 0)]
		3:
			# 底部2枚 + 顶部1枚（倒三角）
			var dx := step_x / 2.0
			var dy := step_y / 2.0
			return [
				Vector2(-dx, dy),
				Vector2(dx, dy),
				Vector2(0, -dy),
			]
		_:
			# 4枚：2×2 网格
			var dx := step_x / 2.0
			var dy := step_y / 2.0
			return [
				Vector2(-dx, dy),
				Vector2(dx, dy),
				Vector2(-dx, -dy),
				Vector2(dx, -dy),
			]


func _create_chip_at(color: ChipUtils.ChipColor, angle: int, left: float, top: float, z_idx: int) -> void:
	var chip_node := TextureRect.new()
	chip_node.set_script(Chip)

	chip_node.chip_color = _map_chip_color_to_enum(color)
	chip_node.chip_angle = angle
	chip_node.chip_size = CHIP_SIZE_BASE * chip_scale

	chip_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip_node)

	chip_node.position = Vector2(left, top)
	chip_node.z_index = z_idx

	_chip_nodes.append(chip_node)


func _clear_chips() -> void:
	for chip in _chip_nodes:
		chip.queue_free()
	_chip_nodes.clear()


func _seeded_random(seed: int) -> float:
	var x := sin(seed * 127.1 + 311.7) * 43758.5453
	return x - floor(x)


func _map_chip_color_to_enum(color: ChipUtils.ChipColor) -> int:
	match color:
		ChipUtils.ChipColor.PURPLE500:
			return 7
		ChipUtils.ChipColor.BLACK100:
			return 8
		ChipUtils.ChipColor.GREEN25:
			return 9
		_:
			return 7
