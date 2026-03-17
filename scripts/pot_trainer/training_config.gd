class_name TrainingConfig
extends RefCounted

var small_blind: int = 25
var big_blind: int = 50
var question_probability: int = 100  # 0-100, percentage chance of asking user
var player_count: int = 8
var dealer_seat: int = 0
var table_preset: int = 0  # TablePresets.PresetId
var training_mode: String = "scenario"  # "scenario" or "game"


func _init(p_sb: int = 25, p_prob: int = 100) -> void:
	small_blind = p_sb
	big_blind = p_sb * 2
	question_probability = p_prob
