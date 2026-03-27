class_name SeatHoleCards
extends RefCounted
## SeatHoleCards — 座位手牌显示组件
## 负责手牌容器的创建和刷新

const CardDisplayScene := preload("res://scenes/game/components/card_display.tscn")

var seat_index: int
var table_overlay: Control
var container: Control
var _displays: Array = []


func setup(index: int, overlay: Control) -> RefCounted:
	seat_index = index
	table_overlay = overlay
	return self


func build() -> void:
	container = Control.new()
	container.name = "HoleCards%d" % seat_index
	container.z_index = 6
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.position = GameManager.get_layout_position_px("cards", seat_index)
	table_overlay.add_child(container)


func refresh(player_data: RefCounted = null) -> void:
	for child in container.get_children():
		child.queue_free()
	_displays.clear()

	if player_data == null or player_data.hole_cards.is_empty():
		container.visible = false
		return

	if player_data.folded:
		container.visible = false
		return

	container.visible = true
	var hc_scale: float = GameManager.layout_config.get("hole_card_scale", 0.55)
	var hc_gap: float = GameManager.layout_config.get("hole_card_gap", 0.6)
	var card_size := Vector2(48, 66) * hc_scale
	var rotation_deg: float = 0.0
	var rotations: Array = GameManager.layout_config.get("hole_card_rotation", [])
	if seat_index < rotations.size():
		rotation_deg = rotations[seat_index]

	var card_count: int = player_data.hole_cards.size()
	var total_w: float = card_size.x + (card_count - 1) * card_size.x * hc_gap
	var total_h: float = card_size.y

	var group := Control.new()
	group.custom_minimum_size = Vector2(total_w, total_h)
	group.size = Vector2(total_w, total_h)
	group.position = Vector2(-total_w / 2.0, -total_h / 2.0)
	group.pivot_offset = Vector2(total_w / 2.0, total_h / 2.0)
	group.rotation_degrees = rotation_deg
	container.add_child(group)

	for i in range(card_count):
		var display = CardDisplayScene.instantiate()
		display.custom_minimum_size = card_size
		display.size = card_size
		display.position = Vector2(i * card_size.x * hc_gap, 0)
		display.z_index = i
		display.seat_index = seat_index
		display.card_index = i
		group.add_child(display)
		if display.has_method("set_card"):
			display.set_card(player_data.hole_cards[i])
		_displays.append(display)


func update_position() -> void:
	container.position = GameManager.get_layout_position_px("cards", seat_index)
