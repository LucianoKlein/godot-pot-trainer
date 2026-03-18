extends Node

# --- Enums ---
enum State { MENU, PLAYING, PAUSED }
enum Street { PREFLOP, FLOP, TURN, RIVER, SHOWDOWN }

const STREET_NAMES := {
	Street.PREFLOP: "preflop",
	Street.FLOP: "flop",
	Street.TURN: "turn",
	Street.RIVER: "river",
	Street.SHOWDOWN: "showdown",
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

var players: Array = []
var community_cards: Array = []
var deck: Array = []
var pot: int = 0
var current_player_index: int = -1
var dealer_index: int = 0
var street: Street = Street.PREFLOP
var small_blind: int = 25
var big_blind: int = 50
var is_hand_in_progress: bool = false
var last_action: String = ""

# Pot Trainer engine
var engine: RefCounted = PotEngine.new()
var config: RefCounted = TrainingConfig.new()
var is_game_running: bool = false
var is_game_started: bool = false
var board_cards: Array[String] = []  # display-only card strings

# Layout
var layout_mode: bool = false
var layout_config: Dictionary:
	get: return _layout_mgr.config
var _layout_mgr: RefCounted  # LayoutConfigManager
var pending_layout_mode: bool = false
var display_mode: String = "chips"  # "numbers" or "chips"

# Seat mapping: seat_map[logical_index] = physical_seat (0-8)
# e.g. seat_map = [0, 3, 5, 7] means 4 players at physical seats 0, 3, 5, 7
var seat_map: Array[int] = []


func _ready() -> void:
	_layout_mgr = LayoutConfigManager.new().setup(layout_changed.emit)


func change_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit()


# --- Deck (for board card display) ---

func _build_deck() -> Array:
	var d: Array = []
	for s in [CardData.Suit.HEARTS, CardData.Suit.DIAMONDS, CardData.Suit.CLUBS, CardData.Suit.SPADES]:
		for r in range(CardData.Rank.TWO, CardData.Rank.ACE + 1):
			d.append(CardData.new(s, r))
	return d


func _shuffle_deck(d: Array) -> Array:
	var shuffled := d.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := randi_range(0, i)
		var tmp: RefCounted = shuffled[i]
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
		var c: RefCounted = deck.pop_back()
		c.face_up = true
		community_cards.append(c)

	community_cards_changed.emit()


# --- Game Init & Control ---

func init_game() -> void:
	players.clear()
	_generate_seat_map()
	for i in range(config.player_count):
		var physical_seat: int = seat_map[i]
		players.append(PlayerData.new(physical_seat + 1, Locale.tr_key("player_n") % (physical_seat + 1)))
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


func _restart_paused() -> void:
	# Config changed mid-game: reset, deal a new hand, but pause — wait for user to press Start
	is_game_running = false
	layout_mode = false
	init_game()
	engine = PotEngine.new()
	engine.create_initial_state(config)
	_sync_from_engine()
	deck = _shuffle_deck(_build_deck())
	_deal_hole_cards()
	is_hand_in_progress = false
	is_game_started = false
	game_reset.emit()
	hand_started.emit()
	hole_cards_changed.emit()


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
			var c: RefCounted = deck.pop_back()
			c.face_up = false
			players[i].hole_cards.append(c)


func _sync_from_engine() -> void:
	# Sync engine state to GameManager display state
	for i in range(engine.players.size()):
		if i < players.size():
			var ep = engine.players[i]
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

	var result: Dictionary = engine.advance_one_step(config)
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
	var q: Dictionary = engine.training_question
	if q["is_answer"]:
		# Skip question if max raise exceeds 7500 or player is all-in
		if q["max_raise_to"] > PotEngine.INITIAL_STACK or q["is_all_in"]:
			var amount: int = q["all_in_amount"] if q["is_all_in"] else q["max_raise_to"]
			last_action = Locale.tr_key("seat_raise_to") % [get_physical_seat(q["seat"]) + 1, amount]
			last_action_changed.emit(last_action)
			npc_acted.emit(q["seat"], "raise", amount)
			engine.complete_raise(amount)
			_sync_from_engine()
			get_tree().create_timer(0.3).timeout.connect(_run_game_loop)
			return
		last_action = Locale.tr_key("seat_raise_question") % (get_physical_seat(q["seat"]) + 1)
		last_action_changed.emit(last_action)
		training_question_appeared.emit(q)
	else:
		# Non-answer question: auto-complete after brief delay
		last_action = Locale.tr_key("seat_raise_to") % [get_physical_seat(q["seat"]) + 1, q["raise_amount"]]
		last_action_changed.emit(last_action)
		npc_acted.emit(q["seat"], "raise", q["raise_amount"])
		engine.complete_raise(q["raise_amount"])
		_sync_from_engine()
		get_tree().create_timer(0.3).timeout.connect(_run_game_loop)


func _handle_game_over() -> void:
	is_hand_in_progress = false
	last_action = Locale.tr_key("hand_over")
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
	if is_game_started:
		_restart_paused()


func set_player_count(count: int) -> void:
	var was_started: bool = is_game_started
	config.player_count = clampi(count, 2, 9)
	if was_started:
		_restart_paused()
	else:
		reset_game()
		init_game()


func set_table_preset(preset: int) -> void:
	config.table_preset = preset
	if is_game_started:
		_restart_paused()


func set_question_probability(prob: int) -> void:
	config.question_probability = clampi(prob, 0, 100)


func set_training_mode(mode: String) -> void:
	config.training_mode = mode
	if is_game_started:
		_restart_paused()


func set_display_mode(mode: String) -> void:
	display_mode = mode
	_layout_mgr.config["display_mode"] = mode
	display_mode_changed.emit(mode)


func move_dealer_button() -> void:
	dealer_index = (dealer_index + 1) % players.size()
	config.dealer_seat = dealer_index
	dealer_moved.emit(dealer_index)


func set_dealer_index(index: int) -> void:
	dealer_index = clampi(index, 0, players.size() - 1)
	config.dealer_seat = dealer_index
	dealer_moved.emit(dealer_index)
	if is_game_started:
		_restart_paused()


func next_active_index(from_index: int) -> int:
	var idx: int = (from_index + 1) % players.size()
	var count: int = 0
	while players[idx].folded and count < players.size():
		idx = (idx + 1) % players.size()
		count += 1
	return idx


# --- Computed helpers ---

func get_active_players() -> Array:
	var result: Array = []
	for p in players:
		if not p.folded:
			result.append(p)
	return result


func get_current_player() -> RefCounted:
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


# --- Layout (delegated to LayoutConfigManager) ---

func toggle_layout_mode() -> void:
	layout_mode = not layout_mode
	layout_changed.emit()

func update_layout_position(category: String, index: int, x: float, y: float) -> void:
	_layout_mgr.update_position(category, index, x, y)

func export_layout() -> String:
	return _layout_mgr.export_layout()

func import_layout(json_str: String) -> void:
	_layout_mgr.import_layout(json_str)

func reset_layout() -> void:
	_layout_mgr.reset_layout()

func save_layout_to_file() -> bool:
	return _layout_mgr.save_to_file()

func load_layout_from_file() -> bool:
	var loaded: bool = _layout_mgr.load_from_file()
	var saved_mode: String = _layout_mgr.config.get("display_mode", "chips")
	display_mode = saved_mode
	return loaded

func get_layout_position_px(category: String, index: int = -1) -> Vector2:
	return _layout_mgr.get_position_px(category, index)

func set_dealer_button_scale(scale: float) -> void:
	_layout_mgr.set_scale("dealer_button_scale", scale)

func set_hole_card_scale(scale: float) -> void:
	_layout_mgr.set_scale("hole_card_scale", scale)

func set_hole_card_gap(gap: float) -> void:
	_layout_mgr.set_scale("hole_card_gap", gap)

func set_community_card_scale(scale: float) -> void:
	_layout_mgr.set_scale("community_card_scale", scale)

func set_muck_card_scale(scale: float) -> void:
	_layout_mgr.set_scale("muck_card_scale", scale)

func set_bet_label_scale(scale: float) -> void:
	_layout_mgr.set_scale("bet_label_scale", scale)

func set_stack_label_scale(scale: float) -> void:
	_layout_mgr.set_scale("stack_label_scale", scale)

func set_pitch_hand_scale(scale: float) -> void:
	_layout_mgr.set_scale("pitch_hand_scale", scale)

func set_pitch_hand_rotation(deg: float) -> void:
	_layout_mgr.set_scale("pitch_hand_rotation", deg)

func set_action_box_scale(scale: float) -> void:
	_layout_mgr.set_scale("action_box_scale", scale)

func set_answer_box_scale(scale: float) -> void:
	_layout_mgr.set_scale("answer_box_scale", scale)

func set_player_chip_scale(scale: float) -> void:
	_layout_mgr.set_scale("player_chip_scale", scale)

func set_bet_chip_scale(scale: float) -> void:
	_layout_mgr.set_scale("bet_chip_scale", scale)

func set_bet_chip_spread(spread: float) -> void:
	_layout_mgr.set_scale("bet_chip_spread", spread)

func set_pot_chip_scale(scale: float) -> void:
	_layout_mgr.set_scale("pot_chip_scale", scale)

func set_chip_record_scale(scale: float) -> void:
	_layout_mgr.set_scale("chip_record_scale", scale)

func set_ordered_bet_chip_scale(scale: float) -> void:
	_layout_mgr.set_scale("ordered_bet_chip_scale", scale)
