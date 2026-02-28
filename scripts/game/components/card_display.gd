extends TextureRect

var _card: CardData = null
var _show_face: bool = false

static var _back_tex: Texture2D = null


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_card(card: CardData) -> void:
	_card = card
	_show_face = card.face_up
	_update_display()


func set_face_down() -> void:
	_show_face = false
	_update_display()


func set_face_up() -> void:
	if _card:
		_show_face = true
		_update_display()


func _update_display() -> void:
	if _show_face and _card:
		var tex := CardTextures.get_texture(_card)
		if tex:
			texture = tex
			return
	# Show card back
	if _back_tex == null:
		_back_tex = CardTextures.get_back_texture()
	texture = _back_tex
