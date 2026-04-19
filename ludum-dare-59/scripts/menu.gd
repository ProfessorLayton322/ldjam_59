extends Control


func _ready() -> void:
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)


func _on_start_pressed() -> void:
	AudioManager.play_ui_interaction()
	LevelState.start_from_first_level()
	get_tree().change_scene_to_file("res://scenes/ld_gameplay.tscn")


func _on_settings_pressed() -> void:
	AudioManager.play_ui_interaction()
	get_tree().change_scene_to_file("res://scenes/settings.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
