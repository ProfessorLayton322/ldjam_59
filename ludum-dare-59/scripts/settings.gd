extends Control


func _ready() -> void:
	$VBoxContainer/FullHDButton.pressed.connect(_on_fullhd_pressed)
	$VBoxContainer/FourKButton.pressed.connect(_on_4k_pressed)
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	_update_buttons()
	ResolutionManager.resolution_changed.connect(_on_resolution_changed)


func _on_fullhd_pressed() -> void:
	ResolutionManager.set_resolution(ResolutionManager.Resolution.FULL_HD)


func _on_4k_pressed() -> void:
	ResolutionManager.set_resolution(ResolutionManager.Resolution.FOUR_K)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _on_resolution_changed(_res: ResolutionManager.Resolution) -> void:
	_update_buttons()


func _update_buttons() -> void:
	var is_4k := ResolutionManager.current == ResolutionManager.Resolution.FOUR_K
	$VBoxContainer/FullHDButton.disabled = !is_4k
	$VBoxContainer/FourKButton.disabled = is_4k
