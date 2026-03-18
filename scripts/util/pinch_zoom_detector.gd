class_name PinchZoomDetector
extends RefCounted
## Pinch-to-Zoom Gesture Detector
## 检测双指缩放手势，用于移动端筹码大小调节

signal zoom_changed(zoom_factor: float)  # 相对缩放因子 (1.0 = 无变化)

var _touch_points: Dictionary = {}  # touch_index -> Vector2
var _initial_distance: float = 0.0
var _current_distance: float = 0.0
var _is_pinching: bool = false
var _min_distance_threshold: float = 50.0  # 最小距离阈值（像素）


func process_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return _handle_touch(event)
	elif event is InputEventScreenDrag:
		return _handle_drag(event)
	return false


func _handle_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		# 触摸开始
		_touch_points[event.index] = event.position

		# 如果有两个触摸点，开始捏合检测
		if _touch_points.size() == 2:
			_is_pinching = true
			_initial_distance = _calculate_distance()
			_current_distance = _initial_distance
			return true
	else:
		# 触摸结束
		_touch_points.erase(event.index)

		# 如果触摸点少于2个，停止捏合
		if _touch_points.size() < 2:
			_is_pinching = false
			_initial_distance = 0.0
			_current_distance = 0.0

	return false


func _handle_drag(event: InputEventScreenDrag) -> bool:
	if not _is_pinching:
		return false

	# 更新触摸点位置
	if _touch_points.has(event.index):
		_touch_points[event.index] = event.position

	# 计算新距离
	if _touch_points.size() == 2:
		var new_distance := _calculate_distance()

		# 只有距离变化超过阈值才触发
		if abs(new_distance - _current_distance) > 1.0:
			var zoom_factor := new_distance / _current_distance
			_current_distance = new_distance
			zoom_changed.emit(zoom_factor)
			return true

	return false


func _calculate_distance() -> float:
	if _touch_points.size() != 2:
		return 0.0

	var points: Array = _touch_points.values()
	var p1: Vector2 = points[0]
	var p2: Vector2 = points[1]
	return p1.distance_to(p2)


func is_pinching() -> bool:
	return _is_pinching


func reset() -> void:
	_touch_points.clear()
	_is_pinching = false
	_initial_distance = 0.0
	_current_distance = 0.0
