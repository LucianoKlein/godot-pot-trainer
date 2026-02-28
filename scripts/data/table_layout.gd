class_name TableLayout
extends RefCounted

# Background rect in the Godot scene: position (131, 130), size (1676, 943)
const BG_OFFSET := Vector2(131.0, 130.0)
const BG_SIZE := Vector2(1676.0, 943.0)

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
	Vector2(21.79, 11.17), Vector2(50.0, 2.0), Vector2(78.21, 11.17),
	Vector2(95.65, 35.17), Vector2(95.65, 64.83), Vector2(78.21, 88.83),
]

const DEFAULT_CARDS_PCT := [
	Vector2(28.84, 77.51), Vector2(15.76, 60.51), Vector2(15.76, 39.49),
	Vector2(30.15, 23.20), Vector2(50.15, 21.47), Vector2(71.16, 22.49),
	Vector2(84.24, 39.49), Vector2(84.24, 60.51), Vector2(71.16, 77.51),
]

const DEFAULT_STACKS_PCT := [
	Vector2(28.16, 75.60), Vector2(10.06, 62.36), Vector2(10.06, 37.64),
	Vector2(34.12, 21.07), Vector2(50.0, 10.0), Vector2(74.69, 17.64),
	Vector2(89.94, 37.64), Vector2(89.94, 62.36), Vector2(76.84, 75.60),
]

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

# Chair center positions (calculated from .tscn offsets)
const DEFAULT_CHAIRS_PCT := [
	Vector2(23.72, 87.88), Vector2(0.81, 73.54), Vector2(0.15, 5.99),
	Vector2(24.55, -9.92), Vector2(52.65, -9.49), Vector2(89.35, -8.11),
	Vector2(102.72, 12.89), Vector2(101.94, 68.87), Vector2(81.28, 87.99),
]

# Chair size in pixels (default 185x185)
const DEFAULT_CHAIR_SIZE := Vector2(185.0, 185.0)

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
