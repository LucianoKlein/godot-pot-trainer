extends Node

## GuestModeManager — 游客模式管理器
## 负责未订阅用户的答题计数和广告触发，进度持久化

signal guest_progress_changed()
signal guest_ad_required()
signal gate_lock_changed(locked: bool)

const GUEST_QUESTIONS_PER_AD := 3
const GUEST_PROGRESS_PATH := "user://guest_progress.json"

var guest_questions_answered: int = 0
var guest_ads_watched: int = 0
var gate_locked: bool = false


func _ready() -> void:
	_load_guest_progress()
	FirebaseAuth.services_loaded.connect(_on_services_loaded)
	FirebaseAuth.logout_completed.connect(_on_logout_completed)


func _on_services_loaded() -> void:
	if is_subscribed() and gate_locked:
		unlock_gate()


func _on_logout_completed() -> void:
	lock_gate()


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
	gate_locked = bool(data.get("gate_locked", false))


func _save_guest_progress() -> void:
	var f := FileAccess.open(GUEST_PROGRESS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"questions_answered": guest_questions_answered,
		"ads_watched": guest_ads_watched,
		"gate_locked": gate_locked,
	}))
	f.close()


func _reset_guest_progress() -> void:
	guest_questions_answered = 0
	guest_ads_watched = 0
	gate_locked = false
	_save_guest_progress()


func increment_guest_question() -> void:
	if is_subscribed():
		return
	guest_questions_answered += 1
	_save_guest_progress()
	guest_progress_changed.emit()
	if guest_questions_answered >= GUEST_QUESTIONS_PER_AD:
		guest_questions_answered = 0
		lock_gate()
		guest_ad_required.emit()


func on_guest_ad_watched() -> void:
	guest_ads_watched += 1
	guest_questions_answered = 0
	unlock_gate()
	guest_progress_changed.emit()


func is_subscribed() -> bool:
	if not FirebaseAuth.is_logged_in:
		return false
	if FirebaseAuth.is_admin():
		return true
	if FirebaseAuth.is_legacy_user():
		return true
	if FirebaseAuth.has_pot_trainer():
		return true
	return false


func lock_gate() -> void:
	gate_locked = true
	_save_guest_progress()
	gate_lock_changed.emit(true)


func unlock_gate() -> void:
	gate_locked = false
	_save_guest_progress()
	gate_lock_changed.emit(false)


func is_gate_locked() -> bool:
	if is_subscribed():
		return false
	return gate_locked
