extends Control


func _ready() -> void:
	$CenterContainer/VBoxContainer/ButtonRow/YesButton.pressed.connect(_on_yes_pressed)
	$CenterContainer/VBoxContainer/ButtonRow/NoButton.pressed.connect(_go_to_menu)
	$CenterContainer/VBoxContainer/ButtonRow/YesButton.grab_focus()


func _on_yes_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_go_to_menu()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
