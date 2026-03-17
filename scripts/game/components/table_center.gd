class_name TableCenter
extends RefCounted
## TableCenter Component — 桌面中心区域 UI 管理
## 封装底池显示、街道标签、公共牌容器、最后动作标签的构建和刷新逻辑

const CardDisplayScene := preload("res://scenes/game/components/card_display.tscn")

var parent: Control
var table_overlay: Control

# UI 节点
var pot_display: VBoxContainer
var pot_amount_label: Label
var street_badge: Label
var community_cards_container: HBoxContainer
var last_action_label: Label


func _init(p: Control, overlay: Control) -> void:
	parent = p
	table_overlay = overlay


func build() -> void:
	_build_pot_display()
	_build_community_cards_container()
	_build_last_action_label()


func _build_pot_display() -> void:
	pot_display = VBoxContainer.new()
	pot_display.name = "PotDisplay"
	pot_display.z_index = 5
	var pot_pos: Vector2 = GameManager.get_layout_position_px("pot")
	pot_display.position = pot_pos - Vector2(40, 10)
	pot_display.size = Vector2(80, 40)
	table_overlay.add_child(pot_display)

	pot_amount_label = Label.new()
	pot_amount_label.text = "底池: 0"
	pot_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pot_amount_label.add_theme_font_size_override("font_size", 14)
	pot_amount_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	pot_display.add_child(pot_amount_label)

	# Street badge — separate from pot_display so it stays visible in chips mode
	street_badge = Label.new()
	street_badge.name = "StreetBadge"
	street_badge.text = "翻牌前"
	street_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	street_badge.add_theme_font_size_override("font_size", 12)
	street_badge.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	street_badge.z_index = 5
	street_badge.position = pot_pos - Vector2(40, 10) + Vector2(0, 22)
	street_badge.size = Vector2(80, 18)
	table_overlay.add_child(street_badge)


func _build_community_cards_container() -> void:
	var cc_pos: Vector2 = GameManager.get_layout_position_px("community_cards")
	var cc_scale: float = GameManager.layout_config.get("community_card_scale", 1.0)
	var cc_card_size := Vector2(48, 66) * cc_scale
	var cc_total_w: float = cc_card_size.x * 5 + 4 * 4  # 5 cards + 4 gaps

	community_cards_container = HBoxContainer.new()
	community_cards_container.name = "CommunityCards"
	community_cards_container.z_index = 5
	community_cards_container.position = cc_pos - Vector2(cc_total_w / 2, cc_card_size.y / 2)
	community_cards_container.size = Vector2(cc_total_w, cc_card_size.y)
	community_cards_container.add_theme_constant_override("separation", 4)
	table_overlay.add_child(community_cards_container)


func _build_last_action_label() -> void:
	last_action_label = Label.new()
	last_action_label.text = ""
	last_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	last_action_label.add_theme_font_size_override("font_size", 13)
	last_action_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	last_action_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	last_action_label.offset_top = -50
	last_action_label.offset_bottom = -30
	parent.add_child(last_action_label)


## 刷新底池显示
func refresh_pot(pot_chip_area: Control = null) -> void:
	# Only show pot_total (settled rounds + folded players' contributions)
	var total := GameManager.engine.pot_total
	pot_amount_label.text = "底池: %d" % total

	# In game mode, respect display_mode
	if not GameManager.layout_mode:
		var is_numbers := GameManager.display_mode == "numbers"
		pot_display.visible = is_numbers
		if pot_chip_area and is_instance_valid(pot_chip_area):
			pot_chip_area.visible = not is_numbers

	# Update pot chip area
	if pot_chip_area:
		pot_chip_area.set_pot_total(total)


## 刷新街道标签
func refresh_street() -> void:
	match GameManager.engine.street:
		"preflop": street_badge.text = "翻牌前"
		"flop": street_badge.text = "翻牌"
		"turn": street_badge.text = "转牌"
		"river": street_badge.text = "河牌"
		_: street_badge.text = GameManager.engine.street


## 刷新公共牌显示
func refresh_community_cards() -> void:
	# Clear existing
	for child in community_cards_container.get_children():
		child.queue_free()

	var cc_scale: float = GameManager.layout_config.get("community_card_scale", 1.0)
	var card_size := Vector2(48, 66) * cc_scale
	var cc_pos: Vector2 = GameManager.get_layout_position_px("community_cards")
	var total_w: float = card_size.x * 5 + 4 * 4  # 5 cards + 4 gaps

	community_cards_container.position = cc_pos - Vector2(total_w / 2, card_size.y / 2)
	community_cards_container.size = Vector2(total_w, card_size.y)

	for card: CardData in GameManager.community_cards:
		var display = CardDisplayScene.instantiate()
		display.custom_minimum_size = card_size
		display.size = card_size
		display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		community_cards_container.add_child(display)
		if display.has_method("set_card"):
			display.set_card(card)


## 设置最后动作文本
func set_last_action(text: String) -> void:
	last_action_label.text = text
