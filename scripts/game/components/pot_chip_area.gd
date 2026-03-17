extends Control
## PotChipArea Component — 底池筹码区域组件
## 用于桌面中央底池的三角形散布布局

const Chip = preload("res://scripts/game/components/chip.gd")

@export var pot_total: int = 0
@export var area_width: float = 160.0
@export var area_height: float = 120.0
@export var chip_scale: float = 1.0
@export var is_editing: bool = false
@export var preset_chips: Array = []  # 可选：预设筹码数组

var _chip_nodes: Array[TextureRect] = []

# SVG viewBox 210.38 x 79.98
const CHIP_ASPECT := 210.38 / 79.98
const ANGLES := [0, 1, 2, 3]
const CHIP_SIZE_BASE := 32.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(area_width, area_height)
	size = Vector2(area_width, area_height)
	_rebuild()


func set_pot_total(amount: int) -> void:
	pot_total = amount
	if is_node_ready():
		_rebuild()


func set_area_size(width: float, height: float) -> void:
	area_width = width
	area_height = height
	custom_minimum_size = Vector2(width, height)
	size = Vector2(width, height)
	if is_node_ready():
		_rebuild()


func set_chip_scale(scale: float) -> void:
	chip_scale = scale
	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	_clear_chips()

	var chips: Array
	if not preset_chips.is_empty():
		chips = preset_chips
	else:
		var amount := pot_total if not is_editing else 7500
		if amount <= 0:
			return
		chips = ChipUtils.amount_to_chips(amount)

	if chips.is_empty():
		return

	var n := chips.size()
	var area_w := area_width
	var area_h := area_height
	var cx := area_w / 2.0
	var cy := area_h / 2.0

	var chip_size := CHIP_SIZE_BASE * chip_scale
	var chip_w := chip_size
	var ellipse_h := chip_w / CHIP_ASPECT
	var chip_v_offset := (chip_w - ellipse_h) / 2.0

	# stepX/stepY 大幅压缩，让椭圆默认重叠
	var step_x := roundi(chip_w * 0.7)
	var step_y := roundi(ellipse_h * 0.75)

	# 三角形尺寸随筹码数量动态增长
	var aspect := area_w / area_h
	var tri_h := sqrt((n * step_x * step_y * 2.0) / aspect)
	var tri_w := tri_h * aspect

	if tri_w > area_w:
		tri_w = area_w
		tri_h = tri_w / aspect
	if tri_h > area_h:
		tri_h = area_h
		tri_w = tri_h * aspect

	# 三角形中心对齐区域中心
	var tri_left := cx - tri_w / 2.0
	var tri_bottom := cy - tri_h / 2.0
	var tri_top := cy + tri_h / 2.0

	# 收集三角形内的所有格子坐标
	var slots: Array = []
	var col_count := ceili(tri_w / step_x) + 2
	var row_count := ceili(tri_h / step_y) + 2

	for row in range(row_count):
		for col in range(col_count):
			var left := tri_left + col * step_x
			var bottom := tri_bottom + row * step_y
			var center_x := left + step_x / 2.0
			var center_y := bottom + step_y / 2.0

			# v: 0=底边，1=尖角
			var v := (center_y - tri_bottom) / tri_h
			if v < 0 or v > 1:
				continue

			# 三角形内水平范围：越靠近尖角越窄
			var half_w := (tri_w / 2.0) * (1.0 - v)
			if center_x < cx - half_w or center_x > cx + half_w:
				continue

			var dx := center_x - cx
			var dy := center_y - cy
			var dist := sqrt(dx * dx + dy * dy)
			slots.append({"left": left, "bottom": bottom, "dist": dist})

	# 按距中心由近到远排序
	slots.sort_custom(func(a, b): return a.dist < b.dist)

	# 如果格子不够，超出部分往上堆叠
	var stack_map: Dictionary = {}

	var tokens: Array = []
	for idx in range(chips.size()):
		var color: ChipUtils.ChipColor = chips[idx]
		var left: float
		var bottom: float
		var dist: float

		if idx < slots.size():
			left = slots[idx].left
			bottom = slots[idx].bottom
			dist = slots[idx].dist
		else:
			# 超出三角形容量：在已有格子上往上堆
			var slot = slots[idx % slots.size()]
			var key := "%f_%f" % [slot.left, slot.bottom]
			var layer: int = stack_map.get(key, 0) + 1
			stack_map[key] = layer
			left = slot.left
			bottom = slot.bottom + layer * ellipse_h
			dist = slot.dist

		# 抖动极小
		var jx := (_seeded_random(idx * 7 + 1) - 0.5) * step_x * 0.15
		var jy := (_seeded_random(idx * 7 + 2) - 0.5) * step_y * 0.15

		left = clampf(left + jx, 0, area_w - chip_w)
		bottom = maxf(-chip_v_offset, bottom + jy - chip_v_offset)

		var angle: int = ANGLES[int(_seeded_random(idx * 7 + 3) * 4)]

		tokens.append({
			"id": idx,
			"color": color,
			"angle": angle,
			"left": left,
			"bottom": bottom,
			"dist": dist
		})

	# zIndex 按距离排：距中心越近越大
	tokens.sort_custom(func(a, b): return a.dist > b.dist)

	for i in range(tokens.size()):
		var token = tokens[i]
		_create_chip(token.color, token.angle, token.left, token.bottom, i + 1)


func _create_chip(color: ChipUtils.ChipColor, angle: int, left: float, bottom: float, z_idx: int) -> void:
	var chip_node := TextureRect.new()
	chip_node.set_script(Chip)

	# 设置筹码属性（在 add_child 之前，避免 _ready 用默认值加载纹理）
	chip_node.chip_color = _map_chip_color_to_enum(color)
	chip_node.chip_angle = angle
	chip_node.chip_size = CHIP_SIZE_BASE * chip_scale

	chip_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip_node)

	# Godot 使用左上原点，bottom 需要转换为 top
	chip_node.position = Vector2(left, area_height - bottom - chip_node.chip_size)
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
