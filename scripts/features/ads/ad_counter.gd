class_name AdCounter
extends RefCounted
## AdCounter — 游客模式广告计数器
## 跟踪游客答对题目的次数，每 3 题触发一次广告

signal ad_requested()

var _count: int = 0
var _threshold: int = 3


func increment() -> void:
	_count += 1
	if _count >= _threshold:
		ad_requested.emit()
		reset()


func reset() -> void:
	_count = 0


func get_count() -> int:
	return _count


func set_threshold(value: int) -> void:
	_threshold = maxi(1, value)


func get_threshold() -> int:
	return _threshold
