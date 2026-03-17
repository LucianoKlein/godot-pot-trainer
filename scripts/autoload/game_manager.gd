extends Node

# --- Enums ---
enum State { MENU, PLAYING, PAUSED }
enum Street { PREFLOP, FLOP, TURN, RIVER, SHOWDOWN }

const STREET_NAMES := {
	Street.PREFLOP: "翻牌前",
	Street.FLOP: "翻牌",
	Street.TURN: "转牌",
	Street.RIVER: "河牌",
	Street.SHOWDOWN: "摊牌",
}

const POT_BLINDS := [
	[25, 50], [50, 100], [100, 200], [200, 400], [500, 1000],
]

# --- Signals ---
signal state_changed()
signal street_changed(new_street: String)
signal pot_changed(new_pot: int)
signal community_cards_changed()
signal dealer_moved(index: int)
signal current_player_changed(index: int)
signal layout_changed()
signal game_reset()
signal last_action_changed(text: String)
signal blinds_changed()
signal npc_acted(seat: int, action: String, amount: int)
signal training_question_appeared(question: Dictionary)
signal training_question_cleared()
signal answer_result(correct: bool, user_answer: int, expected: int)
signal game_over()
signal hand_started()
signal display_mode_changed(mode: String)
signal hole_cards_changed()

# --- State ---
var current_state: State = State.MENU

var players: Array[PlayerData] = []
var community_cards: Array[CardData] = []
var deck: Array[CardData] = []
var pot: int = 0
var current_player_index: int = -1
var dealer_index: int = 0
var street: Street = Street.PREFLOP
var small_blind: int = 25
var big_blind: int = 50
var is_hand_in_progress: bool = false
var last_action: String = ""

# Pot Trainer engine
var engine: PotEngine = PotEngine.new()
var config: TrainingConfig = TrainingConfig.new()
var is_game_running: bool = false
var is_game_started: bool = false
var board_cards: Array[String] = []  # display-only card strings

# Layout
var layout_mode: bool = false
var layout_config: Dictionary = {}
var pending_layout_mode: bool = false
var display_mode: String = "chips"  # "numbers" or "chips"

# Seat mapping: seat_map[logical_index] = physical_seat (0-8)
# e.g. seat_map = [0, 3, 5, 7] means 4 players at physical seats 0, 3, 5, 7
var seat_map: Array[int] = []


func _ready() -> void:
	_reset_layout_config()


func change_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit()


# --- Deck (for board card display) ---

func _build_deck() -> Array[CardData]:
	var d: Array[CardData] = []
	for s in [CardData.Suit.HEARTS, CardData.Suit.DIAMONDS, CardData.Suit.CLUBS, CardData.Suit.SPADES]:
		for r in range(CardData.Rank.TWO, CardData.Rank.ACE + 1):
			d.append(CardData.new(s, r))
	return d


func _shuffle_deck(d: Array[CardData]) -> Array[CardData]:
	var shuffled := d.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := randi_range(0, i)
		var tmp: CardData = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	return shuffled


func _generate_board_cards() -> void:
	var card_count := 0
	match engine.street:
		"preflop": card_count = 0
		"flop": card_count = 3
		"turn": card_count = 4
		"river": card_count = 5

	board_cards.clear()
	if card_count == 0:
		community_cards.clear()
		community_cards_changed.emit()
		return

	# Single board — deal from shared deck
	while community_cards.size() < card_count:
		if deck.is_empty():
			break
		var c: CardData = deck.pop_back()
		c.face_up = true
		community_cards.append(c)

	community_cards_changed.emit()


# --- Game Init & Control ---

func init_game() -> void:
	players.clear()
	_generate_seat_map()
	for i in range(config.player_count):
		var physical_seat: int = seat_map[i]
		players.append(PlayerData.new(physical_seat + 1, "玩家 %d" % (physical_seat + 1)))
	community_cards.clear()
	pot = 0
	current_player_index = -1
	street = Street.PREFLOP
	is_hand_in_progress = false
	is_game_running = false
	is_game_started = false
	last_action = ""
	board_cards.clear()


func start_game() -> void:
	if is_game_running:
		return
	is_game_running = true
	is_game_started = true
	_start_new_hand()


func pause_game() -> void:
	is_game_running = false


func reset_game() -> void:
	layout_mode = false
	init_game()
	engine = PotEngine.new()
	game_reset.emit()


func _start_new_hand() -> void:
	engine = PotEngine.new()
	engine.create_initial_state(config)
	_sync_from_engine()
	# Build and shuffle a shared deck for the entire hand
	deck = _shuffle_deck(_build_deck())
	# Deal hole cards (2 per player)
	_deal_hole_cards()
	is_hand_in_progress = true
	hand_started.emit()
	hole_cards_changed.emit()
	_run_game_loop()


func _deal_hole_cards() -> void:
	for i in range(players.size()):
		players[i].hole_cards.clear()
		for _j in range(2):
			if deck.is_empty():
				break
			var c: CardData = deck.pop_back()
			c.face_up = false
			players[i].hole_cards.append(c)


func _sync_from_engine() -> void:
	# Sync engine state to GameManager display state
	for i in range(engine.players.size()):
		if i < players.size():
			var ep: PotEngine.PotPlayerState = engine.players[i]
			players[i].chips = ep.stack
			players[i].round_contribution = ep.round_contribution
			players[i].status = ep.status
			players[i].last_action = ep.last_action
			players[i].folded = (ep.status == "folded")
			players[i].has_acted = ep.has_acted_this_round
			if ep.template:
				players[i].template = ep.template

	pot = engine.pot_total
	current_player_index = engine.current_seat

	# Map engine street string to enum
	match engine.street:
		"preflop": street = Street.PREFLOP
		"flop": street = Street.FLOP
		"turn": street = Street.TURN
		"river": street = Street.RIVER

	pot_changed.emit(pot)
	current_player_changed.emit(current_player_index)
	street_changed.emit(engine.street)


# --- Game Loop ---

func _run_game_loop() -> void:
	if config.training_mode == "game":
		_run_step_by_step()
	else:
		_run_until_question()


func _run_step_by_step() -> void:
	if not is_game_running:
		return

	var result := engine.advance_one_step(config)
	_sync_from_engine()
	_generate_board_cards()

	if result["is_game_over"]:
		_handle_game_over()
		return

	if result["has_question"]:
		_handle_training_question()
		return

	# Emit npc_acted signal for UI to show the action
	if result["seat"] >= 0:
		npc_acted.emit(result["seat"], result["action"], result["amount"])

	# Wait 1 second then execute next step
	get_tree().create_timer(1.0).timeout.connect(_run_step_by_step)


func _run_until_question() -> void:
	if not is_game_running:
		return

	engine.run_until_question(config)
	_sync_from_engine()
	_generate_board_cards()

	if engine.is_game_over:
		_handle_game_over()
		return

	if not engine.training_question.is_empty():
		_handle_training_question()


func _handle_training_question() -> void:
	if engine.training_question["is_answer"]:
		last_action = "座位 %d 加注 — 底池限注最大是多少？" % (get_physical_seat(engine.training_question["seat"]) + 1)
		last_action_changed.emit(last_action)
		training_question_appeared.emit(engine.training_question)
	else:
		# Non-answer question: auto-complete after brief delay
		last_action = "座位 %d 加注到 %d" % [get_physical_seat(engine.training_question["seat"]) + 1, engine.training_question["raise_amount"]]
		last_action_changed.emit(last_action)
		engine.complete_raise(engine.training_question["raise_amount"])
		_sync_from_engine()
		get_tree().create_timer(0.3).timeout.connect(_run_game_loop)


func _handle_game_over() -> void:
	is_hand_in_progress = false
	last_action = "本手结束。"
	last_action_changed.emit(last_action)
	game_over.emit()

	if config.training_mode == "scenario" and is_game_running:
		# Auto-restart in scenario mode
		get_tree().create_timer(2.0).timeout.connect(_start_new_hand)
	else:
		is_game_running = false
		is_game_started = false


# --- Answer Submission ---

func submit_answer(user_input: int) -> bool:
	if engine.training_question.is_empty():
		return false
	if not engine.training_question["is_answer"]:
		return false

	var expected: int = engine.training_question["max_raise_to"]

	if user_input == expected:
		# Correct
		answer_result.emit(true, user_input, expected)
		engine.complete_raise(expected)
		_sync_from_engine()
		training_question_cleared.emit()
		# Continue game loop after brief pause
		get_tree().create_timer(0.5).timeout.connect(_run_game_loop)
		return true
	else:
		# Wrong
		answer_result.emit(false, user_input, expected)
		return false


# --- Config ---

func set_blinds(sb: int, bb: int) -> void:
	small_blind = sb
	big_blind = bb
	config.small_blind = sb
	config.big_blind = bb
	blinds_changed.emit()


func set_player_count(count: int) -> void:
	config.player_count = clampi(count, 2, 9)
	reset_game()
	init_game()


func set_table_preset(preset: int) -> void:
	config.table_preset = preset
	if is_game_started:
		reset_game()
		init_game()


func set_question_probability(prob: int) -> void:
	config.question_probability = clampi(prob, 0, 100)


func set_training_mode(mode: String) -> void:
	config.training_mode = mode


func set_display_mode(mode: String) -> void:
	display_mode = mode
	layout_config["display_mode"] = mode
	display_mode_changed.emit(mode)


func move_dealer_button() -> void:
	dealer_index = (dealer_index + 1) % players.size()
	config.dealer_seat = dealer_index
	dealer_moved.emit(dealer_index)


func set_dealer_index(index: int) -> void:
	dealer_index = clampi(index, 0, players.size() - 1)
	config.dealer_seat = dealer_index
	dealer_moved.emit(dealer_index)


func next_active_index(from_index: int) -> int:
	var idx := (from_index + 1) % players.size()
	var count := 0
	while players[idx].folded and count < players.size():
		idx = (idx + 1) % players.size()
		count += 1
	return idx


# --- Computed helpers ---

func get_active_players() -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for p in players:
		if not p.folded:
			result.append(p)
	return result


func get_current_player() -> PlayerData:
	if current_player_index >= 0 and current_player_index < players.size():
		return players[current_player_index]
	return null


func get_physical_seat(logical_index: int) -> int:
	if logical_index >= 0 and logical_index < seat_map.size():
		return seat_map[logical_index]
	return logical_index


func _generate_seat_map() -> void:
	# Randomly pick which physical seats (0-8) are occupied
	var all_seats: Array[int] = []
	for i in range(9):
		all_seats.append(i)
	# Shuffle
	for i in range(all_seats.size() - 1, 0, -1):
		var j := randi_range(0, i)
		var tmp: int = all_seats[i]
		all_seats[i] = all_seats[j]
		all_seats[j] = tmp
	# Take first N, then sort so seating order is clockwise
	seat_map.clear()
	for i in range(config.player_count):
		seat_map.append(all_seats[i])
	seat_map.sort()


func get_training_question() -> Dictionary:
	return engine.training_question


# --- Layout ---

func _reset_layout_config() -> void:
	layout_config = {
		"seats": TableLayout.DEFAULT_SEATS_PCT.duplicate(),
		"chairs": TableLayout.DEFAULT_CHAIRS_PCT.duplicate(),
		"cards": TableLayout.DEFAULT_CARDS_PCT.duplicate(),
		"stacks": TableLayout.DEFAULT_STACKS_PCT.duplicate(),
		"bets": TableLayout.DEFAULT_BETS_PCT.duplicate(),
		"dealer_buttons": TableLayout.DEFAULT_DEALER_BUTTONS_PCT.duplicate(),
		"pot": TableLayout.DEFAULT_POT_PCT,
		"muck": TableLayout.DEFAULT_MUCK_PCT,
		"community_cards": TableLayout.DEFAULT_COMMUNITY_CARDS_PCT,
		"avatar_scale": 2.4,
		"avatar_per_seat_scale": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
		"avatar_rotation": [180.0, 0.0, -37.0, 0.0, 0.0, -125.0, 76.0, 120.0, 126.0],
		"chair_scale": 0.95,
		"chair_rotation": [177.0, -133.0, -39.0, 0.0, 0.0, 0.0, 23.0, 136.0, 177.0],
		"dealer_button_scale": 1.0,
		"hole_card_scale": 0.55,
		"hole_card_gap": 0.6,
		"community_card_scale": 1.0,
		"muck_card_scale": 1.0,
		"bet_label_scale": 1.0,
		"stack_label_scale": 1.0,
		"pitch_hand": TableLayout.DEFAULT_PITCH_HAND_PCT,
		"pitch_hand_scale": 1.0,
		"pitch_hand_rotation": 0.0,
		"hole_card_rotation": TableLayout.DEFAULT_HOLE_CARD_ROTATION.duplicate(),
		"action_boxes": TableLayout.DEFAULT_ACTION_BOXES_PCT.duplicate(),
		"action_box_scale": 1.0,
		"answer_boxes": TableLayout.DEFAULT_ANSWER_BOXES_PCT.duplicate(),
		"answer_box_scale": 1.0,
		"player_chip_scale": 1.0,
		"bet_chip_scale": 1.0,
		"bet_chip_spread": 1.0,
		"pot_chip_scale": 1.0,
		"chip_record": TableLayout.DEFAULT_CHIP_RECORD_PCT,
		"chip_record_scale": 1.0,
		"purple_stacks": TableLayout._make_color_stack_defaults(0),
		"black_stacks": TableLayout._make_color_stack_defaults(1),
		"green_stacks": TableLayout._make_color_stack_defaults(2),
		"display_mode": "chips",
	}


func toggle_layout_mode() -> void:
	layout_mode = not layout_mode
	layout_changed.emit()


func update_layout_position(category: String, index: int, x: float, y: float) -> void:
	if index >= 0:
		var arr: Array = layout_config[category]
		if arr and index < arr.size():
			arr[index] = Vector2(x, y)
	else:
		layout_config[category] = Vector2(x, y)
	layout_changed.emit()


func export_layout() -> String:
	var out := {}
	for key in layout_config:
		var val = layout_config[key]
		if val is Array:
			var arr := []
			for v in val:
				if v is Vector2:
					arr.append({"x": snapped(v.x, 0.01), "y": snapped(v.y, 0.01)})
				else:
					arr.append(v)
			out[key] = arr
		elif val is Vector2:
			out[key] = {"x": snapped(val.x, 0.01), "y": snapped(val.y, 0.01)}
		else:
			out[key] = val
	return JSON.stringify(out, "\t")


func import_layout(json_str: String) -> void:
	var parsed = JSON.parse_string(json_str)
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	for key in d:
		var val = d[key]
		if val is Array:
			var arr: Array = []
			for item in val:
				if item is Dictionary and item.has("x") and item.has("y"):
					arr.append(Vector2(item["x"], item["y"]))
				else:
					arr.append(item)
			layout_config[key] = arr
		elif val is Dictionary and val.has("x") and val.has("y"):
			layout_config[key] = Vector2(val["x"], val["y"])
		else:
			# Backward compat: convert old single-float rotation to per-seat array
			if key in ["hole_card_rotation", "avatar_rotation", "chair_rotation"] and (val is float or val is int):
				var arr: Array = []
				for _i in range(9):
					arr.append(val)
				layout_config[key] = arr
			else:
				layout_config[key] = val
	layout_changed.emit()


func reset_layout() -> void:
	_reset_layout_config()
	# Load built-in default on top of hardcoded fallback
	_load_default_layout()
	# Remove user custom layout file
	if FileAccess.file_exists(USER_LAYOUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_LAYOUT_PATH))
	layout_changed.emit()


func set_dealer_button_scale(scale: float) -> void:
	layout_config["dealer_button_scale"] = scale
	layout_changed.emit()


func set_hole_card_scale(scale: float) -> void:
	layout_config["hole_card_scale"] = scale
	layout_changed.emit()


func set_hole_card_gap(gap: float) -> void:
	layout_config["hole_card_gap"] = gap
	layout_changed.emit()


func set_community_card_scale(scale: float) -> void:
	layout_config["community_card_scale"] = scale
	layout_changed.emit()


func set_muck_card_scale(scale: float) -> void:
	layout_config["muck_card_scale"] = scale
	layout_changed.emit()


func set_bet_label_scale(scale: float) -> void:
	layout_config["bet_label_scale"] = scale
	layout_changed.emit()


func set_stack_label_scale(scale: float) -> void:
	layout_config["stack_label_scale"] = scale
	layout_changed.emit()


func set_pitch_hand_scale(scale: float) -> void:
	layout_config["pitch_hand_scale"] = scale
	layout_changed.emit()


func set_pitch_hand_rotation(deg: float) -> void:
	layout_config["pitch_hand_rotation"] = deg
	layout_changed.emit()


func set_action_box_scale(scale: float) -> void:
	layout_config["action_box_scale"] = scale
	layout_changed.emit()


func set_answer_box_scale(scale: float) -> void:
	layout_config["answer_box_scale"] = scale
	layout_changed.emit()


func set_player_chip_scale(scale: float) -> void:
	layout_config["player_chip_scale"] = scale
	layout_changed.emit()


func set_bet_chip_scale(scale: float) -> void:
	layout_config["bet_chip_scale"] = scale
	layout_changed.emit()


func set_bet_chip_spread(spread: float) -> void:
	layout_config["bet_chip_spread"] = spread
	layout_changed.emit()


func set_pot_chip_scale(scale: float) -> void:
	layout_config["pot_chip_scale"] = scale
	layout_changed.emit()


func set_chip_record_scale(scale: float) -> void:
	layout_config["chip_record_scale"] = scale
	layout_changed.emit()


const DEFAULT_LAYOUT_PATH := "res://data/default_layout.json"
const USER_LAYOUT_PATH := "user://layout.json"


func save_layout_to_file() -> bool:
	var json := export_layout()
	var file := FileAccess.open(USER_LAYOUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		return true
	return false


func load_layout_from_file() -> bool:
	# Priority: user file > built-in default
	var loaded := false
	if FileAccess.file_exists(USER_LAYOUT_PATH):
		var file := FileAccess.open(USER_LAYOUT_PATH, FileAccess.READ)
		if file:
			var json := file.get_as_text()
			file.close()
			import_layout(json)
			loaded = true
	if not loaded:
		loaded = _load_default_layout()
	# Apply persisted display_mode
	var saved_mode: String = layout_config.get("display_mode", "chips")
	display_mode = saved_mode
	return loaded


func _load_default_layout() -> bool:
	if not FileAccess.file_exists(DEFAULT_LAYOUT_PATH):
		return false
	var file := FileAccess.open(DEFAULT_LAYOUT_PATH, FileAccess.READ)
	if file:
		var json := file.get_as_text()
		file.close()
		import_layout(json)
		return true
	return false


func get_layout_position_px(category: String, index: int = -1) -> Vector2:
	var pct: Vector2
	if index >= 0:
		var arr: Array = layout_config[category]
		pct = arr[index]
	else:
		pct = layout_config[category]
	return TableLayout.pct_to_px(pct)
