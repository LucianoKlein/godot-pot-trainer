class_name CardData
extends RefCounted

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }
enum Rank { TWO = 2, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE }

const SUIT_NAMES := {
	Suit.HEARTS: "hearts",
	Suit.DIAMONDS: "diamonds",
	Suit.CLUBS: "clubs",
	Suit.SPADES: "spades",
}

const SUIT_SHORT := {
	Suit.HEARTS: "h",
	Suit.DIAMONDS: "d",
	Suit.CLUBS: "c",
	Suit.SPADES: "s",
}

const SUIT_SYMBOLS := {
	Suit.HEARTS: "♥",
	Suit.DIAMONDS: "♦",
	Suit.CLUBS: "♣",
	Suit.SPADES: "♠",
}

const RANK_NAMES := {
	Rank.TWO: "2", Rank.THREE: "3", Rank.FOUR: "4", Rank.FIVE: "5",
	Rank.SIX: "6", Rank.SEVEN: "7", Rank.EIGHT: "8", Rank.NINE: "9",
	Rank.TEN: "10", Rank.JACK: "J", Rank.QUEEN: "Q", Rank.KING: "K", Rank.ACE: "A",
}

# Maps rank enum to SVG filename number (ACE=1, TWO=2 ... KING=13)
const RANK_TO_SVG := {
	Rank.ACE: 1, Rank.TWO: 2, Rank.THREE: 3, Rank.FOUR: 4, Rank.FIVE: 5,
	Rank.SIX: 6, Rank.SEVEN: 7, Rank.EIGHT: 8, Rank.NINE: 9, Rank.TEN: 10,
	Rank.JACK: 11, Rank.QUEEN: 12, Rank.KING: 13,
}

var suit: Suit
var rank: Rank
var id: String  # e.g. "Ah", "10s"
var face_up: bool = false


func _init(p_suit: Suit = Suit.HEARTS, p_rank: Rank = Rank.TWO, p_face_up: bool = false) -> void:
	suit = p_suit
	rank = p_rank
	face_up = p_face_up
	id = RANK_NAMES[rank] + SUIT_SHORT[suit]


func get_display_text() -> String:
	return RANK_NAMES[rank] + SUIT_SYMBOLS[suit]


func duplicate_card() -> CardData:
	var c := CardData.new(suit, rank, face_up)
	return c
