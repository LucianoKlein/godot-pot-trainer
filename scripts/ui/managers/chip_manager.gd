class_name ChipManager
extends RefCounted
## ChipManager — 筹码管理器
## 负责底池筹码区域和筹码记录（算盘）的创建和刷新

var _parent: Control
var _table_overlay: Control
var _pot_chip_area: Control
var _chip_record: Control


func setup(parent: Control, table_overlay: Control) -> RefCounted:
	_parent = parent
	_table_overlay = table_overlay
	return self


func build() -> void:
	_build_pot_chip_area()
	_build_chip_record()


func _build_pot_chip_area() -> void:
	const PotChipArea := preload("res://scripts/game/components/pot_chip_area.gd")
	_pot_chip_area = Control.new()
	_pot_chip_area.set_script(PotChipArea)
	_pot_chip_area.name = "PotChipArea"
	_pot_chip_area.z_index = 8
	var pot_pos: Vector2 = GameManager.get_layout_position_px("pot")
	_pot_chip_area.position = pot_pos - Vector2(80, 60)
	_pot_chip_area.area_width = 160.0
	_pot_chip_area.area_height = 120.0
	_pot_chip_area.chip_scale = GameManager.layout_config.get("pot_chip_scale", 1.0)
	_pot_chip_area.is_editing = false
	_table_overlay.add_child(_pot_chip_area)


func _build_chip_record() -> void:
	const ChipRecord := preload("res://scripts/game/components/chip_record.gd")
	_chip_record = Control.new()
	_chip_record.set_script(ChipRecord)
	_chip_record.name = "ChipRecord"
	_chip_record.z_index = 9
	var cr_pos: Vector2 = GameManager.get_layout_position_px("chip_record")
	var cr_scale: float = GameManager.layout_config.get("chip_record_scale", 1.0)
	_chip_record.scale_factor = cr_scale
	var cr_size: Vector2 = _chip_record.get_display_size()
	_chip_record.position = cr_pos - cr_size * 0.5
	# Hidden by default in numbers mode
	_chip_record.visible = GameManager.display_mode == "chips" or GameManager.layout_mode
	_table_overlay.add_child(_chip_record)


func get_pot_chip_area() -> Control:
	return _pot_chip_area


func get_chip_record() -> Control:
	return _chip_record


func refresh_chip_record() -> void:
	if not _chip_record or not is_instance_valid(_chip_record):
		return
	# Only show pot_total (settled rounds + folded players' contributions)
	var total: int = GameManager.engine.pot_total
	_chip_record.set_amount(total)
	# Update position
	var cr_pos: Vector2 = GameManager.get_layout_position_px("chip_record")
	var cr_scale: float = GameManager.layout_config.get("chip_record_scale", 1.0)
	_chip_record.scale_factor = cr_scale
	var cr_size: Vector2 = _chip_record.get_display_size()
	_chip_record.position = cr_pos - cr_size * 0.5
	# Visibility: chips mode or layout mode
	if not GameManager.layout_mode:
		_chip_record.visible = GameManager.display_mode == "chips"


func update_pot_chip_scale() -> void:
	if _pot_chip_area and is_instance_valid(_pot_chip_area):
		_pot_chip_area.chip_scale = GameManager.layout_config.get("pot_chip_scale", 1.0)
		_pot_chip_area._rebuild()
