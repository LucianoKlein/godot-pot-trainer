extends Control


func _on_play_button_pressed() -> void:
	GameManager.change_state(GameManager.State.PLAYING)
	get_tree().root.get_node("Main").switch_scene("res://scenes/game/game_table.tscn")
