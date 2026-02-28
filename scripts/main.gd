extends Node

@onready var current_scene: Node = $CurrentScene.get_child(0)


func switch_scene(scene_path: String) -> void:
	current_scene.queue_free()
	var next_scene: Node = load(scene_path).instantiate()
	$CurrentScene.add_child(next_scene)
	current_scene = next_scene
