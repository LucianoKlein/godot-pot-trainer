extends TextureRect
## Chip Component — 单枚筹码组件
## 支持9种面额 × 4个角度，动态加载 SVG 纹理

enum ChipColor {
	GREY5M,      # 5,000,000
	ORANGE1M,    # 1,000,000
	PINK500K,    # 500,000
	BLUE100K,    # 100,000
	GREEN25K,    # 25,000
	RED5K,       # 5,000
	YELLOW1K,    # 1,000
	PURPLE500,   # 500
	BLACK100,    # 100
	GREEN25      # 25
}

enum ChipAngle {
	ANG1,
	ANG2,
	ANG3,
	ANG4
}

@export var chip_color: ChipColor = ChipColor.PURPLE500
@export var chip_angle: ChipAngle = ChipAngle.ANG1
@export var chip_size: float = 32.0  # 基准尺寸（像素）

# 颜色名称映射（对应资源文件夹名）
const COLOR_NAMES = {
	ChipColor.GREY5M: "grey5m",
	ChipColor.ORANGE1M: "orange1m",
	ChipColor.PINK500K: "pink500k",
	ChipColor.BLUE100K: "blue100k",
	ChipColor.GREEN25K: "green25k",
	ChipColor.RED5K: "red5k",
	ChipColor.YELLOW1K: "yellow1k",
	ChipColor.PURPLE500: "purple500",
	ChipColor.BLACK100: "black100",
	ChipColor.GREEN25: "green25k"  # 使用 green25k 资源
}

# 角度名称映射
const ANGLE_NAMES = {
	ChipAngle.ANG1: "ang1",
	ChipAngle.ANG2: "ang2",
	ChipAngle.ANG3: "ang3",
	ChipAngle.ANG4: "ang4"
}

# 纹理缓存（避免重复加载）
static var _texture_cache: Dictionary = {}


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_load_texture()
	_apply_size()


func set_chip(color: ChipColor, angle: ChipAngle) -> void:
	chip_color = color
	chip_angle = angle
	if is_node_ready():
		_load_texture()


func set_chip_size(new_size: float) -> void:
	chip_size = new_size
	if is_node_ready():
		_apply_size()


func _load_texture() -> void:
	var color_name = COLOR_NAMES.get(chip_color, "purple500")
	var angle_name = ANGLE_NAMES.get(chip_angle, "ang1")
	var cache_key = "%s_%s" % [color_name, angle_name]

	# 检查缓存
	if _texture_cache.has(cache_key):
		texture = _texture_cache[cache_key]
		return

	# 加载纹理
	var path = "res://assets/chips/%s/%s.svg" % [color_name, angle_name]
	var tex = load(path) as Texture2D
	if tex:
		_texture_cache[cache_key] = tex
		texture = tex
	else:
		push_error("Failed to load chip texture: %s" % path)


func _apply_size() -> void:
	custom_minimum_size = Vector2(chip_size, chip_size)
	size = Vector2(chip_size, chip_size)
