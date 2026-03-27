extends Control

const CardDisplayScene := preload("res://scenes/game/components/card_display.tscn")
const LayoutEditorScript := preload("res://scripts/game/layout_editor.gd")
const SeatManagerScript := preload("res://scripts/ui/managers/seat_manager.gd")
const ChipManagerScript := preload("res://scripts/ui/managers/chip_manager.gd")
const DealerButtonScript := preload("res://scripts/ui/components/dealer_button.gd")
const TableCenterScript := preload("res://scripts/game/components/table_center.gd")
const ControlPanelManagerScript := preload("res://scripts/game/ui/control_panel_manager.gd")
const QuestionPanelManagerScript := preload("res://scripts/game/ui/question_panel_manager.gd")
const GameOverManagerScript := preload("res://scripts/game/ui/game_over_manager.gd")
const ActionBoxManagerScript := preload("res://scripts/game/ui/action_box_manager.gd")
const AdOverlayManagerScript := preload("res://scripts/game/ui/ad_overlay_manager.gd")

# --- Node references ---
var _bg: TextureRect
var _chairs: Array[TextureRect] = []
var _table_overlay: Control
var _seat_mgr: SeatManager
var _chip_mgr: ChipManager
var _dealer_btn: DealerButton
var _control_panel_manager: RefCounted
var _table_center: RefCounted
var _layout_editor: RefCounted

# --- Delegated managers ---
var _question_mgr: RefCounted
var _game_over_mgr: RefCounted
var _action_box_mgr: RefCounted
var _ad_mgr: RefCounted


func _ready() -> void:
	_bg = $Background
	for i in range(1, 10):
		_chairs.append(get_node("Chair%d" % i) as TextureRect)
	GameManager.init_game()
	_build_table_overlay()
	_seat_mgr = SeatManagerScript.new().setup(self, _table_overlay, _chairs)
	_seat_mgr.build()
	_chip_mgr = ChipManagerScript.new().setup(self, _table_overlay)
	_chip_mgr.build()
	_dealer_btn = DealerButtonScript.new().setup(self, _table_overlay)
	_dealer_btn.build()
	_table_center = TableCenterScript.new().setup(self, _table_overlay)
	_table_center.build()
	_question_mgr = QuestionPanelManagerScript.new().setup(self)
	_question_mgr.build()
	_control_panel_manager = ControlPanelManagerScript.new().setup(self)
	_control_panel_manager.build(_on_back_to_menu_pressed)
	_connect_control_panel_signals()
	var seats := _seat_mgr.get_seats()
	_layout_editor = LayoutEditorScript.new().setup(self, _table_overlay, _control_panel_manager.layout_btn, _control_panel_manager.control_panel, _on_back_to_menu_pressed, {
		"avatars": seats.map(func(s: RefCounted) -> TextureRect: return s.avatar),
		"chairs": _chairs,
		"bet_labels": seats.map(func(s: RefCounted) -> Label: return s.bet_label),
		"stack_labels": seats.map(func(s: RefCounted) -> Label: return s.stack_label),
		"dealer_button": _dealer_btn.get_button(),
		"pot_display": _table_center.pot_display,
		"street_badge": _table_center.street_badge,
		"community_cards_container": _table_center.community_cards_container,
		"purple_stacks": seats.map(func(s: RefCounted) -> Node2D: return s.purple_stack),
		"black_stacks": seats.map(func(s: RefCounted) -> Node2D: return s.black_stack),
		"green_stacks": seats.map(func(s: RefCounted) -> Node2D: return s.green_stack),
		"red_stacks_1": seats.map(func(s: RefCounted) -> Node2D: return s.red_stack_1),
		"red_stacks_2": seats.map(func(s: RefCounted) -> Node2D: return s.red_stack_2),
		"red_stacks_3": seats.map(func(s: RefCounted) -> Node2D: return s.red_stack_3),
		"white_stacks": seats.map(func(s: RefCounted) -> Node2D: return s.white_stack),
		"player_bet_chips": seats.map(func(s: RefCounted) -> Control: return s.bet_chips_container),
		"ordered_bet_chips": seats.map(func(s: RefCounted) -> Node2D: return s.ordered_bet_chips),
		"pot_chip_area": _chip_mgr.get_pot_chip_area(),
		"chip_record": _chip_mgr.get_chip_record(),
		"action_boxes": seats.map(func(s: RefCounted) -> Label: return s.action_box),
	})
	_layout_editor.build()
	_game_over_mgr = GameOverManagerScript.new().setup(self)
	_action_box_mgr = ActionBoxManagerScript.new().setup(self, seats)
	_ad_mgr = AdOverlayManagerScript.new().setup(self)
	_ad_mgr.build()
	_connect_signals()
	GameManager.load_layout_from_file()
	# Apply persisted display_mode to UI after layout load
	_on_display_mode_changed(GameManager.display_mode)
	_refresh_all()
	if GameManager.pending_layout_mode:
		GameManager.pending_layout_mode = false
		_layout_editor.toggle()


func _process(delta: float) -> void:
	_ad_mgr.process(delta)


func _build_table_overlay() -> void:
	_table_overlay = Control.new()
	_table_overlay.name = "TableOverlay"
	_table_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_table_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_table_overlay)


func _play_sfx(path: String) -> void:
	var main_node: Node = get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.play_sfx(path)


# =============================================================================
# SIGNAL CONNECTIONS
# =============================================================================

func _connect_control_panel_signals() -> void:
	_control_panel_manager.start_pressed.connect(_on_start_pressed)
	_control_panel_manager.pause_pressed.connect(_on_pause_pressed)
	_control_panel_manager.reset_pressed.connect(_on_reset_pressed)
	_control_panel_manager.player_count_changed.connect(func(count: int) -> void:
		GameManager.set_player_count(count)
		_control_panel_manager.update_dealer_options()
	)
	_control_panel_manager.blinds_changed.connect(func(sb: int, bb: int) -> void:
		GameManager.set_blinds(sb, bb)
		GameManager.switch_layout_mode(GameManager.blinds_mode)
	)
	_control_panel_manager.preset_changed.connect(func(preset: int) -> void:
		GameManager.set_table_preset(preset)
	)
	_control_panel_manager.mode_changed.connect(func(mode: String) -> void:
		GameManager.set_training_mode(mode)
	)
	_control_panel_manager.display_mode_changed.connect(func(mode: String) -> void:
		GameManager.set_display_mode(mode)
	)
	_control_panel_manager.dealer_changed.connect(func(index: int) -> void:
		GameManager.set_dealer_index(index)
	)


func _connect_signals() -> void:
	GameManager.pot_changed.connect(_on_pot_changed)
	GameManager.street_changed.connect(_on_street_changed)
	GameManager.community_cards_changed.connect(_on_community_cards_changed)
	GameManager.current_player_changed.connect(_on_current_player_changed)
	GameManager.last_action_changed.connect(_on_last_action_changed)
	GameManager.dealer_moved.connect(_on_dealer_moved)
	GameManager.layout_changed.connect(_on_layout_changed)
	GameManager.game_reset.connect(_on_game_reset)
	GameManager.training_question_appeared.connect(_on_question_appeared)
	GameManager.training_question_cleared.connect(_on_question_cleared)
	GameManager.answer_result.connect(_on_answer_result)
	GameManager.game_over.connect(_on_game_over)
	GameManager.display_mode_changed.connect(_on_display_mode_changed)
	GameManager.hole_cards_changed.connect(_on_hole_cards_changed)
	GameManager.npc_acted.connect(_on_npc_acted)
	GameManager.show_ad_requested.connect(_on_show_ad_requested)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_pot_changed(_new_pot: int) -> void:
	_table_center.refresh_pot(_chip_mgr.get_pot_chip_area())
	_chip_mgr.refresh_chip_record()

func _on_street_changed(_new_street: String) -> void:
	_table_center.refresh_street()
	_seat_mgr.refresh_all()

func _on_community_cards_changed() -> void:
	_table_center.refresh_community_cards()

func _on_current_player_changed(_index: int) -> void:
	_seat_mgr.refresh_current_player()

func _on_last_action_changed(text: String) -> void:
	_table_center.set_last_action(text)

func _on_dealer_moved(_index: int) -> void:
	_dealer_btn.refresh()

func _on_layout_changed() -> void:
	# Skip heavy refresh during active drag — the drag handler already moves the node directly
	if _layout_editor.is_dragging:
		return
	_refresh_all()
	# Re-apply layout editor visibility after _refresh_all resets everything visible
	if GameManager.layout_mode:
		_layout_editor.apply_all_visibility()
	# Update seat positions and chip scales
	_seat_mgr.update_positions()
	# Update pot chip scale
	_chip_mgr.update_pot_chip_scale()
	# Re-enable drag and refresh preview after chip stacks are rebuilt
	# (fixes stale DragOverlay issue for both chips and preview elements like hole cards)
	if GameManager.layout_mode:
		_layout_editor.rebuild_drag_connections()

func _on_game_reset() -> void:
	_question_mgr.on_game_reset()
	_game_over_mgr.hide()
	_refresh_all()

func _on_question_appeared(question: Dictionary) -> void:
	_question_mgr.on_question_appeared(question)

func _on_question_cleared() -> void:
	_question_mgr.on_question_cleared()
	_seat_mgr.refresh_all()

func _on_answer_result(correct: bool, user_answer: int, expected: int) -> void:
	_question_mgr.on_answer_result(correct, user_answer, expected)

func _on_game_over() -> void:
	_seat_mgr.refresh_all()
	# In game mode, show a prominent overlay so the user knows the hand is done
	if GameManager.config.training_mode == "game":
		_game_over_mgr.show()

func _on_display_mode_changed(_mode: String) -> void:
	_seat_mgr.refresh_all()
	_table_center.refresh_pot(_chip_mgr.get_pot_chip_area())
	_chip_mgr.refresh_chip_record()
	_control_panel_manager._update_display_mode_styles()

func _on_hole_cards_changed() -> void:
	_seat_mgr.refresh_all()

func _on_npc_acted(seat: int, _action: String, _amount: int) -> void:
	_seat_mgr.refresh_all()
	_seat_mgr.refresh_current_player()
	# In game mode, auto-hide the action box after 1 second
	if GameManager.config.training_mode == "game":
		var physical_seat: int = GameManager.get_physical_seat(seat)
		_action_box_mgr.auto_hide(physical_seat)

func _on_show_ad_requested() -> void:
	_ad_mgr.show_ad()


# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_start_pressed() -> void:
	_game_over_mgr.hide()
	_control_panel_manager.collapse_config()
	GameManager.start_game()

func _on_pause_pressed() -> void:
	GameManager.pause_game()

func _on_reset_pressed() -> void:
	GameManager.reset_game()
	GameManager.init_game()

func _on_back_to_menu_pressed() -> void:
	var main_node: Node = get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.play_sfx("res://assets/music/sounds_effect/button.ogg")
	# Ensure layout mode is fully exited before leaving
	if GameManager.layout_mode:
		_layout_editor.toggle()
	GameManager.reset_game()
	GameManager.change_state(GameManager.State.MENU)
	if main_node:
		main_node.switch_scene("res://scenes/main_menu/main_menu.tscn")



# =============================================================================
# REFRESH METHODS
# =============================================================================

func _refresh_all() -> void:
	_seat_mgr.refresh_all()
	_table_center.refresh_pot(_chip_mgr.get_pot_chip_area())
	_table_center.refresh_street()
	_dealer_btn.refresh()
	_table_center.refresh_community_cards()
	_seat_mgr.refresh_current_player()
	_chip_mgr.refresh_chip_record()
