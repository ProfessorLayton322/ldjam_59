extends Control


func _ready() -> void:
	$VBoxContainer/FullHDButton.pressed.connect(_on_fullhd_pressed)
	$VBoxContainer/FourKButton.pressed.connect(_on_4k_pressed)
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)


func _on_fullhd_pressed() -> void:
	pass


func _on_4k_pressed() -> void:
	pass


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
