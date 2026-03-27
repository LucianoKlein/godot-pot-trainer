class_name TableLayout
extends RefCounted

# Background now fills the entire viewport (1920x1080)
const BG_OFFSET := Vector2(0.0, 0.0)
const BG_SIZE := Vector2(1920.0, 1080.0)

# Convert percentage position (relative to poker-table div) to pixel position
static func pct_to_px(pct: Vector2) -> Vector2:
	return Vector2(
		BG_OFFSET.x + (pct.x / 100.0) * BG_SIZE.x,
		BG_OFFSET.y + (pct.y / 100.0) * BG_SIZE.y
	)

# Convert pixel position back to percentage
static func px_to_pct(px: Vector2) -> Vector2:
	return Vector2(
		((px.x - BG_OFFSET.x) / BG_SIZE.x) * 100.0,
		((px.y - BG_OFFSET.y) / BG_SIZE.y) * 100.0
	)

# --- Default layout from defaultLayout.json (percentage values) ---

const DEFAULT_SEATS_PCT := [
	Vector2(31.24, 82.74), Vector2(5.76, 68.98), Vector2(5.65, 17.11),
	Vector2(24.29, 5.33), Vector2(49.89, 4.37), Vector2(76.58, 6.31),
	Vector2(94.96, 15.46), Vector2(93.11, 71.11), Vector2(74.68, 81.1),
]

const DEFAULT_CARDS_PCT := [
	Vector2(35.09, 66.3), Vector2(11.08, 55.88), Vector2(14.08, 25.38),
	Vector2(25.37, 19.75), Vector2(50.96, 19.83), Vector2(76.21, 18.69),
	Vector2(87.83, 25.67), Vector2(86.46, 49.21), Vector2(72.19, 65.14),
]

const DEFAULT_STACKS_PCT := [
	Vector2(26.37, 67.48), Vector2(14.19, 62.75), Vector2(9.9, 28.75),
	Vector2(30.32, 17.27), Vector2(46.9, 17.2), Vector2(71.97, 17.27),
	Vector2(84.55, 20.25), Vector2(87.16, 61.97), Vector2(77.06, 67.39),
]

# Per-color chip stack positions (hardcoded from layout editor)
const DEFAULT_PURPLE_STACKS_PCT := [
	Vector2(24.47, 67.0), Vector2(12.45, 62.94), Vector2(8.05, 32.42),
	Vector2(29.72, 19.2), Vector2(55.54, 19.91), Vector2(66.32, 18.23),
	Vector2(88.3, 38.99), Vector2(85.59, 62.36), Vector2(74.94, 66.32),
]

const DEFAULT_BLACK_STACKS_PCT := [
	Vector2(27.2, 67.77), Vector2(15.18, 64.0), Vector2(9.92, 35.9),
	Vector2(32.24, 19.88), Vector2(57.73, 20.0), Vector2(68.84, 18.23),
	Vector2(90.33, 39.48), Vector2(88.16, 61.39), Vector2(77.46, 67.1),
]

const DEFAULT_GREEN_STACKS_PCT := [
	Vector2(29.77, 67.97), Vector2(17.65, 64.49), Vector2(12.43, 36.29),
	Vector2(34.75, 19.88), Vector2(60.14, 19.81), Vector2(71.25, 18.13),
	Vector2(92.63, 40.06), Vector2(90.51, 61.3), Vector2(79.92, 66.03),
]

# 5/10 模式：红色筹码3摞位置（复用紫/黑/绿的位置）
const DEFAULT_RED_STACK1_PCT := [
	Vector2(24.47, 67.0), Vector2(12.45, 62.94), Vector2(8.05, 32.42),
	Vector2(29.72, 19.2), Vector2(55.54, 19.91), Vector2(66.32, 18.23),
	Vector2(88.3, 38.99), Vector2(85.59, 62.36), Vector2(74.94, 66.32),
]

const DEFAULT_RED_STACK2_PCT := [
	Vector2(27.2, 67.77), Vector2(15.18, 64.0), Vector2(9.92, 35.9),
	Vector2(32.24, 19.88), Vector2(57.73, 20.0), Vector2(68.84, 18.23),
	Vector2(90.33, 39.48), Vector2(88.16, 61.39), Vector2(77.46, 67.1),
]

const DEFAULT_RED_STACK3_PCT := [
	Vector2(29.77, 67.97), Vector2(17.65, 64.49), Vector2(12.43, 36.29),
	Vector2(34.75, 19.88), Vector2(60.14, 19.81), Vector2(71.25, 18.13),
	Vector2(92.63, 40.06), Vector2(90.51, 61.3), Vector2(79.92, 66.03),
]

# Legacy helper (kept for compatibility)
const STACK_COLOR_OFFSET_X := 2.3

static func _make_color_stack_defaults(offset_index: int) -> Array:
	match offset_index:
		0: return DEFAULT_PURPLE_STACKS_PCT.duplicate()
		1: return DEFAULT_BLACK_STACKS_PCT.duplicate()
		2: return DEFAULT_GREEN_STACKS_PCT.duplicate()
		3: return DEFAULT_RED_STACK1_PCT.duplicate()
		4: return DEFAULT_RED_STACK2_PCT.duplicate()
		5: return DEFAULT_RED_STACK3_PCT.duplicate()
	var arr: Array = []
	for base in DEFAULT_STACKS_PCT:
		arr.append(Vector2(base.x + offset_index * STACK_COLOR_OFFSET_X, base.y))
	return arr

const DEFAULT_BETS_PCT := [
	Vector2(39.48, 52.36), Vector2(17.6, 45.06), Vector2(19.3, 37.07),
	Vector2(32.17, 29.65), Vector2(46.1, 29.63), Vector2(70.0, 28.84),
	Vector2(80.66, 31.55), Vector2(79.37, 50.28), Vector2(66.4, 53.21),
]

const DEFAULT_DEALER_BUTTONS_PCT := [
	Vector2(34.49, 52.42), Vector2(21.12, 49.38), Vector2(20.69, 31.99),
	Vector2(27.23, 30.17), Vector2(51.74, 30.16), Vector2(76.09, 30.46),
	Vector2(82.94, 35.54), Vector2(82.72, 45.19), Vector2(71.66, 52.65),
]

const DEFAULT_POT_PCT := Vector2(36.75, 42.95)
const DEFAULT_MUCK_PCT := Vector2(41.99, 59.87)
const DEFAULT_COMMUNITY_CARDS_PCT := Vector2(55.85, 39.74)
const DEFAULT_PITCH_HAND_PCT := Vector2(50.0, 97.0)
const DEFAULT_CHIP_RECORD_PCT := Vector2(50.71, 64.2)
const DEFAULT_STREET_BADGE_PCT := Vector2(36.92, 35.49)

# Ordered bet chips — offset slightly from bet positions
const DEFAULT_ORDERED_BET_CHIPS_PCT := [
	Vector2(27.23, 44.05), Vector2(17.8, 43.72), Vector2(18.03, 28.56),
	Vector2(28.3, 26.36), Vector2(47.5, 26.63), Vector2(65.22, 26.05),
	Vector2(76.38, 27.19), Vector2(74.56, 42.85), Vector2(64.3, 42.48),
]

const DEFAULT_HOLE_CARD_ROTATION := [
	0.0, 48.0, -46.0, 0.0, 0.0, 0.0, -114.0, -57.0, 0.0,
]

const DEFAULT_ACTION_BOXES_PCT := [
	Vector2(39.66, 56.81), Vector2(13.53, 49.32), Vector2(15.26, 33.19),
	Vector2(33.14, 24.13), Vector2(56.57, 24.23), Vector2(69.52, 24.61),
	Vector2(88.11, 33.48), Vector2(89.19, 43.62), Vector2(72.67, 58.25),
]

const DEFAULT_ANSWER_BOXES_PCT := [
	Vector2(30.36, 82.1), Vector2(9.51, 62.97), Vector2(6.89, 14.8),
	Vector2(27.86, 11.11), Vector2(51.05, 9.67), Vector2(72.18, 10.29),
	Vector2(91.76, 15.84), Vector2(90.66, 58.79), Vector2(73.1, 87.69),
]

# Chair center positions (calculated from .tscn offsets)
const DEFAULT_CHAIRS_PCT := [
	Vector2(31.27, 82.37), Vector2(4.72, 70.45), Vector2(5.47, 15.94),
	Vector2(24.28, 3.56), Vector2(49.78, 3.75), Vector2(75.75, 3.56),
	Vector2(94.79, 13.46), Vector2(93.91, 73.99), Vector2(75.2, 82.58),
]

# Chair size in pixels (default 185x185)
const DEFAULT_CHAIR_SIZE := Vector2(185.0, 185.0)

# Default chip preset configurations (using ChipUtils.ChipColor enum values)
static func get_default_player_stack_chips() -> Array:
	return [
		ChipUtils.ChipColor.PURPLE500, ChipUtils.ChipColor.PURPLE500, ChipUtils.ChipColor.PURPLE500,
		ChipUtils.ChipColor.PURPLE500, ChipUtils.ChipColor.PURPLE500, ChipUtils.ChipColor.PURPLE500,
		ChipUtils.ChipColor.PURPLE500, ChipUtils.ChipColor.PURPLE500, ChipUtils.ChipColor.PURPLE500,
		ChipUtils.ChipColor.PURPLE500,  # 10 purple
		ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100,
		ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100,
		ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100,
		ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100,
		ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100,
		ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100,
		ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100,  # 20 black
		ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25,
		ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25,
		ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25,
		ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25,
		ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25,
		ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25,
		ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25,  # 20 green
	]

static func get_default_bet_chips() -> Array:
	return [
		ChipUtils.ChipColor.PURPLE500,  # 1 purple
		ChipUtils.ChipColor.BLACK100, ChipUtils.ChipColor.BLACK100,  # 2 black
		ChipUtils.ChipColor.GREEN25,  # 1 green
	]

# 5/10 模式默认下注筹码预览
static func get_default_bet_chips_small() -> Array:
	return [
		ChipUtils.ChipColor.BLACK100,  # 1 black
		ChipUtils.ChipColor.GREEN25, ChipUtils.ChipColor.GREEN25,  # 2 green
		ChipUtils.ChipColor.RED5,  # 1 red
	]

# 5/10 模式默认玩家筹码预览（用于 ordered bet chips）
static func get_default_player_stack_chips_small() -> Array:
	var chips: Array = []
	for i in range(60):
		chips.append(ChipUtils.ChipColor.RED5)
	for i in range(20):
		chips.append(ChipUtils.ChipColor.GREEN25)
	for i in range(5):
		chips.append(ChipUtils.ChipColor.BLACK100)
	return chips

# 1/2 模式默认下注筹码预览
static func get_default_bet_chips_12() -> Array:
	return [
		ChipUtils.ChipColor.GREEN25,  # 1 green
		ChipUtils.ChipColor.RED5, ChipUtils.ChipColor.RED5,  # 2 red
		ChipUtils.ChipColor.WHITE1,  # 1 white
	]

# 1/2 模式默认玩家筹码预览（用于 ordered bet chips）
static func get_default_player_stack_chips_12() -> Array:
	var chips: Array = []
	for i in range(60):
		chips.append(ChipUtils.ChipColor.RED5)
	for i in range(20):
		chips.append(ChipUtils.ChipColor.WHITE1)
	for i in range(8):
		chips.append(ChipUtils.ChipColor.GREEN25)
	return chips

# --- Pre-computed pixel positions ---

static func get_default_card_positions() -> Array[Vector2]:
	var arr: Array[Vector2] = []
	for pct in DEFAULT_CARDS_PCT:
		arr.append(pct_to_px(pct))
	return arr

static func get_default_stack_positions() -> Array[Vector2]:
	var arr: Array[Vector2] = []
	for pct in DEFAULT_STACKS_PCT:
		arr.append(pct_to_px(pct))
	return arr

static func get_default_bet_positions() -> Array[Vector2]:
	var arr: Array[Vector2] = []
	for pct in DEFAULT_BETS_PCT:
		arr.append(pct_to_px(pct))
	return arr

static func get_default_dealer_button_positions() -> Array[Vector2]:
	var arr: Array[Vector2] = []
	for pct in DEFAULT_DEALER_BUTTONS_PCT:
		arr.append(pct_to_px(pct))
	return arr

static func get_default_pot_position() -> Vector2:
	return pct_to_px(DEFAULT_POT_PCT)

static func get_default_muck_position() -> Vector2:
	return pct_to_px(DEFAULT_MUCK_PCT)

static func get_default_community_cards_position() -> Vector2:
	return pct_to_px(DEFAULT_COMMUNITY_CARDS_PCT)

static func get_default_pitch_hand_position() -> Vector2:
	return pct_to_px(DEFAULT_PITCH_HAND_PCT)

static func get_default_seat_positions() -> Array[Vector2]:
	var arr: Array[Vector2] = []
	for pct in DEFAULT_SEATS_PCT:
		arr.append(pct_to_px(pct))
	return arr
