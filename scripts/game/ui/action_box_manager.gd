class_name ActionBoxManager
extends RefCounted
## ActionBoxManager — 游戏模式动作标签自动隐藏

var _parent: Control
var _seats: Array  # Array[SeatUI]
var _tweens: Dictionary = {}  # physical_seat -> Tween


func setup(parent: Control, seats: Array) -> RefCounted:
	_parent = parent
	_seats = seats
	return self


func auto_hide(physical_seat: int) -> void:
	if physical_seat < 0 or physical_seat >= _seats.size():
		return
	if _tweens.has(physical_seat):
		var old_tw: Tween = _tweens[physical_seat]
		if old_tw and old_tw.is_valid():
			old_tw.kill()
	var ab: Label = _seats[physical_seat].action_box
	ab.visible = true
	ab.modulate.a = 1.0
	var tw := _parent.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(ab, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		ab.visible = false
		ab.modulate.a = 1.0
	)
	_tweens[physical_seat] = tw
