class_name DeckManager
extends RefCounted
## DeckManager — 牌组管理器
## 负责牌组构建、洗牌、发牌、公共牌生成

var deck: Array = []
var community_cards: Array = []
var board_cards: Array[String] = []


func build_and_shuffle() -> void:
	deck = _shuffle(_build())


func deal_hole_cards(players: Array) -> void:
	for i in range(players.size()):
		players[i].hole_cards.clear()
		for _j in range(2):
			if deck.is_empty():
				break
			var c: RefCounted = deck.pop_back()
			c.face_up = false
			players[i].hole_cards.append(c)


func generate_board_cards(street: String) -> void:
	var card_count := 0
	match street:
		"preflop": card_count = 0
		"flop": card_count = 3
		"turn": card_count = 4
		"river": card_count = 5

	board_cards.clear()
	if card_count == 0:
		community_cards.clear()
		return

	while community_cards.size() < card_count:
		if deck.is_empty():
			break
		var c: RefCounted = deck.pop_back()
		c.face_up = true
		community_cards.append(c)


func reset() -> void:
	deck.clear()
	community_cards.clear()
	board_cards.clear()


func _build() -> Array:
	var d: Array = []
	for s in [CardData.Suit.HEARTS, CardData.Suit.DIAMONDS, CardData.Suit.CLUBS, CardData.Suit.SPADES]:
		for r in range(CardData.Rank.TWO, CardData.Rank.ACE + 1):
			d.append(CardData.new(s, r))
	return d


func _shuffle(d: Array) -> Array:
	var shuffled := d.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := randi_range(0, i)
		var tmp: RefCounted = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	return shuffled
