extends Control

func _on_play_pressed() -> void:
	GameState.has_state = false
	GameState.production_count = 3
	GameState.has_free_reset = true
	get_tree().change_scene_to_file("res://scenes/crafting.tscn")
