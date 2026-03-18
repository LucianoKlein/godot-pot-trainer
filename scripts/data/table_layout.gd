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
	Vector2(31.19, 82.74), Vector2(5.76, 68.98), Vector2(6.52, 18.17),
	Vector2(24.34, 5.14), Vector2(49.89, 4.37), Vector2(75.77, 5.92),
	Vector2(94.96, 15.46), Vector2(92.95, 73.43), Vector2(75.01, 81.0),
]

const DEFAULT_CARDS_PCT := [
	Vector2(28.84, 77.51), Vector2(15.76, 60.51), Vector2(15.76, 39.49),
	Vector2(30.15, 27.0), Vector2(50.15, 32.0), Vector2(71.16, 27.0),
	Vector2(84.24, 39.49), Vector2(84.24, 60.51), Vector2(71.16, 77.51),
]

const DEFAULT_STACKS_PCT := [
	Vector2(26.37, 67.48), Vector2(14.19, 62.75), Vector2(9.9, 28.75),
	Vector2(30.32, 17.27), Vector2(46.9, 17.2), Vector2(71.97, 17.27),
	Vector2(87.54, 24.5), Vector2(87.16, 61.97), Vector2(77.06, 67.39),
]

# Per-color chip stack positions (hardcoded from layout editor)
const DEFAULT_PURPLE_STACKS_PCT := [
	Vector2(24.47, 67.0), Vector2(10.06, 61.3), Vector2(8.05, 32.42),
	Vector2(29.72, 19.2), Vector2(55.54, 19.91), Vector2(77.62, 20.07),
	Vector2(88.3, 38.99), Vector2(87.0, 62.36), Vector2(74.94, 66.32),
]

const DEFAULT_BLACK_STACKS_PCT := [
	Vector2(27.2, 67.77), Vector2(12.36, 62.36), Vector2(9.92, 35.9),
	Vector2(32.24, 19.88), Vector2(57.73, 20.0), Vector2(79.92, 21.13),
	Vector2(90.33, 39.48), Vector2(89.3, 62.36), Vector2(77.46, 67.1),
]

const DEFAULT_GREEN_STACKS_PCT := [
	Vector2(29.77, 67.97), Vector2(14.66, 62.36), Vector2(12.43, 36.29),
	Vector2(34.75, 19.88), Vector2(60.14, 19.81), Vector2(82.44, 21.13),
	Vector2(92.63, 40.06), Vector2(91.6, 62.36), Vector2(79.92, 66.03),
]

# Legacy helper (kept for compatibility)
const STACK_COLOR_OFFSET_X := 2.3

static func _make_color_stack_defaults(offset_index: int) -> Array:
	match offset_index:
		0: return DEFAULT_PURPLE_STACKS_PCT.duplicate()
		1: return DEFAULT_BLACK_STACKS_PCT.duplicate()
		2: return DEFAULT_GREEN_STACKS_PCT.duplicate()
	var arr: Array = []
	for base in DEFAULT_STACKS_PCT:
		arr.append(Vector2(base.x + offset_index * STACK_COLOR_OFFSET_X, base.y))
	return arr

const DEFAULT_BETS_PCT := [
	Vector2(32.79, 53.23), Vector2(19.18, 48.74), Vector2(18.43, 33.88),
	Vector2(28.31, 28.29), Vector2(50.34, 28.18), Vector2(73.9, 28.85),
	Vector2(82.61, 36.76), Vector2(80.24, 50.87), Vector2(71.94, 53.3),
]

const DEFAULT_DEALER_BUTTONS_PCT := [
	Vector2(30.2, 53.97), Vector2(21.61, 52.47), Vector2(19.88, 31.41),
	Vector2(31.03, 29.11), Vector2(54.62, 28.9), Vector2(69.3, 29.3),
	Vector2(81.42, 33.02), Vector2(81.47, 47.12), Vector2(73.62, 50.52),
]

const DEFAULT_POT_PCT := Vector2(32.79, 41.8)
const DEFAULT_MUCK_PCT := Vector2(41.99, 59.87)
const DEFAULT_COMMUNITY_CARDS_PCT := Vector2(59.26, 60.40)
const DEFAULT_PITCH_HAND_PCT := Vector2(50.0, 97.0)
const DEFAULT_CHIP_RECORD_PCT := Vector2(55.0, 47.0)

# Ordered bet chips — offset slightly from bet positions
const DEFAULT_ORDERED_BET_CHIPS_PCT := [
	Vector2(32.01, 60.67), Vector2(22.09, 55.60), Vector2(22.97, 38.13),
	Vector2(39.81, 33.60), Vector2(55.54, 34.27), Vector2(65.93, 33.20),
	Vector2(76.0, 38.40), Vector2(76.51, 55.60), Vector2(70.71, 62.0),
]

const DEFAULT_HOLE_CARD_ROTATION := [
	0.0, 48.0, -46.0, 0.0, 0.0, 0.0, -114.0, -57.0, 0.0,
]

const DEFAULT_ACTION_BOXES_PCT := [
	Vector2(38.68, 82.12), Vector2(11.25, 76.57), Vector2(12.82, 11.16),
	Vector2(32.27, 6.74), Vector2(59.56, 4.42), Vector2(83.48, 4.71),
	Vector2(95.12, 28.94), Vector2(95.82, 62.75), Vector2(84.13, 81.15),
]

const DEFAULT_ANSWER_BOXES_PCT := [
	Vector2(30.36, 82.1), Vector2(9.51, 62.97), Vector2(9.57, 16.74),
	Vector2(33.41, 10.53), Vector2(55.96, 9.34), Vector2(80.12, 9.95),
	Vector2(90.49, 21.76), Vector2(92.17, 64.62), Vector2(75.94, 86.35),
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
