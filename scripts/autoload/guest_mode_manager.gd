extends Node

## GuestModeManager — 游客模式管理器
## 负责未订阅用户的答题计数和广告触发，进度持久化

signal guest_progress_changed()
signal guest_ad_required()

const GUEST_QUESTIONS_PER_AD := 3
const GUEST_PROGRESS_PATH := "user://guest_progress.json"

var guest_questions_answered: int = 0
var guest_ads_watched: int = 0


func _ready() -> void:
	_load_guest_progress()


func _load_guest_progress() -> void:
	if not FileAccess.file_exists(GUEST_PROGRESS_PATH):
		_reset_guest_progress()
		return
	var f := FileAccess.open(GUEST_PROGRESS_PATH, FileAccess.READ)
	if f == null:
		_reset_guest_progress()
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary:
		_reset_guest_progress()
		return
	guest_questions_answered = int(data.get("questions_answered", 0))
	guest_ads_watched = int(data.get("ads_watched", 0))


func _save_guest_progress() -> void:
	var f := FileAccess.open(GUEST_PROGRESS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"questions_answered": guest_questions_answered,
		"ads_watched": guest_ads_watched,
	}))
	f.close()


func _reset_guest_progress() -> void:
	guest_questions_answered = 0
	guest_ads_watched = 0
	_save_guest_progress()


func increment_guest_question() -> void:
	"""Called after each question submission for non-subscribed users"""
	if is_subscribed():
		return
	guest_questions_answered += 1
	_save_guest_progress()
	guest_progress_changed.emit()
	if guest_questions_answered >= GUEST_QUESTIONS_PER_AD:
		guest_questions_answered = 0
		_save_guest_progress()
		guest_ad_required.emit()


func on_guest_ad_watched() -> void:
	"""Called after user watches a rewarded ad"""
	guest_ads_watched += 1
	guest_questions_answered = 0
	_save_guest_progress()
	guest_progress_changed.emit()


func is_subscribed() -> bool:
	"""Check if user has active subscription (no ads needed)"""
	if not FirebaseAuth.is_logged_in:
		return false
	if FirebaseAuth.has_pot_trainer():
		return true
	return false
