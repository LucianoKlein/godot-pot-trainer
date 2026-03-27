class_name SeatManager
extends RefCounted
## SeatManager — 座位管理器
## 负责座位的创建、刷新和状态更新

var _parent: Control
var _table_overlay: Control
var _seats: Array = []  # Array of SeatUI
var _chairs: Array[TextureRect] = []


func setup(parent: Control, table_overlay: Control, chairs: Array[TextureRect]) -> RefCounted:
	_parent = parent
	_table_overlay = table_overlay
	_chairs = chairs
	return self


func build() -> void:
	const SeatUIScript := preload("res://scripts/game/components/seat_ui.gd")
	for i in range(9):
		var seat: RefCounted = SeatUIScript.new().setup(i, _table_overlay)
		seat.build()
		_seats.append(seat)


func get_seats() -> Array:
	return _seats


func refresh_all() -> void:
	var chair_scale: float = GameManager.layout_config.get("chair_scale", 1.0)
	var chair_rotations: Array = GameManager.layout_config.get("chair_rotation", [])
	var chair_size: Vector2 = TableLayout.DEFAULT_CHAIR_SIZE * chair_scale

	# Build a reverse map: physical_seat -> player_data
	var seat_to_player: Dictionary = {}
	for logical_i in range(GameManager.players.size()):
		var physical_seat: int = GameManager.get_physical_seat(logical_i)
		seat_to_player[physical_seat] = GameManager.players[logical_i]

	for i in range(9):
		var has_player: bool = seat_to_player.has(i)
		_chairs[i].visible = GameManager.layout_mode or has_player
		var chair_pos: Vector2 = GameManager.get_layout_position_px("chairs", i)
		_chairs[i].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_chairs[i].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_chairs[i].custom_minimum_size = chair_size
		_chairs[i].size = chair_size
		_chairs[i].position = chair_pos - chair_size * 0.5
		_chairs[i].pivot_offset = chair_size * 0.5
		_chairs[i].rotation_degrees = chair_rotations[i] if i < chair_rotations.size() else 0.0

		var player_data: RefCounted = null
		if has_player:
			player_data = seat_to_player[i]

		_seats[i].refresh(player_data, GameManager.layout_mode)


func refresh_current_player() -> void:
	var cp: int = GameManager.current_player_index
	# Build reverse map: physical_seat -> logical_index
	var seat_to_logical: Dictionary = {}
	for logical_i in range(GameManager.players.size()):
		var physical_seat: int = GameManager.get_physical_seat(logical_i)
		seat_to_logical[physical_seat] = logical_i

	for i in range(_seats.size()):
		if not seat_to_logical.has(i):
			# No player at this seat — disable highlight
			_seats[i].set_current_player(false, false)
			continue
		var logical_i: int = seat_to_logical[i]
		var is_folded: bool = GameManager.players[logical_i].folded
		_seats[i].set_current_player(logical_i == cp, is_folded)


func update_positions() -> void:
	for seat in _seats:
		seat.update_position()
		seat.update_chip_scale()
