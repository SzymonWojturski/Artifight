extends CanvasLayer

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		_on_resume_pressed()
	elif _can_pause():
		_open()

func _can_pause() -> bool:
	var lu := get_node_or_null("/root/game/HUD/LevelUpMenu")
	return lu == null or not lu.visible

func _open() -> void:
	visible = true
	get_tree().paused = true

func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false

func _on_exit_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameState.has_state = false
	GameState.production_count = 3
	GameState.has_free_reset = true
	get_tree().change_scene_to_file("res://scenes/start.tscn")
