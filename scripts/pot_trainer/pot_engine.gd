class_name PotEngine
extends RefCounted

# --- Constants ---
const INITIAL_STACK := 7500  # 默认值，实际由 config.initial_stack 决定

# --- Game State ---

var street: String = "preflop"  # preflop / flop / turn / river
var dealer_seat: int = 0
var current_seat: int = 0
var players: Array = []  # Array of PotPlayerState
var pot_total: int = 0
var pot_current_bet: int = 0
var pot_last_raise_size: int = 0
var training_question: Dictionary = {}  # empty = no question
var is_game_over: bool = false
var _big_blind: int = 50  # cached for _advance_street in complete_raise


# --- Player State (inner class) ---

class PotPlayerState:
	var seat: int = 0
	var status: String = "active"  # "active" / "folded"
	var template: PlayerTemplates.PlayerTemplate = null
	var stack: int = 0
	var round_contribution: int = 0
	var has_acted_this_round: bool = false
	var last_action: String = ""  # "" / "blind" / "fold" / "check" / "call" / "bet" / "raise"

	func _init(p_seat: int = 0, p_template: PlayerTemplates.PlayerTemplate = null, p_stack: int = INITIAL_STACK) -> void:
		seat = p_seat
		template = p_template
		stack = p_stack


# --- Init ---

func create_initial_state(config: RefCounted) -> void:
	_big_blind = config.big_blind
	var templates := TablePresets.assign_player_templates(
		config.table_preset as TablePresets.PresetId, config.player_count
	)

	players.clear()
	for i in range(config.player_count):
		players.append(PotPlayerState.new(i, templates[i], config.initial_stack))

	dealer_seat = config.dealer_seat
	var sb_seat: int = (dealer_seat + 1) % config.player_count
	var bb_seat: int = (dealer_seat + 2) % config.player_count

	# Post small blind
	var sb_amount: int = mini(config.small_blind, players[sb_seat].stack)
	players[sb_seat].round_contribution = sb_amount
	players[sb_seat].stack -= sb_amount
	players[sb_seat].has_acted_this_round = true
	players[sb_seat].last_action = "blind"

	# Post big blind
	var bb_amount: int = mini(config.big_blind, players[bb_seat].stack)
	players[bb_seat].round_contribution = bb_amount
	players[bb_seat].stack -= bb_amount
	players[bb_seat].has_acted_this_round = true
	players[bb_seat].last_action = "blind"

	# Post Big Big Blind (1/2/5 WSOP)
	var last_blind_seat: int = bb_seat
	if config.has_bbb:
		var bbb_seat: int = (dealer_seat + 3) % config.player_count
		var bbb_amt: int = mini(config.bbb_amount, players[bbb_seat].stack)
		players[bbb_seat].round_contribution = bbb_amt
		players[bbb_seat].stack -= bbb_amt
		players[bbb_seat].has_acted_this_round = true
		players[bbb_seat].last_action = "blind"
		last_blind_seat = bbb_seat

	# 1/2 和 1/2/5 模式：preflop 最小 call/open 为 5
	var is_12_mode: bool = (config.small_blind == 1)
	var effective_open: int = 5 if is_12_mode else bb_amount

	street = "preflop"
	current_seat = (last_blind_seat + 1) % config.player_count
	pot_total = 0
	pot_current_bet = effective_open
	pot_last_raise_size = effective_open
	training_question = {}
	is_game_over = false


# --- Helpers ---

static func _ceil5(n: int) -> int:
	return ceili(float(n) / 5.0) * 5


func _next_active_seat(from_seat: int) -> int:
	var n: int = players.size()
	for i in range(1, n + 1):
		var idx: int = (from_seat + i) % n
		if players[idx].status == "active":
			return idx
	return from_seat


func _active_players() -> Array:
	var result: Array = []
	for p in players:
		if p.status == "active":
			result.append(p)
	return result


func _is_betting_round_closed() -> bool:
	for p: PotPlayerState in players:
		if p.status != "active":
			continue
		if not p.has_acted_this_round:
			return false
		if p.round_contribution != pot_current_bet and p.stack > 0:
			return false
	return true


# --- Street Progression ---

func _reset_betting_round(big_blind: int) -> void:
	for p: PotPlayerState in players:
		if p.round_contribution > 0:
			pot_total += p.round_contribution
		p.round_contribution = 0
		p.has_acted_this_round = false
		p.last_action = ""
	pot_current_bet = 0
	pot_last_raise_size = big_blind


func _advance_street(big_blind: int) -> void:
	var order: Array = ["preflop", "flop", "turn", "river"]
	var idx: int = order.find(street)
	if idx < 0 or idx >= order.size() - 1:
		return
	street = order[idx + 1]
	_reset_betting_round(big_blind)
	# First active player after dealer
	current_seat = _next_active_seat(dealer_seat)


# --- Training Question ---

func _create_training_question(seat: int, config: RefCounted) -> Dictionary:
	var player: PotPlayerState = players[seat]
	var current_bet: int = pot_current_bet
	var is_bet: bool = (current_bet == 0)

	var min_raise_to: int
	var max_raise_to: int

	var is_12_mode: bool = (config.small_blind == 1)

	if is_bet:
		min_raise_to = config.big_blind
		max_raise_to = pot_total
		# 1/2 和 1/2/5 模式：bet ceil5, min=5
		if is_12_mode:
			max_raise_to = _ceil5(max_raise_to)
			min_raise_to = 5
	else:
		min_raise_to = current_bet + pot_last_raise_size

		if config.blinds_mode == "1/2/5":
			# 1/2/5 WSOP: ceil5(currentBet)*3 + Σceil5(others) + ceil5(pot)
			var other_cont: int = 0
			var excluded: bool = false
			for p: PotPlayerState in players:
				if p.seat == seat:
					continue
				if p.round_contribution == current_bet and not excluded:
					excluded = true
					continue
				other_cont += _ceil5(p.round_contribution)
			max_raise_to = _ceil5(current_bet) * 3 + other_cont + _ceil5(pot_total)

		elif config.blinds_mode == "1/2":
			# 1/2: ceil5(前一个玩家)*3 + ceil5(其他总和) + ceil5(pot)
			var last_better_cont: int = 0
			var has_last_better: bool = false
			for p: PotPlayerState in players:
				if p.seat == seat:
					continue
				if p.round_contribution == current_bet:
					last_better_cont = p.round_contribution
					has_last_better = true
					break

			var others_total: int = 0
			if has_last_better:
				var excluded2: bool = false
				for p: PotPlayerState in players:
					if p.seat == seat:
						continue
					if p.round_contribution == current_bet and not excluded2:
						excluded2 = true
						continue
					others_total += p.round_contribution
			else:
				# preflop 特殊：SB+BB 合并为"前一个玩家"
				var blinds_total: int = 0
				for p: PotPlayerState in players:
					if p.seat == seat:
						continue
					blinds_total += p.round_contribution
				last_better_cont = blinds_total
				others_total = 0
			max_raise_to = _ceil5(last_better_cont) * 3 + _ceil5(others_total) + _ceil5(pot_total)

		else:
			# 标准模式（5/10, 25/50）
			var other_contributions: int = 0
			var has_excluded_one: bool = false
			for p: PotPlayerState in players:
				if p.seat == seat:
					continue
				if p.round_contribution == current_bet and not has_excluded_one:
					has_excluded_one = true
					continue
				other_contributions += p.round_contribution
			max_raise_to = current_bet * 3 + pot_total + other_contributions

	# All-in check
	var player_total_chips: int = player.stack + player.round_contribution
	var is_all_in: bool = player_total_chips < max_raise_to
	var all_in_amount: int = player_total_chips if is_all_in else 0

	# Roll whether this is an answer question
	var is_answer: bool = randf() * 100.0 < config.question_probability

	var raise_amount := 0
	if not is_answer:
		if is_all_in:
			raise_amount = all_in_amount
		else:
			var unit: int = config.round_unit
			var mn: int = ceili(float(min_raise_to) / float(unit)) * unit
			var mx: int = floori(float(max_raise_to) / float(unit)) * unit
			if mn > mx:
				raise_amount = mx
			else:
				var steps: int = (mx - mn) / unit
				raise_amount = mn + randi_range(0, steps) * unit

	return {
		"seat": seat,
		"min_raise_to": min_raise_to,
		"max_raise_to": max_raise_to,
		"is_answer": is_answer,
		"raise_amount": raise_amount,
		"is_all_in": is_all_in,
		"all_in_amount": all_in_amount,
	}


# --- Main Step: NPC acts ---

func advance_game(config: RefCounted) -> void:
	if not training_question.is_empty():
		return

	var player: PotPlayerState = players[current_seat]

	if player.status == "folded":
		current_seat = _next_active_seat(current_seat)
		return

	# Auto-fold if no chips at all
	var player_total_chips: int = player.stack + player.round_contribution
	if player_total_chips == 0:
		player.status = "folded"
		current_seat = _next_active_seat(current_seat)
		if _active_players().size() <= 1:
			is_game_over = true
		return

	var current_bet: int = pot_current_bet
	var need_to_call: int = current_bet - player.round_contribution
	var template: PlayerTemplates.PlayerTemplate = player.template

	var action: String

	if need_to_call == 0:
		# No pressure: use noAggression weights
		var roll: int = PlayerTemplates.weighted_roll(template.no_aggression)
		match roll:
			PlayerTemplates.NoAggressionAction.FOLD:
				action = "fold"
			PlayerTemplates.NoAggressionAction.CHECK:
				action = "check"
			_:  # BET_SMALL, BET_BIG, BET_POT
				action = "bet"
	else:
		# Under pressure: use vsAggressionBySize
		var pot_size: int = pot_total
		for p: PotPlayerState in players:
			pot_size += p.round_contribution
		var agg_size: int = PlayerTemplates.get_aggression_size(need_to_call, pot_size)
		var vs_weights: Dictionary = template.vs_aggression_by_size[agg_size]
		var roll: int = PlayerTemplates.weighted_roll(vs_weights)

		match roll:
			PlayerTemplates.VsAggressionAction.FOLD:
				action = "fold"
			PlayerTemplates.VsAggressionAction.CALL:
				action = "call" if player.stack > 0 else "fold"
			_:  # RAISE_SMALL, RAISE_BIG, RAISE_POT
				if player.stack == 0 or player.stack < need_to_call:
					action = "fold"
				else:
					action = "raise"

	player.has_acted_this_round = true
	player.last_action = action

	match action:
		"fold":
			player.status = "folded"
			if player.round_contribution > 0:
				pot_total += player.round_contribution
				player.round_contribution = 0
			if _active_players().size() <= 1:
				is_game_over = true
				return

		"check":
			pass

		"call":
			var call_amount: int = mini(need_to_call, player.stack)
			player.round_contribution += call_amount
			player.stack -= call_amount

		"bet", "raise":
			# Mark other players as needing to act
			for p: PotPlayerState in players:
				if p.seat != player.seat and p.status == "active":
					p.has_acted_this_round = false
			# Generate training question
			training_question = _create_training_question(player.seat, config)
			return

	if _is_betting_round_closed():
		_advance_street(config.big_blind)
	else:
		current_seat = _next_active_seat(current_seat)


# --- Complete Raise (after question answered or auto) ---

func complete_raise(raise_amount: int) -> void:
	if training_question.is_empty():
		return

	var seat: int = training_question["seat"]
	var player: PotPlayerState = players[seat]

	var amount_to_add: int = raise_amount - player.round_contribution
	var actual_amount: int = mini(amount_to_add, player.stack)
	player.stack -= actual_amount
	player.round_contribution += actual_amount

	var raise_increment: int = player.round_contribution - pot_current_bet
	pot_last_raise_size = maxi(raise_increment, pot_last_raise_size)
	pot_current_bet = player.round_contribution

	training_question = {}

	if _is_betting_round_closed():
		_advance_street(_big_blind)
	else:
		current_seat = _next_active_seat(current_seat)


# --- Single-step advance (for game mode: one NPC action at a time) ---

func advance_one_step(config: RefCounted) -> Dictionary:
	if is_game_over:
		return {"done": true, "is_game_over": true, "has_question": false, "seat": -1, "action": "", "amount": 0}
	if not training_question.is_empty():
		return {"done": true, "is_game_over": false, "has_question": true, "seat": training_question["seat"], "action": "raise", "amount": 0}

	var seat_before := current_seat
	advance_game(config)
	var player: PotPlayerState = players[seat_before]

	return {
		"done": false,
		"seat": seat_before,
		"action": player.last_action,
		"amount": player.round_contribution,
		"has_question": not training_question.is_empty(),
		"is_game_over": is_game_over,
	}


# --- Run until a question appears or game ends ---

func run_until_question(config: RefCounted) -> void:
	var guard := 0
	var is_scenario: bool = config.training_mode == "scenario"

	while guard < 500:
		if is_game_over:
			break
		if not training_question.is_empty():
			# Scenario mode: skip non-answer questions
			if is_scenario and not training_question["is_answer"]:
				complete_raise(training_question["raise_amount"])
				guard += 1
				continue
			# All-in: auto-complete
			if training_question["is_answer"] and training_question["is_all_in"]:
				complete_raise(training_question["all_in_amount"])
				guard += 1
				continue
			# Skip question if max raise exceeds initial stack
			if training_question["is_answer"] and training_question["max_raise_to"] > config.initial_stack:
				complete_raise(training_question["max_raise_to"])
				guard += 1
				continue
			break
		advance_game(config)
		guard += 1
