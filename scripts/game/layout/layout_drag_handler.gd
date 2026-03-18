class_name LayoutDragHandler
extends RefCounted
## LayoutDragHandler — 布局编辑器拖拽逻辑管理
## 处理所有拖拽相关的逻辑，包括拖拽状态、偏移、提示显示

signal drag_ended

var _parent: Control
var _table_overlay: Control
var _dragging_node: Node = null
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_connections: Array = []  # Array of [Control, Callable]
var _drag_tooltip: Label = null

var is_dragging: bool:
	get: return _dragging_node != null


func setup(parent: Control, table_overlay: Control) -> RefCounted:
	_parent = parent
	_table_overlay = table_overlay
	_build_tooltip()
	return self


func _build_tooltip() -> void:
	_drag_tooltip = Label.new()
	_drag_tooltip.name = "DragTooltip"
	_drag_tooltip.visible = false
	_drag_tooltip.z_index = 300
	_drag_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drag_tooltip.add_theme_font_size_override("font_size", 26)
	_drag_tooltip.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	var tt_bg := StyleBoxFlat.new()
	tt_bg.bg_color = Color(0.1, 0.1, 0.18, 0.82)
	tt_bg.set_corner_radius_all(4)
	tt_bg.set_content_margin_all(4)
	_drag_tooltip.add_theme_stylebox_override("normal", tt_bg)
	_drag_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parent.add_child(_drag_tooltip)


func enable_drag(nodes: Dictionary) -> void:
	disable_drag()
	for key in nodes:
		var node_list = nodes[key]
		if node_list is Array:
			for i in range(node_list.size()):
				_make_draggable(node_list[i], key, i)
		else:
			_make_draggable(node_list, key, -1)


func disable_drag() -> void:
	for pair in _drag_connections:
		if not is_instance_valid(pair[0]):
			continue
		var node: Node = pair[0]
		var cb: Callable = pair[1]
		if node.gui_input.is_connected(cb):
			node.gui_input.disconnect(cb)
		if node.name == "DragOverlay":
			node.queue_free()
	_drag_connections.clear()
	_dragging_node = null


func enable_drag_for_element(element_key: String, nodes: Variant) -> void:
	if nodes is Array:
		for i in range(nodes.size()):
			_make_draggable(nodes[i], element_key, i)
	else:
		_make_draggable(nodes, element_key, -1)


func disable_drag_for_element(nodes_to_remove: Array[Node]) -> void:
	var keep: Array = []
	for pair in _drag_connections:
		if not is_instance_valid(pair[0]):
			continue
		var node: Node = pair[0]
		var cb: Callable = pair[1]
		var match_found: bool = false
		if node in nodes_to_remove:
			match_found = true
		elif node.name == "DragOverlay" and node.get_parent() in nodes_to_remove:
			match_found = true
		if match_found:
			if node.gui_input.is_connected(cb):
				node.gui_input.disconnect(cb)
			if node.name == "DragOverlay":
				node.queue_free()
		else:
			keep.append(pair)
	_drag_connections = keep


func _make_draggable(node: Node, category: String, idx: int) -> void:
	node.set_meta("layout_category", category)
	node.set_meta("layout_index", idx)
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		var cb: Callable = _on_drag_input.bind(node)
		node.gui_input.connect(cb)
		_drag_connections.append([node, cb])
	elif node is Node2D:
		# Plain Node2D has no gui_input signal; add a transparent Control overlay
		var overlay: Control = Control.new()
		overlay.name = "DragOverlay"
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var sz: Vector2 = Vector2(80, 80)
		if node.has_method("get_total_size"):
			sz = node.get_total_size()
			if sz.length_squared() < 1.0:
				sz = Vector2(80, 80)
		overlay.size = sz
		# Chip stacks grow upward (negative Y), offset overlay to cover visual area
		overlay.position = Vector2(0, -sz.y + sz.x) if node.has_method("get_stack_height") else Vector2.ZERO
		node.add_child(overlay)
		var cb: Callable = _on_drag_input.bind(node)
		overlay.gui_input.connect(cb)
		_drag_connections.append([overlay, cb])


func _on_drag_input(event: InputEvent, node: Node) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging_node = node
				_drag_offset = node.position - mb.global_position
				_show_drag_tooltip(node)
			else:
				_dragging_node = null
				_hide_drag_tooltip()
				drag_ended.emit()
	elif event is InputEventMouseMotion and _dragging_node == node:
		var delta: Vector2 = (event as InputEventMouseMotion).global_position + _drag_offset - node.position
		node.position += delta
		var category: String = node.get_meta("layout_category")
		var idx: int = node.get_meta("layout_index")
		var node_size: Vector2 = Vector2.ZERO
		if node is Control:
			node_size = node.size
		elif node is Node2D and node.has_method("get_size"):
			node_size = node.get_size()
		var center: Vector2 = node.position + node_size * 0.5
		var pct: Vector2 = TableLayout.px_to_pct(center)
		# Map display category to config key
		var config_key: String = _get_config_key(category)
		GameManager.update_layout_position(config_key, idx, pct.x, pct.y)
		_update_drag_tooltip_pos(node)


func _show_drag_tooltip(node: Node) -> void:
	if not _drag_tooltip:
		return
	var category: String = node.get_meta("layout_category")
	var idx: int = node.get_meta("layout_index")
	_drag_tooltip.text = _get_element_name(category, idx)
	_drag_tooltip.visible = true
	_update_drag_tooltip_pos(node)


func _update_drag_tooltip_pos(node: Node) -> void:
	if not _drag_tooltip or not _drag_tooltip.visible:
		return
	var tw: float = _drag_tooltip.size.x
	if tw < 20:
		tw = 100
	var node_size: Vector2 = Vector2.ZERO
	if node is Control:
		node_size = node.size
	elif node is Node2D and node.has_method("get_size"):
		node_size = node.get_size()
	_drag_tooltip.position = Vector2(
		node.position.x + node_size.x * 0.5 - tw * 0.5,
		node.position.y - 28
	)
	_drag_tooltip.size.x = 0


func _hide_drag_tooltip() -> void:
	if _drag_tooltip:
		_drag_tooltip.visible = false


func _get_element_name(category: String, idx: int) -> String:
	var seat_str: String = "玩家%d " % (idx + 1) if idx >= 0 else ""
	match category:
		"seats": return seat_str + "头像"
		"chairs": return seat_str + "椅子"
		"bets": return seat_str + "下注筹码"
		"stacks": return seat_str + "本金"
		"cards": return seat_str + "手牌"
		"dealer_buttons": return seat_str + "庄家按钮"
		"answer_boxes": return seat_str + "答题框"
		"action_boxes": return seat_str + "行动框"
		"pot": return "底池"
		"community_cards": return "公共牌"
		"purple_stacks": return seat_str + "紫色筹码"
		"black_stacks": return seat_str + "黑色筹码"
		"green_stacks": return seat_str + "绿色筹码"
		"bet_chips": return seat_str + "下注筹码"
		"ordered_bet_chips": return seat_str + "整齐筹码"
		"pot_chips": return "底池筹码"
		"chip_record": return "筹码记录"
		_: return category


func _get_config_key(category: String) -> String:
	# Map display category to layout_config key
	match category:
		"bet_chips": return "bets"
		"ordered_bet_chips": return "ordered_bet_chips"
		"pot_chips": return "pot"
		_: return category
