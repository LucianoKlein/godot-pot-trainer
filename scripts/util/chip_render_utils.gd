class_name ChipRenderUtils
extends RefCounted
## ChipRenderUtils — 共享筹码渲染工具
## 提供 seeded_random、颜色映射、筹码节点创建，消除 pot_chip_area/scattered_chips/chip_record 的重复代码

const Chip = preload("res://scripts/game/components/chip.gd")

# SVG viewBox 210.38 x 79.98
const CHIP_ASPECT := 210.38 / 79.98
const ANGLES := [0, 1, 2, 3]
const CHIP_SIZE_BASE := 32.0


## 确定性伪随机（基于 sin hash）
static func seeded_random(seed: int) -> float:
	var x := sin(seed * 127.1 + 311.7) * 43758.5453
	return x - floor(x)


## 确定性伪随机角度 (0-3)
static func pseudo_angle(seed_val: int) -> int:
	return int(seeded_random(seed_val) * 4) % 4


## ChipUtils.ChipColor → Chip.ChipColor 枚举映射
static func map_color(color: ChipUtils.ChipColor) -> int:
	match color:
		ChipUtils.ChipColor.PURPLE500: return 7
		ChipUtils.ChipColor.BLACK100: return 8
		ChipUtils.ChipColor.GREEN25: return 9
		ChipUtils.ChipColor.RED5: return 10
		ChipUtils.ChipColor.WHITE1: return 11
		_: return 7


## 创建筹码 TextureRect 节点（设置属性后再 add_child 以避免 _ready 用默认值）
static func create_chip(color: ChipUtils.ChipColor, angle: int, chip_size: float) -> TextureRect:
	var node := TextureRect.new()
	node.set_script(Chip)
	node.chip_color = map_color(color)
	node.chip_angle = angle
	node.chip_size = chip_size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 用 Chip.ChipColor 枚举直接创建（chip_record 用）
static func create_chip_raw(chip_color: int, angle: int, chip_size: float) -> TextureRect:
	var node := TextureRect.new()
	node.set_script(Chip)
	node.chip_color = chip_color
	node.chip_angle = angle
	node.chip_size = chip_size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 清除筹码节点数组
static func clear_chips(chip_nodes: Array) -> void:
	for chip in chip_nodes:
		chip.queue_free()
	chip_nodes.clear()


## 从排除列表中选择不同角度
static func pick_angle_avoiding(raw_angle: int, excluded: Array, seed: int) -> int:
	if raw_angle not in excluded:
		return raw_angle
	var candidates: Array = []
	for a in ANGLES:
		if a not in excluded:
			candidates.append(a)
	if candidates.is_empty():
		return raw_angle
	return candidates[int(seeded_random(seed) * candidates.size())]
