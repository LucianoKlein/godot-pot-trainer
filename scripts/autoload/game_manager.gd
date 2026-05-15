extends Node

const GameLoopControllerScript := preload("res://scripts/core/game_loop_controller.gd")
const DeckManagerScript := preload("res://scripts/core/deck_manager.gd")

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
	[1, 2], [1, 5], [5, 10], [25, 50],
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
signal language_changed()

# --- State ---
var current_state: State = State.MENU

# Language
var language: String = "zh":
	set(v):
		language = v
		language_changed.emit()

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
var blinds_mode: String = "25/50"  # "25/50" / "5/10" / "1/2" / "1/2/5"
var is_guest_mode: bool = false  # true if playing as guest
var open_subscription_on_menu: bool = false  # open subscription panel on return to menu
var _loop: GameLoopController  # game loop controller
var _deck_mgr: DeckManager  # deck manager

# Seat mapping: seat_map[logical_index] = physical_seat (0-8)
# e.g. seat_map = [0, 3, 5, 7] means 4 players at physical seats 0, 3, 5, 7
var seat_map: Array[int] = []


func _ready() -> void:
	_layout_mgr = LayoutConfigManager.new().setup(layout_changed.emit)
	_loop = GameLoopControllerScript.new().setup(self)
	_deck_mgr = DeckManagerScript.new()


func change_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit()


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
	is_game_running = false
	layout_mode = false
	init_game()
	engine = PotEngine.new()
	engine.create_initial_state(config)
	_sync_from_engine()
	_deck_mgr.reset()
	_deck_mgr.build_and_shuffle()
	deck = _deck_mgr.deck
	_deck_mgr.deal_hole_cards(players)
	is_hand_in_progress = false
	is_game_started = false
	game_reset.emit()
	hand_started.emit()
	hole_cards_changed.emit()


func _start_new_hand() -> void:
	engine = PotEngine.new()
	engine.create_initial_state(config)
	_sync_from_engine()
	_deck_mgr.reset()
	_deck_mgr.build_and_shuffle()
	deck = _deck_mgr.deck
	community_cards = _deck_mgr.community_cards
	_deck_mgr.deal_hole_cards(players)
	is_hand_in_progress = true
	hand_started.emit()
	hole_cards_changed.emit()
	_loop.run_game_loop()


func _generate_board_cards() -> void:
	_deck_mgr.generate_board_cards(engine.street)
	community_cards = _deck_mgr.community_cards
	community_cards_changed.emit()


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


# --- Answer Submission ---

func submit_answer(user_input: int) -> bool:
	return _loop.submit_answer(user_input)


# --- Config ---

func set_blinds(sb: int, bb: int) -> void:
	small_blind = sb
	big_blind = bb
	config.set_blinds(sb, bb)
	blinds_mode = config.blinds_mode
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
	return loaded

func get_layout_position_px(category: String, index: int = -1) -> Vector2:
	return _layout_mgr.get_position_px(category, index)

func set_layout_scale(key: String, value: float) -> void:
	_layout_mgr.set_scale(key, value)

func switch_layout_mode(mode: String) -> void:
	_layout_mgr.switch_mode(mode)


func set_per_seat_value(key: String, seat: int, value: float) -> void:
	var arr: Array = layout_config.get(key, [])
	if seat >= 0 and seat < arr.size():
		arr[seat] = value
		layout_config[key] = arr
		layout_changed.emit()


# --- Guest mode ad counter ---

func increment_guest_answer_count() -> void:
	GuestModeManager.increment_guest_question()


func reset_guest_answer_count() -> void:
	pass  # GuestModeManager handles its own state
