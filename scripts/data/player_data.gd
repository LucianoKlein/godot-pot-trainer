class_name PlayerData
extends RefCounted

var id: int
var player_name: String
var chips: int = 1000
var hole_cards: Array[CardData] = []
var current_bet: int = 0
var folded: bool = false
var has_acted: bool = false


func _init(p_id: int = 0, p_name: String = "") -> void:
	id = p_id
	player_name = p_name


func duplicate_player() -> PlayerData:
	var p := PlayerData.new(id, player_name)
	p.chips = chips
	p.current_bet = current_bet
	p.folded = folded
	p.has_acted = has_acted
	p.hole_cards = []
	for c in hole_cards:
		p.hole_cards.append(c.duplicate_card())
	return p
