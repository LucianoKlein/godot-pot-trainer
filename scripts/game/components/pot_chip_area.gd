extends Control
## PotChipArea Component — 底池筹码区域组件
## 用于桌面中央底池的三角形散布布局

@export var pot_total: int = 0
@export var area_width: float = 160.0
@export var area_height: float = 120.0
@export var chip_scale: float = 1.0
@export var is_editing: bool = false
@export var preset_chips: Array = []

var _chip_nodes: Array[TextureRect] = []


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
	ChipRenderUtils.clear_chips(_chip_nodes)

	var chips: Array
	if not preset_chips.is_empty():
		chips = preset_chips
	else:
		var amount: int = pot_total if not is_editing else 7500
		if amount <= 0:
			return
		chips = ChipUtils.amount_to_chips_by_mode(amount, GameManager.blinds_mode)

	if chips.is_empty():
		return

	var n: int = chips.size()
	var cx := area_width / 2.0
	var cy := area_height / 2.0
	var chip_size := ChipRenderUtils.CHIP_SIZE_BASE * chip_scale
	var chip_w := chip_size
	var ellipse_h := chip_w / ChipRenderUtils.CHIP_ASPECT
	var chip_v_offset := (chip_w - ellipse_h) / 2.0

	var step_x := roundi(chip_w * 0.7)
	var step_y := roundi(ellipse_h * 0.75)

	# 三角形尺寸随筹码数量动态增长
	var aspect := area_width / area_height
	var tri_h := sqrt((n * step_x * step_y * 2.0) / aspect)
	var tri_w := tri_h * aspect
	if tri_w > area_width:
		tri_w = area_width
		tri_h = tri_w / aspect
	if tri_h > area_height:
		tri_h = area_height
		tri_w = tri_h * aspect

	var tri_left := cx - tri_w / 2.0
	var tri_bottom := cy - tri_h / 2.0
	var tri_top := cy + tri_h / 2.0

	# 收集三角形内的所有格子坐标
	var slots: Array = []
	var col_count: int = ceili(tri_w / step_x) + 2
	var row_count: int = ceili(tri_h / step_y) + 2

	for row in range(row_count):
		for col in range(col_count):
			var left: float = tri_left + col * step_x
			var bottom: float = tri_bottom + row * step_y
			var center_x: float = left + step_x / 2.0
			var center_y: float = bottom + step_y / 2.0
			var v: float = (center_y - tri_bottom) / tri_h
			if v < 0 or v > 1:
				continue
			var half_w: float = (tri_w / 2.0) * (1.0 - v)
			if center_x < cx - half_w or center_x > cx + half_w:
				continue
			var dx: float = center_x - cx
			var dy: float = center_y - cy
			slots.append({"left": left, "bottom": bottom, "dist": sqrt(dx * dx + dy * dy)})

	slots.sort_custom(func(a, b): return a.dist < b.dist)

	var stack_map: Dictionary = {}
	var slot_last_angle: Dictionary = {}
	var tokens: Array = []

	for idx in range(chips.size()):
		var color: ChipUtils.ChipColor = chips[idx]
		var left: float
		var bottom: float
		var dist: float
		var slot_key: String

		if idx < slots.size():
			left = slots[idx].left
			bottom = slots[idx].bottom
			dist = slots[idx].dist
			slot_key = "%f_%f" % [left, bottom]
		else:
			var slot = slots[idx % slots.size()]
			slot_key = "%f_%f" % [slot.left, slot.bottom]
			var layer: int = stack_map.get(slot_key, 0) + 1
			stack_map[slot_key] = layer
			left = slot.left
			bottom = slot.bottom + layer * ellipse_h
			dist = slot.dist

		var jx := (ChipRenderUtils.seeded_random(idx * 7 + 1) - 0.5) * step_x * 0.15
		var jy := (ChipRenderUtils.seeded_random(idx * 7 + 2) - 0.5) * step_y * 0.15
		left = clampf(left + jx, 0, area_width - chip_w)
		bottom = maxf(-chip_v_offset, bottom + jy - chip_v_offset)

		var raw_angle: int = ChipRenderUtils.ANGLES[int(ChipRenderUtils.seeded_random(idx * 7 + 3) * 4)]
		var excluded: Array = [slot_last_angle[slot_key]] if slot_last_angle.has(slot_key) else []
		var angle: int = ChipRenderUtils.pick_angle_avoiding(raw_angle, excluded, idx * 7 + 5)
		slot_last_angle[slot_key] = angle

		tokens.append({"color": color, "angle": angle, "left": left, "bottom": bottom, "dist": dist})

	tokens.sort_custom(func(a, b): return a.dist > b.dist)

	for i in range(tokens.size()):
		var t = tokens[i]
		var chip_node := ChipRenderUtils.create_chip(t.color, t.angle, ChipRenderUtils.CHIP_SIZE_BASE * chip_scale)
		add_child(chip_node)
		chip_node.position = Vector2(t.left, area_height - t.bottom - chip_node.chip_size)
		chip_node.z_index = i + 1
		_chip_nodes.append(chip_node)
