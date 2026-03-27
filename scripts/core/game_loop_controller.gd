class_name GameLoopController
extends RefCounted
## GameLoopController — 游戏循环控制器
## 负责游戏循环、训练问题处理、答题验证

var _gm: Node  # GameManager reference


func setup(gm: Node) -> RefCounted:
	_gm = gm
	return self


func run_game_loop() -> void:
	if _gm.config.training_mode == "game":
		_run_step_by_step()
	else:
		_run_until_question()


func _run_step_by_step() -> void:
	if not _gm.is_game_running:
		return

	var result: Dictionary = _gm.engine.advance_one_step(_gm.config)
	_gm._sync_from_engine()
	_gm._generate_board_cards()

	if result["is_game_over"]:
		_handle_game_over()
		return

	if result["has_question"]:
		_handle_training_question()
		return

	if result["seat"] >= 0:
		_gm.npc_acted.emit(result["seat"], result["action"], result["amount"])

	_gm.get_tree().create_timer(1.0).timeout.connect(_run_step_by_step)


func _run_until_question() -> void:
	if not _gm.is_game_running:
		return

	_gm.engine.run_until_question(_gm.config)
	_gm._sync_from_engine()
	_gm._generate_board_cards()

	if _gm.engine.is_game_over:
		_handle_game_over()
		return

	if not _gm.engine.training_question.is_empty():
		_handle_training_question()


func _handle_training_question() -> void:
	var q: Dictionary = _gm.engine.training_question
	if q["is_answer"]:
		if q["max_raise_to"] > _gm.config.initial_stack or q["is_all_in"]:
			var amount: int = q["all_in_amount"] if q["is_all_in"] else q["max_raise_to"]
			_gm.last_action = Locale.tr_key("seat_raise_to") % [_gm.get_physical_seat(q["seat"]) + 1, amount]
			_gm.last_action_changed.emit(_gm.last_action)
			_gm.npc_acted.emit(q["seat"], "raise", amount)
			_gm.engine.complete_raise(amount)
			_gm._sync_from_engine()
			_gm.get_tree().create_timer(0.3).timeout.connect(run_game_loop)
			return
		_gm.last_action = Locale.tr_key("seat_raise_question") % (_gm.get_physical_seat(q["seat"]) + 1)
		_gm.last_action_changed.emit(_gm.last_action)
		_gm.training_question_appeared.emit(q)
	else:
		_gm.last_action = Locale.tr_key("seat_raise_to") % [_gm.get_physical_seat(q["seat"]) + 1, q["raise_amount"]]
		_gm.last_action_changed.emit(_gm.last_action)
		_gm.npc_acted.emit(q["seat"], "raise", q["raise_amount"])
		_gm.engine.complete_raise(q["raise_amount"])
		_gm._sync_from_engine()
		_gm.get_tree().create_timer(0.3).timeout.connect(run_game_loop)


func _handle_game_over() -> void:
	_gm.is_hand_in_progress = false
	_gm.last_action = Locale.tr_key("hand_over")
	_gm.last_action_changed.emit(_gm.last_action)
	_gm.game_over.emit()

	if _gm.config.training_mode == "scenario" and _gm.is_game_running:
		_gm.get_tree().create_timer(2.0).timeout.connect(_gm._start_new_hand)
	else:
		_gm.is_game_running = false
		_gm.is_game_started = false


func submit_answer(user_input: int) -> bool:
	if _gm.engine.training_question.is_empty():
		return false
	if not _gm.engine.training_question["is_answer"]:
		return false

	var expected: int = _gm.engine.training_question["max_raise_to"]

	if user_input == expected:
		_gm.answer_result.emit(true, user_input, expected)
		_gm.engine.complete_raise(expected)
		_gm._sync_from_engine()
		_gm.training_question_cleared.emit()
		_gm.get_tree().create_timer(0.5).timeout.connect(run_game_loop)
		return true
	else:
		_gm.answer_result.emit(false, user_input, expected)
		return false
