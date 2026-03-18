extends Control
## ChipRecord — 筹码算盘组件
## 用算盘形式（黑色=5，绿色=1）显示底池金额
## 四列：万位、千位、百位、低位(amount%100/25)

const Chip := preload("res://scripts/game/components/chip.gd")

var _title_label: Label
var _beam: ColorRect
var _top_row: HBoxContainer    # 上半区（黑色筹码）
var _bottom_row: HBoxContainer # 下半区（绿色筹码）
var _top_cols: Array[Control] = []  # 4 digit columns (top)
var _bottom_cols: Array[Control] = []  # 4 digit columns (bottom)

var _current_amount: int = -1  # -1 forces first rebuild
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
	# Rebuild chips if amount was set before _ready
	if _current_amount >= 0:
		_rebuild_chips()


func _build_ui() -> void:
	# Background panel
	var bg := Panel.new()
	bg.name = "BG"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	sb.border_color = Color(1.0, 0.84, 0.0, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(0)
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = Locale.tr_key("chip_record_label")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_title_label.custom_minimum_size.y = 20
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	# Top row (black chips = 5)
	_top_row = HBoxContainer.new()
	_top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_row.add_theme_constant_override("separation", 6)
	_top_row.custom_minimum_size.y = 28
	_top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_top_row)

	_build_digit_cols(_top_row, _top_cols)

	# Beam (gold separator)
	_beam = ColorRect.new()
	_beam.color = Color(1.0, 0.84, 0.0, 0.5)
	_beam.custom_minimum_size = Vector2(0, 2)
	_beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_beam)

	# Bottom row (green chips = 1)
	_bottom_row = HBoxContainer.new()
	_bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom_row.add_theme_constant_override("separation", 6)
	_bottom_row.custom_minimum_size.y = 68
	_bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_bottom_row)

	_build_digit_cols(_bottom_row, _bottom_cols)


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
	# Clear all columns
	for col in _top_cols:
		for child in col.get_children():
			child.queue_free()
	for col in _bottom_cols:
		for child in col.get_children():
			child.queue_free()

	var amount: int = _current_amount
	var wan: int = (amount / 10000) % 10
	var qian: int = (amount / 1000) % 10
	var bai: int = (amount / 100) % 10
	var low: int = (amount % 100) / 25

	var digits: Array = [wan, qian, bai, 0]  # top/bottom for first 3 cols, col 4 is low-only

	# Place chips for each digit column
	for i in range(4):
		var blacks := 0
		var greens := 0
		if i < 3:
			var d: int = digits[i]
			if d == 0:
				pass
			elif d <= 4:
				greens = d
			elif d == 5:
				blacks = 1
			else:
				blacks = 1
				greens = d - 5
		else:
			# Low column: only greens
			greens = low

		# Top column: black chips
		for j in range(blacks):
			var chip := TextureRect.new()
			chip.set_script(Chip)
			chip.chip_color = Chip.ChipColor.BLACK100
			chip.chip_angle = _pseudo_angle(i * 11 + j)
			chip.chip_size = _chip_size
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_top_cols[i].add_child(chip)

		# Bottom column: green chips
		for j in range(greens):
			var chip := TextureRect.new()
			chip.set_script(Chip)
			chip.chip_color = Chip.ChipColor.GREEN25
			chip.chip_angle = _pseudo_angle(i * 13 + j + 50)
			chip.chip_size = _chip_size
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bottom_cols[i].add_child(chip)


func _pseudo_angle(seed_val: int) -> int:
	# Deterministic pseudo-random angle from seed
	var x := sin(seed_val * 127.1 + 311.7) * 43758.5453
	return int((x - floor(x)) * 4) % 4


func _apply_scale() -> void:
	custom_minimum_size = _base_size * scale_factor
	size = _base_size * scale_factor
	pivot_offset = size * 0.5


func get_display_size() -> Vector2:
	return _base_size * scale_factor
