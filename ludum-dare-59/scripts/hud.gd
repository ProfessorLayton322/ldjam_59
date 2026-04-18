class_name Hud
extends CanvasLayer

var _game_over_panel: Panel


func _ready() -> void:
	_build_game_over_panel()


func show_game_over() -> void:
	_game_over_panel.visible = true


func _build_game_over_panel() -> void:
	_game_over_panel = Panel.new()
	_game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.visible = false
	add_child(_game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_game_over_panel.add_child(vbox)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var retry_btn := Button.new()
	retry_btn.text = "Retry"
	retry_btn.custom_minimum_size = Vector2(160, 40)
	retry_btn.pressed.connect(_on_retry_pressed)
	vbox.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(160, 40)
	menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(menu_btn)


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ld_gameplay.tscn")


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
