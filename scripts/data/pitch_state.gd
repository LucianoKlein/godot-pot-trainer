class_name PitchState
extends RefCounted

var cards_pitched: int = 0
var player_card_counts: Array[int] = []
var has_mispitch: bool = false
var mispitch_position: Vector2 = Vector2.ZERO  # percentage coords, Vector2.ZERO = null
var has_mispitch_position: bool = false
var expected_player_index: int = 0
var current_round: int = 0  # 0 = first card to each, 1 = second card to each
var face_up_cards: Array[Dictionary] = []  # [{player_index, card_index, card}]
var total_face_up: int = 0
var replacement_phase: bool = false
var replacement_player_index: int = -1  # -1 = null


func _init() -> void:
	player_card_counts.resize(9)
	player_card_counts.fill(0)


func reset(first_receiver: int) -> void:
	cards_pitched = 0
	player_card_counts.resize(9)
	player_card_counts.fill(0)
	has_mispitch = false
	mispitch_position = Vector2.ZERO
	has_mispitch_position = false
	expected_player_index = first_receiver
	current_round = 0
	face_up_cards.clear()
	total_face_up = 0
	replacement_phase = false
	replacement_player_index = -1
