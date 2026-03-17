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
	Vector2(21.79, 88.83), Vector2(4.35, 64.83), Vector2(4.35, 35.17),
	Vector2(21.79, 15.0), Vector2(50.0, 15.0), Vector2(78.21, 15.0),
	Vector2(93.0, 35.17), Vector2(93.0, 64.83), Vector2(78.21, 88.83),
]

const DEFAULT_CARDS_PCT := [
	Vector2(28.84, 77.51), Vector2(15.76, 60.51), Vector2(15.76, 39.49),
	Vector2(30.15, 27.0), Vector2(50.15, 32.0), Vector2(71.16, 27.0),
	Vector2(84.24, 39.49), Vector2(84.24, 60.51), Vector2(71.16, 77.51),
]

const DEFAULT_STACKS_PCT := [
	Vector2(28.16, 75.60), Vector2(10.06, 62.36), Vector2(10.06, 37.64),
	Vector2(34.12, 25.0), Vector2(50.0, 23.0), Vector2(74.69, 22.0),
	Vector2(87.0, 37.64), Vector2(87.0, 62.36), Vector2(76.84, 75.60),
]

# Per-color chip stack positions (offset from stacks position)
# Purple stack (leftmost), Black stack (middle), Green stack (rightmost)
const STACK_COLOR_OFFSET_X := 2.3  # ~38px in percentage

static func _make_color_stack_defaults(offset_index: int) -> Array:
	var arr: Array = []
	for base in DEFAULT_STACKS_PCT:
		arr.append(Vector2(base.x + offset_index * STACK_COLOR_OFFSET_X, base.y))
	return arr

const DEFAULT_BETS_PCT := [
	Vector2(28.01, 60.67), Vector2(18.09, 55.60), Vector2(18.97, 38.13),
	Vector2(35.81, 33.60), Vector2(51.54, 34.27), Vector2(69.93, 33.20),
	Vector2(80.0, 38.40), Vector2(80.51, 55.60), Vector2(74.71, 62.0),
]

const DEFAULT_DEALER_BUTTONS_PCT := [
	Vector2(26.40, 61.60), Vector2(18.68, 57.20), Vector2(17.87, 40.40),
	Vector2(33.75, 33.07), Vector2(50.0, 32.67), Vector2(70.88, 33.07),
	Vector2(80.66, 40.27), Vector2(81.25, 56.40), Vector2(75.96, 62.40),
]

const DEFAULT_POT_PCT := Vector2(44.56, 47.20)
const DEFAULT_MUCK_PCT := Vector2(41.99, 59.87)
const DEFAULT_COMMUNITY_CARDS_PCT := Vector2(59.26, 60.40)
const DEFAULT_PITCH_HAND_PCT := Vector2(50.0, 97.0)
const DEFAULT_CHIP_RECORD_PCT := Vector2(55.0, 47.0)

const DEFAULT_HOLE_CARD_ROTATION := [
	0.0, 48.0, -46.0, 0.0, 0.0, 0.0, -114.0, -57.0, 0.0,
]

const DEFAULT_ACTION_BOXES_PCT := [
	Vector2(21.79, 78.83), Vector2(4.35, 54.83), Vector2(4.35, 25.17),
	Vector2(21.79, 5.0), Vector2(50.0, 5.0), Vector2(78.21, 5.0),
	Vector2(93.0, 25.17), Vector2(93.0, 54.83), Vector2(78.21, 78.83),
]

const DEFAULT_ANSWER_BOXES_PCT := [
	Vector2(28.84, 67.51), Vector2(15.76, 50.51), Vector2(15.76, 29.49),
	Vector2(30.15, 17.0), Vector2(50.15, 22.0), Vector2(71.16, 17.0),
	Vector2(84.24, 29.49), Vector2(84.24, 50.51), Vector2(71.16, 67.51),
]

# Chair center positions (calculated from .tscn offsets)
const DEFAULT_CHAIRS_PCT := [
	Vector2(23.72, 87.88), Vector2(0.81, 73.54), Vector2(0.15, 5.99),
	Vector2(24.55, 8.0), Vector2(50.0, 8.0), Vector2(82.0, 8.0),
	Vector2(88.0, 18.0), Vector2(95.0, 68.87), Vector2(81.28, 87.99),
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
