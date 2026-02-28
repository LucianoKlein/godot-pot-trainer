extends Node

# --- Enums ---
enum State { MENU, PLAYING, PAUSED }
enum Street { PITCH, PREFLOP, FLOP, TURN, RIVER, SHOWDOWN }
enum GameMode { CASH, TOURNAMENT }

const STREET_NAMES := {
	Street.PITCH: "Pitch",
	Street.PREFLOP: "Pre-Flop",
	Street.FLOP: "Flop",
	Street.TURN: "Turn",
	Street.RIVER: "River",
	Street.SHOWDOWN: "Showdown",
}

const CASH_BLINDS := [
	[1, 2], [1, 3], [2, 3], [2, 5], [3, 5], [5, 5],
	[5, 10], [10, 20], [10, 25], [20, 40], [25, 50], [50, 100], [100, 100],
]

const TOURNAMENT_BLINDS := [
	[100, 100], [100, 200], [200, 300], [200, 400], [300, 600], [400, 800],
	[500, 1000], [600, 1200], [800, 1600], [1000, 1500], [1000, 2000], [1500, 3000],
]

# --- Signals ---
signal hand_started()
signal hand_ended(winner_name: String, pot_amount: int)
signal street_changed(new_street: Street)
signal player_acted(player_id: int, action: String, amount: int)
signal pot_changed(new_pot: int)
signal community_cards_changed()
signal pitch_state_changed()
signal pitch_card_animated(player_index: int, face_up: bool, card: CardData)
signal context_menu_requested(player_id: int)
signal raise_dialog_requested(player_id: int)
signal misdeal_detected(reason: String)
signal dealer_moved(index: int)
signal current_player_changed(index: int)
signal layout_changed()
signal game_reset()
signal muck_changed()
signal last_action_changed(text: String)
signal misdeal_x_changed(visible: bool)
signal mispitch_animated(target_pct: Vector2, card: CardData)
signal blinds_changed()

# --- State ---
var current_state: State = State.MENU

var players: Array[PlayerData] = []
var community_cards: Array[CardData] = []
var deck: Array[CardData] = []
var muck_pile: Array[CardData] = []
var pot: int = 0
var current_bet: int = 0
var last_raise_increment: int = 0
var current_player_index: int = -1
var dealer_index: int = 0
var street: Street = Street.PREFLOP
var small_blind: int = 1
var big_blind: int = 2
var game_mode: GameMode = GameMode.CASH
var is_hand_in_progress: bool = false
var last_action: String = ""

# UI state
var context_menu_player_id: int = -1  # -1 = none
var show_raise_dialog: bool = false
var raise_dialog_player_id: int = -1

# Out-of-turn state
var out_of_turn_mode: bool = false
var has_out_of_turn_action: bool = false

# Indicators
var show_action: bool = false
var show_aggressor: bool = false
var aggressor_player_id: int = -1  # -1 = none

# Pitch state
var pitch_state: PitchState = PitchState.new()
var show_misdeal_x: bool = false
var show_misdeal_menu: bool = false

# Undo
var _action_history: Array[Dictionary] = []

# Layout
var layout_mode: bool = false
var layout_config: Dictionary = {}


func _ready() -> void:
	_reset_layout_config()


func change_state(new_state: State) -> void:
	current_state = new_state


# --- Deck ---

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


# --- Game Init ---

func init_game() -> void:
	players.clear()
	for i in range(9):
		players.append(PlayerData.new(i + 1, "Player %d" % (i + 1)))
	community_cards.clear()
	muck_pile.clear()
	pot = 0
	current_bet = 0
	current_player_index = -1
	street = Street.PREFLOP
	is_hand_in_progress = false
	last_action = ""
	context_menu_player_id = -1
	show_raise_dialog = false
	has_out_of_turn_action = false
	aggressor_player_id = -1
	show_misdeal_x = false
	show_misdeal_menu = false
	_action_history.clear()


func start_hand() -> void:
	for p in players:
		p.hole_cards.clear()
		p.current_bet = 0
		p.folded = false
		p.has_acted = false

	community_cards.clear()
	muck_pile.clear()
	pot = 0
	current_bet = 0
	context_menu_player_id = -1
	show_raise_dialog = false
	has_out_of_turn_action = false
	_action_history.clear()
	aggressor_player_id = -1

	deck = _shuffle_deck(_build_deck())

	# Post blinds
	var sb_index := next_active_index(dealer_index)
	var bb_index := next_active_index(sb_index)

	var sb_player := players[sb_index]
	var sb_amount := mini(small_blind, sb_player.chips)
	sb_player.chips -= sb_amount
	sb_player.current_bet = sb_amount

	var bb_player := players[bb_index]
	var bb_amount := mini(big_blind, bb_player.chips)
	bb_player.chips -= bb_amount
	bb_player.current_bet = bb_amount

	current_bet = bb_amount
	last_raise_increment = bb_amount
	aggressor_player_id = bb_player.id

	# Enter pitch phase
	street = Street.PITCH
	is_hand_in_progress = true
	current_player_index = -1

	var first_receiver := next_active_index(dealer_index)
	pitch_state.reset(first_receiver)

	show_misdeal_x = false
	show_misdeal_menu = false
	last_action = "Blinds posted. Pitch cards to players."

	hand_started.emit()
	street_changed.emit(street)
	pitch_state_changed.emit()
	last_action_changed.emit(last_action)
	pot_changed.emit(pot)


func next_active_index(from_index: int) -> int:
	var idx := (from_index + 1) % players.size()
	var count := 0
	while players[idx].folded and count < players.size():
		idx = (idx + 1) % players.size()
		count += 1
	return idx


# --- Snapshots / Undo ---

func _save_snapshot() -> Dictionary:
	var snap := {}
	var p_arr: Array[Dictionary] = []
	for p in players:
		var cards: Array[Dictionary] = []
		for c in p.hole_cards:
			cards.append({"suit": c.suit, "rank": c.rank, "face_up": c.face_up, "id": c.id})
		p_arr.append({
			"id": p.id, "name": p.player_name, "chips": p.chips,
			"current_bet": p.current_bet, "folded": p.folded, "has_acted": p.has_acted,
			"hole_cards": cards,
		})
	snap["players"] = p_arr

	var cc: Array[Dictionary] = []
	for c in community_cards:
		cc.append({"suit": c.suit, "rank": c.rank, "face_up": c.face_up, "id": c.id})
	snap["community_cards"] = cc

	var mp: Array[Dictionary] = []
	for c in muck_pile:
		mp.append({"suit": c.suit, "rank": c.rank, "face_up": c.face_up, "id": c.id})
	snap["muck_pile"] = mp

	var dk: Array[Dictionary] = []
	for c in deck:
		dk.append({"suit": c.suit, "rank": c.rank, "face_up": c.face_up, "id": c.id})
	snap["deck"] = dk

	snap["pot"] = pot
	snap["current_bet"] = current_bet
	snap["current_player_index"] = current_player_index
	snap["street"] = street
	snap["is_hand_in_progress"] = is_hand_in_progress
	snap["last_action"] = last_action
	return snap


func _restore_card(d: Dictionary) -> CardData:
	return CardData.new(d["suit"] as CardData.Suit, d["rank"] as CardData.Rank, d["face_up"] as bool)


func undo_last_action() -> void:
	if _action_history.is_empty():
		return
	var snap: Dictionary = _action_history.pop_back()

	players.clear()
	for pd: Dictionary in snap["players"]:
		var p := PlayerData.new(pd["id"] as int, pd["name"] as String)
		p.chips = pd["chips"] as int
		p.current_bet = pd["current_bet"] as int
		p.folded = pd["folded"] as bool
		p.has_acted = pd["has_acted"] as bool
		for cd: Dictionary in pd["hole_cards"]:
			p.hole_cards.append(_restore_card(cd))
		players.append(p)

	community_cards.clear()
	for cd: Dictionary in snap["community_cards"]:
		community_cards.append(_restore_card(cd))

	muck_pile.clear()
	for cd: Dictionary in snap["muck_pile"]:
		muck_pile.append(_restore_card(cd))

	deck.clear()
	for cd: Dictionary in snap["deck"]:
		deck.append(_restore_card(cd))

	pot = snap["pot"] as int
	current_bet = snap["current_bet"] as int
	current_player_index = snap["current_player_index"] as int
	street = snap["street"] as Street
	is_hand_in_progress = snap["is_hand_in_progress"] as bool
	last_action = snap["last_action"] as String
	has_out_of_turn_action = not _action_history.is_empty() and out_of_turn_mode

	pot_changed.emit(pot)
	community_cards_changed.emit()
	muck_changed.emit()
	street_changed.emit(street)
	current_player_changed.emit(current_player_index)
	last_action_changed.emit(last_action)


# --- Player Actions ---

func player_action(player_id: int, action: String, amount: int = 0) -> void:
	var player_idx := -1
	for i in range(players.size()):
		if players[i].id == player_id:
			player_idx = i
			break
	if player_idx == -1:
		return

	_action_history.append(_save_snapshot())

	if out_of_turn_mode and current_player_index >= 0:
		if players[current_player_index].id != player_id:
			has_out_of_turn_action = true

	match action:
		"fold":
			_handle_fold(player_idx)
		"call":
			_handle_call(player_idx)
		"raise":
			_handle_raise(player_idx, amount)
		"check":
			_handle_check(player_idx)
		"bet":
			_handle_bet(player_idx, amount)

	context_menu_player_id = -1
	show_raise_dialog = false
	player_acted.emit(player_id, action, amount)


func _handle_fold(player_idx: int) -> void:
	var player := players[player_idx]
	muck_pile.append_array(player.hole_cards)
	player.folded = true
	player.has_acted = true
	last_action = "%s folds" % player.player_name
	player.hole_cards.clear()
	last_action_changed.emit(last_action)
	muck_changed.emit()
	_check_street_end(player_idx)


func _handle_call(player_idx: int) -> void:
	var player := players[player_idx]
	var call_amount := current_bet - player.current_bet
	var actual := mini(call_amount, player.chips)
	player.chips -= actual
	player.current_bet += actual
	player.has_acted = true
	last_action = "%s calls $%d" % [player.player_name, actual]
	last_action_changed.emit(last_action)
	_check_street_end(player_idx)


func _handle_raise(player_idx: int, raise_total: int) -> void:
	var player := players[player_idx]
	var to_add := raise_total - player.current_bet
	var actual := mini(to_add, player.chips)
	player.chips -= actual
	player.current_bet += actual
	last_raise_increment = player.current_bet - current_bet
	current_bet = player.current_bet
	player.has_acted = true
	aggressor_player_id = player.id
	last_action = "%s raises to $%d" % [player.player_name, player.current_bet]

	for p in players:
		if p.id != player.id and not p.folded:
			p.has_acted = false

	last_action_changed.emit(last_action)
	_check_street_end(player_idx)


func _handle_check(player_idx: int) -> void:
	var player := players[player_idx]
	player.has_acted = true
	last_action = "%s checks" % player.player_name
	last_action_changed.emit(last_action)
	_check_street_end(player_idx)


func _handle_bet(player_idx: int, bet_amount: int) -> void:
	var player := players[player_idx]
	var actual := mini(bet_amount, player.chips)
	player.chips -= actual
	player.current_bet = actual
	last_raise_increment = actual
	current_bet = actual
	player.has_acted = true
	aggressor_player_id = player.id
	last_action = "%s bets $%d" % [player.player_name, actual]

	for p in players:
		if p.id != player.id and not p.folded:
			p.has_acted = false

	last_action_changed.emit(last_action)
	_check_street_end(player_idx)


func _check_street_end(last_actor_idx: int) -> void:
	var active: Array[PlayerData] = []
	for p in players:
		if not p.folded:
			active.append(p)

	if active.size() <= 1:
		_collect_bets()
		if active.size() == 1:
			last_action = "%s wins $%d!" % [active[0].player_name, pot]
			active[0].chips += pot
			pot = 0
		is_hand_in_progress = false
		current_player_index = -1
		pot_changed.emit(pot)
		last_action_changed.emit(last_action)
		hand_ended.emit(active[0].player_name if active.size() == 1 else "", pot)
		current_player_changed.emit(current_player_index)
		return

	var all_acted := true
	var all_matched := true
	for p in active:
		if not p.has_acted:
			all_acted = false
		if p.current_bet != current_bet and p.chips > 0:
			all_matched = false

	if all_acted and all_matched:
		_advance_street()
	else:
		current_player_index = next_active_index(last_actor_idx)
		current_player_changed.emit(current_player_index)


func _collect_bets() -> void:
	for p in players:
		pot += p.current_bet
		p.current_bet = 0
	pot_changed.emit(pot)


func _advance_street() -> void:
	_collect_bets()
	current_bet = 0
	last_raise_increment = 0
	aggressor_player_id = -1

	for p in players:
		if not p.folded:
			p.has_acted = false

	var next_streets := {
		Street.PITCH: Street.PREFLOP,
		Street.PREFLOP: Street.FLOP,
		Street.FLOP: Street.TURN,
		Street.TURN: Street.RIVER,
		Street.RIVER: Street.SHOWDOWN,
	}

	street = next_streets.get(street, Street.SHOWDOWN)

	if street == Street.SHOWDOWN:
		is_hand_in_progress = false
		current_player_index = -1
		last_action = "Showdown! Pot: $%d" % pot
		street_changed.emit(street)
		last_action_changed.emit(last_action)
		current_player_changed.emit(current_player_index)
		return

	if street == Street.FLOP:
		deck.pop_back()  # burn
		for i in range(3):
			var c: CardData = deck.pop_back()
			c.face_up = true
			community_cards.append(c)
	elif street == Street.TURN or street == Street.RIVER:
		deck.pop_back()  # burn
		var c: CardData = deck.pop_back()
		c.face_up = true
		community_cards.append(c)

	current_player_index = next_active_index(dealer_index)
	street_changed.emit(street)
	community_cards_changed.emit()
	current_player_changed.emit(current_player_index)
	last_action = "Street: %s" % STREET_NAMES[street]
	last_action_changed.emit(last_action)


# --- Pitch Actions ---

func pitch_card_to_player(player_index: int, face_up: bool = false) -> void:
	if street != Street.PITCH:
		return
	if pitch_state.has_mispitch:
		return

	# Replacement phase
	if pitch_state.replacement_phase:
		if player_index != pitch_state.replacement_player_index:
			return

		var card: CardData = deck.pop_back()
		card.face_up = false

		var face_up_idx := -1
		for i in range(players[player_index].hole_cards.size()):
			if players[player_index].hole_cards[i].face_up:
				face_up_idx = i
				break
		if face_up_idx != -1:
			var removed_card: CardData = players[player_index].hole_cards[face_up_idx]
			players[player_index].hole_cards.remove_at(face_up_idx)
			removed_card.face_up = false
			deck.push_front(removed_card)

		players[player_index].hole_cards.append(card)

		pitch_state.replacement_phase = false
		pitch_state.replacement_player_index = -1
		pitch_state.face_up_cards.clear()
		pitch_state.total_face_up = 0

		last_action = "Replacement card dealt to %s. Pre-flop betting begins." % players[player_index].player_name
		pitch_card_animated.emit(player_index, false, card)
		_complete_pitch()
		return

	if pitch_state.player_card_counts[player_index] >= 2:
		return

	# Enforce clockwise order
	if player_index != pitch_state.expected_player_index:
		var mispitch_card: CardData = deck.pop_back()
		mispitch_card.face_up = face_up
		pitch_state.has_mispitch = true
		pitch_state.has_mispitch_position = false
		show_misdeal_x = true
		last_action = "Wrong order! Expected %s, got %s. Misdeal!" % [
			players[pitch_state.expected_player_index].player_name,
			players[player_index].player_name
		]
		pitch_card_animated.emit(player_index, face_up, mispitch_card)
		misdeal_detected.emit(last_action)
		pitch_state_changed.emit()
		last_action_changed.emit(last_action)
		misdeal_x_changed.emit(true)
		return

	var card: CardData = deck.pop_back()
	card.face_up = face_up
	players[player_index].hole_cards.append(card)

	pitch_state.player_card_counts[player_index] += 1
	pitch_state.cards_pitched += 1

	if face_up:
		pitch_state.total_face_up += 1
		pitch_state.face_up_cards.append({
			"player_index": player_index,
			"card_index": pitch_state.player_card_counts[player_index] - 1,
			"card": card,
		})

		var sb_index := next_active_index(dealer_index)
		var bb_index := next_active_index(sb_index)

		var is_first_card_to_sb := pitch_state.current_round == 0 and player_index == sb_index
		var is_first_card_to_bb := pitch_state.current_round == 0 and player_index == bb_index

		if is_first_card_to_sb or is_first_card_to_bb or pitch_state.total_face_up >= 2:
			pitch_state.has_mispitch = true
			pitch_state.has_mispitch_position = false
			show_misdeal_x = true
			var reason: String
			if is_first_card_to_sb:
				reason = "First card to SB dealt face-up"
			elif is_first_card_to_bb:
				reason = "First card to BB dealt face-up"
			else:
				reason = "Two or more cards dealt face-up"
			last_action = "%s. Misdeal!" % reason
			misdeal_detected.emit(last_action)
			pitch_state_changed.emit()
			last_action_changed.emit(last_action)
			misdeal_x_changed.emit(true)
			pitch_card_animated.emit(player_index, face_up, card)
			return

	# Advance expected player
	var next_expected := next_active_index(player_index)
	var first_receiver := next_active_index(dealer_index)
	if next_expected == first_receiver:
		pitch_state.current_round += 1
	pitch_state.expected_player_index = next_expected

	last_action = "Card %d/18 pitched to %s%s" % [
		pitch_state.cards_pitched,
		players[player_index].player_name,
		" (FACE UP!)" if face_up else ""
	]

	pitch_card_animated.emit(player_index, face_up, card)
	pitch_state_changed.emit()
	last_action_changed.emit(last_action)

	if pitch_state.cards_pitched >= players.size() * 2:
		if pitch_state.total_face_up == 1:
			var exposed: Dictionary = pitch_state.face_up_cards[0]
			pitch_state.replacement_phase = true
			pitch_state.replacement_player_index = exposed["player_index"] as int
			last_action = "All cards pitched. %s has an exposed card — deal replacement." % players[exposed["player_index"] as int].player_name
			pitch_state_changed.emit()
			last_action_changed.emit(last_action)
		else:
			_complete_pitch()


func mispitch(x: float, y: float) -> void:
	if street != Street.PITCH:
		return
	if pitch_state.has_mispitch:
		return
	if deck.is_empty():
		return

	var card: CardData = deck.pop_back()
	card.face_up = false

	pitch_state.has_mispitch = true
	pitch_state.mispitch_position = Vector2(x, y)
	pitch_state.has_mispitch_position = true
	show_misdeal_x = true
	last_action = "Mispitch! Click the X to declare a misdeal."
	mispitch_animated.emit(Vector2(x, y), card)
	pitch_state_changed.emit()
	last_action_changed.emit(last_action)
	misdeal_x_changed.emit(true)


func declare_misdeal() -> void:
	show_misdeal_x = false
	show_misdeal_menu = false

	for p in players:
		p.hole_cards.clear()

	deck = _shuffle_deck(_build_deck())

	var first_receiver := next_active_index(dealer_index)
	pitch_state.reset(first_receiver)

	last_action = "Misdeal declared. Pitch again from scratch."
	pitch_state_changed.emit()
	last_action_changed.emit(last_action)
	misdeal_x_changed.emit(false)


func _complete_pitch() -> void:
	street = Street.PREFLOP
	var sb_index := next_active_index(dealer_index)
	var bb_index := next_active_index(sb_index)
	current_player_index = next_active_index(bb_index)
	last_action = "All cards pitched. Pre-flop betting begins."
	street_changed.emit(street)
	current_player_changed.emit(current_player_index)
	last_action_changed.emit(last_action)


# --- Context Menu / Raise Dialog ---

func open_context_menu(player_id: int) -> void:
	if layout_mode:
		return
	if not is_hand_in_progress:
		return
	if street == Street.PITCH:
		return
	var player: PlayerData = null
	for p in players:
		if p.id == player_id:
			player = p
			break
	if player == null or player.folded:
		return
	if not out_of_turn_mode and current_player_index >= 0:
		if players[current_player_index].id != player_id:
			return
	context_menu_player_id = player_id
	context_menu_requested.emit(player_id)


func close_context_menu() -> void:
	context_menu_player_id = -1


func open_raise_dialog(player_id: int) -> void:
	raise_dialog_player_id = player_id
	show_raise_dialog = true
	context_menu_player_id = -1
	raise_dialog_requested.emit(player_id)


func close_raise_dialog() -> void:
	show_raise_dialog = false
	raise_dialog_player_id = -1


# --- Misc ---

func move_dealer_button() -> void:
	dealer_index = (dealer_index + 1) % players.size()
	dealer_moved.emit(dealer_index)


func reset_game() -> void:
	init_game()
	game_reset.emit()


func set_game_mode(mode: GameMode) -> void:
	game_mode = mode
	var presets: Array = CASH_BLINDS if mode == GameMode.CASH else TOURNAMENT_BLINDS
	small_blind = presets[0][0]
	big_blind = presets[0][1]
	blinds_changed.emit()


func set_blinds(sb: int, bb: int) -> void:
	small_blind = sb
	big_blind = bb
	blinds_changed.emit()


# --- Layout ---

func _reset_layout_config() -> void:
	layout_config = {
		"seats": TableLayout.DEFAULT_SEATS_PCT.duplicate(),
		"cards": TableLayout.DEFAULT_CARDS_PCT.duplicate(),
		"stacks": TableLayout.DEFAULT_STACKS_PCT.duplicate(),
		"bets": TableLayout.DEFAULT_BETS_PCT.duplicate(),
		"dealer_buttons": TableLayout.DEFAULT_DEALER_BUTTONS_PCT.duplicate(),
		"chairs": TableLayout.DEFAULT_CHAIRS_PCT.duplicate(),
		"pot": TableLayout.DEFAULT_POT_PCT,
		"muck": TableLayout.DEFAULT_MUCK_PCT,
		"community_cards": TableLayout.DEFAULT_COMMUNITY_CARDS_PCT,
		"avatar_scale": 1.0,
		"dealer_button_scale": 1.0,
		"hole_card_scale": 0.55,
		"hole_card_gap": 0.6,
		"community_card_scale": 1.0,
		"muck_card_scale": 1.0,
		"pitch_hand": TableLayout.DEFAULT_PITCH_HAND_PCT,
		"pitch_hand_scale": 1.0,
		"pitch_hand_rotation": 0.0,
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
			layout_config[key] = val
	layout_changed.emit()


func reset_layout() -> void:
	_reset_layout_config()
	layout_changed.emit()


func set_avatar_scale(scale: float) -> void:
	layout_config["avatar_scale"] = scale
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


func set_pitch_hand_scale(scale: float) -> void:
	layout_config["pitch_hand_scale"] = scale
	layout_changed.emit()


func set_pitch_hand_rotation(deg: float) -> void:
	layout_config["pitch_hand_rotation"] = deg
	layout_changed.emit()


func save_layout_to_file() -> void:
	var json := export_layout()
	var file := FileAccess.open("user://layout.json", FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		print("Layout saved to user://layout.json")


func load_layout_from_file() -> bool:
	if not FileAccess.file_exists("user://layout.json"):
		return false
	var file := FileAccess.open("user://layout.json", FileAccess.READ)
	if file:
		var json := file.get_as_text()
		file.close()
		import_layout(json)
		print("Layout loaded from user://layout.json")
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


func has_bet_to_match() -> bool:
	var cp := get_current_player()
	if cp == null:
		return false
	return current_bet > cp.current_bet
