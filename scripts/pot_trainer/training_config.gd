class_name TrainingConfig
extends RefCounted

var small_blind: int = 25
var big_blind: int = 50
var question_probability: int = 100  # 0-100, percentage chance of asking user
var player_count: int = 8
var dealer_seat: int = 0
var table_preset: int = 0  # TablePresets.PresetId
var training_mode: String = "scenario"  # "scenario" or "game"
var blinds_mode: String = "25/50"  # "25/50" / "5/10" / "1/2" / "1/2/5"
var round_unit: int = 25  # 取整倍数
var initial_stack: int = 7500
var has_bbb: bool = false  # 是否有大大盲（1/2/5 WSOP）
var bbb_amount: int = 0  # 大大盲金额


func _init(p_sb: int = 25, p_prob: int = 100) -> void:
	small_blind = p_sb
	big_blind = p_sb * 2
	question_probability = p_prob
	_update_mode()


func set_blinds(sb: int, bb: int) -> void:
	small_blind = sb
	big_blind = bb
	_update_mode()


func _update_mode() -> void:
	has_bbb = false
	bbb_amount = 0
	# 1/2/5 必须在 1/2 之前检测：set_blinds(1, 5) 传入 bb=5
	if small_blind == 1 and big_blind == 5:
		# 1/2/5 WSOP: SB=1, BB=2, BBB=5
		big_blind = 2  # 实际 BB 是 2，5 是 BBB
		blinds_mode = "1/2/5"
		round_unit = 5
		initial_stack = 520
		has_bbb = true
		bbb_amount = 5
	elif small_blind == 1 and big_blind == 2:
		blinds_mode = "1/2"
		round_unit = 5
		initial_stack = 520
	elif small_blind == 5 and big_blind == 10:
		blinds_mode = "5/10"
		round_unit = 5
		initial_stack = 1300
	else:
		blinds_mode = "25/50"
		round_unit = 25
		initial_stack = 7500
