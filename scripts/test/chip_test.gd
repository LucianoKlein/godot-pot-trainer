extends Control

const PotChipArea = preload("res://scripts/game/components/pot_chip_area.gd")
const OrderedChipStacks = preload("res://scripts/game/components/ordered_chip_stacks.gd")
const ScatteredChips = preload("res://scripts/game/components/scattered_chips.gd")

var _chip_display: Control
var _amount_input: LineEdit
var _update_btn: Button
var _test_pot_btn: Button
var _test_bet_btn: Button

var _current_display: Node = null


func _ready() -> void:
	_chip_display = $TestContainer/ChipDisplay
	_amount_input = $TestContainer/Controls/AmountInput
	_update_btn = $TestContainer/Controls/UpdateBtn
	_test_pot_btn = $TestContainer/Controls/TestPotBtn
	_test_bet_btn = $TestContainer/Controls/TestBetBtn

	_update_btn.pressed.connect(_on_update_pressed)
	_test_pot_btn.pressed.connect(_on_test_pot_pressed)
	_test_bet_btn.pressed.connect(_on_test_bet_pressed)

	# Default test
	_test_pot_with_amount(2500)


func _on_update_pressed() -> void:
	var text := _amount_input.text.strip_edges()
	if text.is_empty() or not text.is_valid_int():
		print("请输入有效金额")
		return

	var amount := text.to_int()
	_test_pot_with_amount(amount)


func _on_test_pot_pressed() -> void:
	_test_pot_with_amount(7500)


func _on_test_bet_pressed() -> void:
	_test_bet_with_amount(1200)


func _test_pot_with_amount(amount: int) -> void:
	_clear_display()

	var pot_area := Control.new()
	pot_area.set_script(PotChipArea)
	pot_area.name = "PotChipArea"
	pot_area.position = Vector2(100, 50)
	pot_area.area_width = 200.0
	pot_area.area_height = 150.0
	pot_area.chip_scale = 1.0
	pot_area.pot_total = amount

	_chip_display.add_child(pot_area)
	_current_display = pot_area

	print("底池筹码测试: %d" % amount)


func _test_bet_with_amount(amount: int) -> void:
	_clear_display()

	var chips := ChipUtils.amount_to_chips(amount)
	print("下注筹码测试: %d, 筹码数: %d" % [amount, chips.size()])

	if chips.size() < 5:
		var scattered := Node2D.new()
		scattered.set_script(ScatteredChips)
		scattered.name = "ScatteredChips"
		scattered.position = Vector2(150, 100)
		scattered.chip_size = 28.0
		scattered.seed_value = 42
		_chip_display.add_child(scattered)
		scattered.set_chips(chips)
		_current_display = scattered
	else:
		var ordered := Node2D.new()
		ordered.set_script(OrderedChipStacks)
		ordered.name = "OrderedChipStacks"
		ordered.position = Vector2(100, 50)
		ordered.chip_size = 28.0
		ordered.stack_gap_x = 5.0
		ordered.stack_gap_y = 5.0
		_chip_display.add_child(ordered)
		ordered.set_chips(chips)
		_current_display = ordered


func _clear_display() -> void:
	if _current_display:
		_current_display.queue_free()
		_current_display = null
