extends Control

var _focusables: Array[Control] = []
var _focus_idx: int = 0


func _ready() -> void:
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	_focusables = [
		$VBoxContainer/StartButton,
		$VBoxContainer/SettingsButton,
		$VBoxContainer/QuitButton,
	]
	_focus_idx = 0
	_focusables[0].grab_focus()


func _on_start_pressed() -> void:
	AudioManager.play_ui_interaction()
	LevelState.start_from_first_level()
	get_tree().change_scene_to_file("res://scenes/ld_gameplay.tscn")


func _on_settings_pressed() -> void:
	AudioManager.play_ui_interaction()
	get_tree().change_scene_to_file("res://scenes/settings.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q:
			get_tree().quit()
		KEY_W, KEY_UP:
			_focus_idx = (_focus_idx - 1 + _focusables.size()) % _focusables.size()
			_focusables[_focus_idx].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_S, KEY_DOWN:
			_focus_idx = (_focus_idx + 1) % _focusables.size()
			_focusables[_focus_idx].grab_focus()
			get_viewport().set_input_as_handled()
