class_name PlayerData
extends RefCounted

var id: int
var player_name: String
var chips: int = 7500
var hole_cards: Array = []
var current_bet: int = 0
var folded: bool = false
var has_acted: bool = false

# Pot Trainer fields
var template: PlayerTemplates.PlayerTemplate = null
var round_contribution: int = 0
var status: String = "active"  # "active" / "folded"
var last_action: String = ""  # "" / "blind" / "fold" / "check" / "call" / "bet" / "raise"


func _init(p_id: int = 0, p_name: String = "") -> void:
	id = p_id
	player_name = p_name


func duplicate_player() -> RefCounted:
	var p := PlayerData.new(id, player_name)
	p.chips = chips
	p.current_bet = current_bet
	p.folded = folded
	p.has_acted = has_acted
	p.template = template
	p.round_contribution = round_contribution
	p.status = status
	p.last_action = last_action
	p.hole_cards = []
	for c in hole_cards:
		p.hole_cards.append(c.duplicate_card())
	return p
