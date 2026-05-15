extends Node

## DialogQueue — 全局弹窗队列，保证同一时间只显示一个弹窗
## Autoload singleton — access via DialogQueue

var _current: Node = null
var _queue: Array[Callable] = []


## 请求显示弹窗。creator 是一个 Callable，执行后应创建弹窗并调用 register()。
func show(creator: Callable) -> void:
	if _current != null and is_instance_valid(_current):
		_queue.append(creator)
		return
	creator.call()


## 弹窗创建后调用，注册为当前弹窗。弹窗被 queue_free 时自动出队下一个。
func register(dialog_node: Node) -> void:
	if _current != null and is_instance_valid(_current) and _current != dialog_node:
		if _current.tree_exiting.is_connected(_on_dialog_closed):
			_current.tree_exiting.disconnect(_on_dialog_closed)
	_current = dialog_node
	dialog_node.tree_exiting.connect(_on_dialog_closed, CONNECT_ONE_SHOT)


func _on_dialog_closed() -> void:
	_current = null
	if _queue.is_empty():
		return
	var next := _queue.pop_front() as Callable
	await get_tree().process_frame
	if _current != null and is_instance_valid(_current):
		_queue.push_front(next)
		return
	next.call()
