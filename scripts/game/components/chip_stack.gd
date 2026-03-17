extends Node2D
## ChipStack Component — 单色筹码垂直堆叠组件
## 用于显示玩家筹码堆

const Chip = preload("res://scripts/game/components/chip.gd")

@export var chip_color: ChipUtils.ChipColor = ChipUtils.ChipColor.PURPLE500
@export var chip_count: int = 5
@export var chip_size: float = 32.0
@export var spacing: float = 6.0  # 每层垂直间距（像素）
@export var use_random_angles: bool = true
@export var seed_value: int = 0

var _chip_nodes: Array[TextureRect] = []

# 伪随机数生成器（可复现）
var _rng: RandomNumberGenerator


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value if seed_value != 0 else Time.get_ticks_msec()
	_build_stack()


func set_stack(color: ChipUtils.ChipColor, count: int) -> void:
	chip_color = color
	chip_count = count
	if is_node_ready():
		_rebuild_stack()


func set_chip_size(new_size: float) -> void:
	chip_size = new_size
	if is_node_ready():
		_rebuild_stack()


func _build_stack() -> void:
	_clear_chips()

	for i in range(chip_count):
		var chip_node := TextureRect.new()
		chip_node.set_script(Chip)

		# 随机角度或固定角度
		var angle: int
		if use_random_angles:
			angle = _rng.randi_range(0, 3)
		else:
			angle = i % 4

		# 设置筹码属性（在 add_child 之前，避免 _ready 用默认值加载纹理）
		chip_node.chip_color = _map_chip_color_to_enum(chip_color)
		chip_node.chip_angle = angle
		chip_node.chip_size = chip_size
		chip_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip_node)

		# 位置：从下往上堆叠
		var y_offset := -i * spacing
		chip_node.position = Vector2(0, y_offset)

		# z_index：下层在前，上层在后
		chip_node.z_index = i

		_chip_nodes.append(chip_node)


func _rebuild_stack() -> void:
	_clear_chips()
	_build_stack()


func _clear_chips() -> void:
	for chip in _chip_nodes:
		chip.queue_free()
	_chip_nodes.clear()


func _map_chip_color_to_enum(color: ChipUtils.ChipColor) -> int:
	# 将 ChipUtils.ChipColor 映射到 Chip.ChipColor
	match color:
		ChipUtils.ChipColor.PURPLE500:
			return 7  # Chip.ChipColor.PURPLE500
		ChipUtils.ChipColor.BLACK100:
			return 8  # Chip.ChipColor.BLACK100
		ChipUtils.ChipColor.GREEN25:
			return 9  # Chip.ChipColor.GREEN25
		_:
			return 7


func get_stack_height() -> float:
	if chip_count <= 0:
		return 0.0
	return chip_size + (chip_count - 1) * spacing


func get_total_size() -> Vector2:
	return Vector2(chip_size, get_stack_height())
