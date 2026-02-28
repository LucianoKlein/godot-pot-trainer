class_name CardTextures
extends RefCounted

const SUIT_FOLDERS := {
	CardData.Suit.HEARTS: "hearts",
	CardData.Suit.DIAMONDS: "diamonds",
	CardData.Suit.CLUBS: "clubs",
	CardData.Suit.SPADES: "spades",
}


static func get_texture(card: CardData) -> Texture2D:
	var folder: String = SUIT_FOLDERS[card.suit]
	var num: int = CardData.RANK_TO_SVG[card.rank]
	var path := "res://assets/cards/%s/%d.svg" % [folder, num]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Card texture not found: %s" % path)
	return null


static func get_back_texture() -> Texture2D:
	var path := "res://assets/cards/card back/card back.svg"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Card back texture not found")
	return null
