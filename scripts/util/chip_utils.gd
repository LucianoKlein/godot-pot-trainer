class_name ChipUtils
## Chip Utilities — 筹码工具类
## 提供金额转筹码算法

# 筹码颜色枚举（与 Chip.gd 保持一致）
enum ChipColor {
	PURPLE500 = 500,
	BLACK100 = 100,
	GREEN25 = 25,
	RED5 = 5,
	WHITE1 = 1
}

## 将金额转换为筹码颜色数组（25/50 模式：紫500/黑100/绿25）
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

	var chips: Array = []
	for i in range(best_p):
		chips.append(ChipColor.PURPLE500)
	for i in range(best_b):
		chips.append(ChipColor.BLACK100)
	for i in range(best_g):
		chips.append(ChipColor.GREEN25)

	return chips


## 将金额转换为筹码颜色数组（5/10 模式：黑100/绿25/红5）
static func amount_to_chips_small(amount: int) -> Array:
	if amount <= 0:
		return []

	var best_b := 0
	var best_g := 0
	var best_r := 0
	var best_variance := INF

	var max_b := int(amount / 100)

	for b in range(max_b + 1):
		var rem1 := amount - b * 100
		var max_g := int(rem1 / 25)

		for g in range(max_g + 1):
			var rem2 := rem1 - g * 25
			if rem2 < 0 or rem2 % 5 != 0:
				continue

			var r := rem2 / 5
			var mean := (b + g + r) / 3.0
			var variance := pow(b - mean, 2) + pow(g - mean, 2) + pow(r - mean, 2)

			if variance < best_variance:
				best_variance = variance
				best_b = b
				best_g = g
				best_r = r

	var chips: Array = []
	for i in range(best_b):
		chips.append(ChipColor.BLACK100)
	for i in range(best_g):
		chips.append(ChipColor.GREEN25)
	for i in range(best_r):
		chips.append(ChipColor.RED5)

	return chips


## 将金额转换为筹码颜色数组（1/2 模式：绿25/红5/白1）
static func amount_to_chips_12(amount: int) -> Array:
	if amount <= 0:
		return []

	var best_g := 0
	var best_r := 0
	var best_w := 0
	var best_variance := INF

	var max_g := int(amount / 25)

	for g in range(max_g + 1):
		var rem1 := amount - g * 25
		var max_r := int(rem1 / 5)

		for r in range(max_r + 1):
			var w := rem1 - r * 5
			if w < 0:
				continue

			var mean := (g + r + w) / 3.0
			var variance := pow(g - mean, 2) + pow(r - mean, 2) + pow(w - mean, 2)

			if variance < best_variance:
				best_variance = variance
				best_g = g
				best_r = r
				best_w = w

	var chips: Array = []
	for i in range(best_g):
		chips.append(ChipColor.GREEN25)
	for i in range(best_r):
		chips.append(ChipColor.RED5)
	for i in range(best_w):
		chips.append(ChipColor.WHITE1)

	return chips


## 根据盲注模式自动选择转换函数
static func amount_to_chips_by_mode(amount: int, blinds_mode: String) -> Array:
	if blinds_mode == "1/2" or blinds_mode == "1/2/5":
		return amount_to_chips_12(amount)
	if blinds_mode == "5/10":
		return amount_to_chips_small(amount)
	return amount_to_chips(amount)


## 将筹码颜色枚举转换为字符串（用于 Chip.gd）
static func chip_color_to_string(color: ChipColor) -> String:
	match color:
		ChipColor.PURPLE500:
			return "purple500"
		ChipColor.BLACK100:
			return "black100"
		ChipColor.GREEN25:
			return "green25"
		ChipColor.RED5:
			return "red5"
		ChipColor.WHITE1:
			return "white1"
		_:
			return "purple500"


## 获取筹码面值
static func get_chip_value(color: ChipColor) -> int:
	return int(color)
