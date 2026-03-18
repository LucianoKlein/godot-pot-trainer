extends TextureRect

signal card_clicked(card_display: TextureRect)

var _card: RefCounted = null
var _show_face: bool = false
var seat_index: int = -1
var card_index: int = -1

static var _back_tex: Texture2D = null


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func set_card(card: RefCounted) -> void:
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


func get_card() -> RefCounted:
	return _card


var _click_enabled: bool = false


func enable_click() -> void:
	if _click_enabled:
		return
	_click_enabled = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)


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
