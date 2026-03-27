extends Control
## ChipRecord — 筹码算盘组件
## 25/50 模式：万/千/百/低位(÷25)，上黑下绿，低位绿
## 5/10 模式：千/百/十/低位(÷5)，上绿下红，低位红
## 1/2 & 1/2/5 模式：百/十/个/low=0，上红下白，低位白

const Chip := preload("res://scripts/game/components/chip.gd")

var _title_label: Label
var _beam: ColorRect
var _top_row: HBoxContainer
var _bottom_row: HBoxContainer
var _top_cols: Array[Control] = []
var _bottom_cols: Array[Control] = []

var _current_amount: int = -1
var _chip_size: float = 28.0
var _base_size := Vector2(280, 180)

var scale_factor: float = 1.0:
	set(v):
		scale_factor = v
		if is_node_ready():
			_apply_scale()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_apply_scale()
	if _current_amount >= 0:
		_rebuild_chips()


func _build_ui() -> void:
	var bg := Panel.new()
	bg.name = "BG"
	bg.add_theme_stylebox_override("panel", UiFactory.make_stylebox(
		Color(0.0, 0.0, 0.0, 0.75), 8, 0, Color(1.0, 0.84, 0.0, 0.4), 1))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_title_label = UiFactory.make_label(Locale.tr_key("chip_record_label"), 22, Color(1, 1, 1, 0.5))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.custom_minimum_size.y = 20
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	_top_row = _make_chip_row(vbox, 28, BoxContainer.ALIGNMENT_END)
	_build_digit_cols(_top_row, _top_cols)

	_beam = ColorRect.new()
	_beam.color = Color(1.0, 0.84, 0.0, 0.5)
	_beam.custom_minimum_size = Vector2(0, 2)
	_beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_beam)

	_bottom_row = _make_chip_row(vbox, 68, BoxContainer.ALIGNMENT_BEGIN)
	_build_digit_cols(_bottom_row, _bottom_cols)


func _make_chip_row(parent: VBoxContainer, min_h: float, align: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = align
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size.y = min_h
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	return row


func _build_digit_cols(parent: HBoxContainer, cols: Array[Control]) -> void:
	for i in range(4):
		if i > 0:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(4, 0)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(sep)
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = _chip_size
		col.alignment = BoxContainer.ALIGNMENT_END if parent == _top_row else BoxContainer.ALIGNMENT_BEGIN
		col.add_theme_constant_override("separation", -18)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(col)
		cols.append(col)


func set_amount(amount: int) -> void:
	if amount == _current_amount:
		return
	_current_amount = amount
	if is_node_ready() and _top_cols.size() > 0:
		_rebuild_chips()


func _rebuild_chips() -> void:
	for col in _top_cols:
		for child in col.get_children():
			child.queue_free()
	for col in _bottom_cols:
		for child in col.get_children():
			child.queue_free()

	var amount: int = _current_amount
	var bm: String = GameManager.blinds_mode
	var is_12: bool = (bm == "1/2" or bm == "1/2/5")
	var is_small: bool = (bm == "5/10")

	# 位数分解
	var col1_digit: int
	var col2_digit: int
	var col3_digit: int
	var low: int

	if is_12:
		amount = ceili(float(amount) / 5.0) * 5
		col1_digit = (amount / 100) % 10
		col2_digit = (amount / 10) % 10
		col3_digit = (amount / 1) % 10
		low = 0
	elif is_small:
		col1_digit = (amount / 1000) % 10
		col2_digit = (amount / 100) % 10
		col3_digit = (amount / 10) % 10
		low = (amount % 10) / 5
	else:
		col1_digit = (amount / 10000) % 10
		col2_digit = (amount / 1000) % 10
		col3_digit = (amount / 100) % 10
		low = (amount % 100) / 25

	# 筹码颜色
	var top_color: int
	var bottom_color: int
	var low_color: int
	if is_12:
		top_color = Chip.ChipColor.RED5
		bottom_color = Chip.ChipColor.WHITE1
		low_color = Chip.ChipColor.WHITE1
	elif is_small:
		top_color = Chip.ChipColor.GREEN25
		bottom_color = Chip.ChipColor.RED5
		low_color = Chip.ChipColor.RED5
	else:
		top_color = Chip.ChipColor.BLACK100
		bottom_color = Chip.ChipColor.GREEN25
		low_color = Chip.ChipColor.GREEN25

	var digits: Array = [col1_digit, col2_digit, col3_digit, 0]

	for i in range(4):
		var tops := 0
		var bottoms := 0
		if i < 3:
			var d: int = digits[i]
			if d <= 4:
				bottoms = d
			elif d == 5:
				tops = 1
			else:
				tops = 1
				bottoms = d - 5
		else:
			bottoms = low

		for j in range(tops):
			_top_cols[i].add_child(ChipRenderUtils.create_chip_raw(
				top_color, ChipRenderUtils.pseudo_angle(i * 11 + j), _chip_size))

		var col_color: int = low_color if i == 3 else bottom_color
		for j in range(bottoms):
			_bottom_cols[i].add_child(ChipRenderUtils.create_chip_raw(
				col_color, ChipRenderUtils.pseudo_angle(i * 13 + j + 50), _chip_size))


func _apply_scale() -> void:
	custom_minimum_size = _base_size * scale_factor
	size = _base_size * scale_factor
	pivot_offset = size * 0.5


func get_display_size() -> Vector2:
	return _base_size * scale_factor
