class_name LayoutPreviewManager
extends RefCounted
## LayoutPreviewManager — 布局编辑器预览管理
## 管理预览卡牌、庄位按钮、答题框的显示和隐藏

const CardDisplayScene := preload("res://scenes/game/components/card_display.tscn")
const AnswerBoxScene := preload("res://scenes/game/components/answer_box.tscn")

var _table_overlay: Control

# Preview elements
var _preview_cards: Array[Control] = []
var _preview_hole_cards: Array = []  # Array of [card0, card1] per seat (9 pairs)
var _preview_hole_card_containers: Array = []  # 9 card containers (for rotation)
var _preview_comm_cards: Array = []  # 5 community preview cards
var _preview_dealer_buttons: Array[Control] = []  # 9 preview dealer buttons
var _preview_answer_boxes: Array[Control] = []  # 9 preview answer boxes


func _init(table_overlay: Control) -> void:
	_table_overlay = table_overlay


func show_preview(visibility_manager: LayoutVisibilityManager, drag_handler: LayoutDragHandler) -> void:
	hide_preview()

	var hc_scale: float = GameManager.layout_config.get("hole_card_scale", 1.0)
	var cc_scale: float = GameManager.layout_config.get("community_card_scale", 1.0)
	var hc_size := Vector2(48, 66) * hc_scale
	var cc_size := Vector2(48, 66) * cc_scale
	var hc_gap: float = GameManager.layout_config.get("hole_card_gap", 0.6)

	# Preview hole cards
	if visibility_manager.is_element_visible("hole_cards"):
		_show_preview_hole_cards(hc_size, hc_gap, drag_handler)

	# Preview community cards
	if visibility_manager.is_element_visible("community_cards"):
		_show_preview_community_cards(cc_size, drag_handler)

	# Preview dealer buttons
	if visibility_manager.is_element_visible("dealer_buttons"):
		_show_preview_dealer_buttons(drag_handler)

	# Preview answer boxes
	if visibility_manager.is_element_visible("answer_boxes"):
		_show_preview_answer_boxes(drag_handler)

	# Update visibility manager with preview references
	visibility_manager.set_preview_references({
		"hole_card_containers": _preview_hole_card_containers,
		"comm_cards": _preview_comm_cards,
		"dealer_buttons": _preview_dealer_buttons,
		"answer_boxes": _preview_answer_boxes,
	})


func hide_preview() -> void:
	# Free preview elements
	for card in _preview_cards:
		if is_instance_valid(card):
			card.queue_free()
	_preview_cards.clear()
	_preview_hole_cards.clear()
	_preview_hole_card_containers.clear()
	_preview_comm_cards.clear()

	for btn in _preview_dealer_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_preview_dealer_buttons.clear()

	for box in _preview_answer_boxes:
		if is_instance_valid(box):
			box.queue_free()
	_preview_answer_boxes.clear()


func get_preview_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	nodes.append_array(_preview_cards)
	nodes.append_array(_preview_dealer_buttons)
	nodes.append_array(_preview_answer_boxes)
	return nodes


func _show_preview_hole_cards(hc_size: Vector2, hc_gap: float, drag_handler: LayoutDragHandler) -> void:
	for i in range(9):
		var card_pos: Vector2 = GameManager.get_layout_position_px("cards", i)
		var total_w: float = hc_size.x + hc_size.x * hc_gap
		var container := Control.new()
		container.custom_minimum_size = Vector2(total_w, hc_size.y)
		container.size = Vector2(total_w, hc_size.y)
		container.position = card_pos - Vector2(total_w / 2, hc_size.y / 2)
		container.z_index = 5
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		container.set_meta("category", "cards")
		container.set_meta("index", i)
		var hc_rot_deg: float = _get_rotation_for_seat("hole_card_rotation", i)
		container.pivot_offset = Vector2(total_w / 2, hc_size.y / 2)
		container.rotation = deg_to_rad(hc_rot_deg)
		_table_overlay.add_child(container)
		_preview_cards.append(container)
		_preview_hole_card_containers.append(container)

		var pair: Array[Control] = []
		for c in range(2):
			var card_node: TextureRect = CardDisplayScene.instantiate()
			card_node.custom_minimum_size = hc_size
			card_node.size = hc_size
			card_node.position = Vector2(c * hc_size.x * hc_gap, 0)
			card_node.z_index = 5
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(card_node)
			card_node.set_face_down()
			pair.append(card_node)
		_preview_hole_cards.append(pair)

	# Make draggable
	if GameManager.layout_mode:
		for i in range(_preview_hole_card_containers.size()):
			var container: Control = _preview_hole_card_containers[i]
			drag_handler._make_draggable(container, "cards", i)


func _show_preview_community_cards(cc_size: Vector2, drag_handler: LayoutDragHandler) -> void:
	var sample_cards: Array[CardData] = [
		CardData.new(CardData.Suit.SPADES, CardData.Rank.ACE, true),
		CardData.new(CardData.Suit.HEARTS, CardData.Rank.KING, true),
		CardData.new(CardData.Suit.DIAMONDS, CardData.Rank.QUEEN, true),
		CardData.new(CardData.Suit.CLUBS, CardData.Rank.JACK, true),
		CardData.new(CardData.Suit.SPADES, CardData.Rank.TEN, true),
	]
	var comm_pos: Vector2 = GameManager.get_layout_position_px("community_cards", -1)
	var comm_container := Control.new()
	var comm_total_w := cc_size.x * 5 + 4 * 4  # 5 cards + 4 gaps
	comm_container.custom_minimum_size = Vector2(comm_total_w, cc_size.y)
	comm_container.size = Vector2(comm_total_w, cc_size.y)
	comm_container.position = comm_pos - Vector2(comm_total_w / 2, cc_size.y / 2)
	comm_container.z_index = 5
	comm_container.mouse_filter = Control.MOUSE_FILTER_STOP
	comm_container.set_meta("category", "community_cards")
	comm_container.set_meta("index", -1)
	_table_overlay.add_child(comm_container)
	_preview_cards.append(comm_container)

	for c in range(5):
		var card_node: TextureRect = CardDisplayScene.instantiate()
		card_node.custom_minimum_size = cc_size
		card_node.size = cc_size
		card_node.position = Vector2(c * (cc_size.x + 4), 0)
		card_node.z_index = 5
		card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		comm_container.add_child(card_node)
		card_node.set_card(sample_cards[c])
		_preview_comm_cards.append(card_node)

	# Make draggable
	if GameManager.layout_mode:
		drag_handler._make_draggable(comm_container, "community_cards", -1)


func _show_preview_dealer_buttons(drag_handler: LayoutDragHandler) -> void:
	var scale: float = GameManager.layout_config.get("dealer_button_scale", 1.0)
	var btn_size := Vector2(28, 28) * scale
	for i in range(9):
		var pos: Vector2 = GameManager.get_layout_position_px("dealer_buttons", i)
		var btn := Control.new()
		btn.name = "PreviewDealer%d" % i
		btn.custom_minimum_size = btn_size
		btn.size = btn_size
		btn.position = pos - btn_size * 0.5
		btn.z_index = 10
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		var bg := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.border_color = Color.BLACK
		sb.set_border_width_all(2)
		var radius := int(btn_size.x / 2)
		sb.corner_radius_top_left = radius
		sb.corner_radius_top_right = radius
		sb.corner_radius_bottom_left = radius
		sb.corner_radius_bottom_right = radius
		bg.add_theme_stylebox_override("panel", sb)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bg)

		var lbl := Label.new()
		lbl.text = "D"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", int(28 * scale))
		lbl.add_theme_color_override("font_color", Color.BLACK)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl)

		_table_overlay.add_child(btn)
		_preview_dealer_buttons.append(btn)
		drag_handler._make_draggable(btn, "dealer_buttons", i)


func _show_preview_answer_boxes(drag_handler: LayoutDragHandler) -> void:
	var scale: float = GameManager.layout_config.get("answer_box_scale", 1.0)
	for i in range(9):
		var pos: Vector2 = GameManager.get_layout_position_px("answer_boxes", i)
		var box: Control = AnswerBoxScene.instantiate()
		box.name = "PreviewAnswerBox%d" % i
		box.preview_mode = true
		box.scale_factor = scale
		box.position = pos - box.size * 0.5
		box.z_index = 10
		box.set_player_label(i, "预览")
		box.set_question_text("底池限注最大加注是多少？")
		_table_overlay.add_child(box)
		_preview_answer_boxes.append(box)
		drag_handler._make_draggable(box, "answer_boxes", i)


func _get_rotation_for_seat(key: String, seat_index: int) -> float:
	var val = GameManager.layout_config.get(key, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	if val is Array and seat_index < val.size():
		return val[seat_index]
	elif val is float:
		return val
	return 0.0
