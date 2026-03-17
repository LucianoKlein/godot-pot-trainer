class_name ChipUtils
## Chip Utilities — 筹码工具类
## 提供金额转筹码算法

# 筹码颜色枚举（与 Chip.gd 保持一致）
enum ChipColor {
	PURPLE500 = 500,
	BLACK100 = 100,
	GREEN25 = 25
}

## 将金额转换为筹码颜色数组
## 使用方差最小化算法，让三种颜色数量尽量均衡
static func amount_to_chips(amount: int) -> Array:
	if amount <= 0:
		return []

	var best_p := 0
	var best_b := 0
	var best_g := 0
	var best_variance := INF

	var max_p := int(amount / 500)

	for p in range(max_p + 1):
		var rem1 := amount - p * 500
		var max_b := int(rem1 / 100)
		var b_guess := roundi(rem1 / 300.0)
		var b_lo := maxi(0, b_guess - 8)
		var b_hi := mini(max_b, b_guess + 8)

		for b in range(b_lo, b_hi + 1):
			var rem2 := rem1 - b * 100
			if rem2 < 0 or rem2 % 25 != 0:
				continue

			var g := rem2 / 25
			var mean := (p + b + g) / 3.0
			var variance := pow(p - mean, 2) + pow(b - mean, 2) + pow(g - mean, 2)

			if variance < best_variance:
				best_variance = variance
				best_p = p
				best_b = b
				best_g = g

	# 构建筹码数组
	var chips: Array = []
	for i in range(best_p):
		chips.append(ChipColor.PURPLE500)
	for i in range(best_b):
		chips.append(ChipColor.BLACK100)
	for i in range(best_g):
		chips.append(ChipColor.GREEN25)

	return chips


## 将筹码颜色枚举转换为字符串（用于 Chip.gd）
static func chip_color_to_string(color: ChipColor) -> String:
	match color:
		ChipColor.PURPLE500:
			return "purple500"
		ChipColor.BLACK100:
			return "black100"
		ChipColor.GREEN25:
			return "green25"
		_:
			return "purple500"


## 获取筹码面值
static func get_chip_value(color: ChipColor) -> int:
	return int(color)
