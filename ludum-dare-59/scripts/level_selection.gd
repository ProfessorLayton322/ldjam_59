extends Control

const LEVELS: Array[LevelDefinition] = [
	preload("res://scripts/resources/levels/demo_level.tres"),
	preload("res://scripts/resources/levels/level_02.tres"),
]

@onready var _level_list: VBoxContainer = $VBoxContainer/LevelList
@onready var _back_button: Button = $VBoxContainer/BackButton


func _ready() -> void:
	for level in LEVELS:
		var button := Button.new()
		button.text = level.title
		button.custom_minimum_size = Vector2(220.0, 44.0)
		button.pressed.connect(_on_level_pressed.bind(level))
		_level_list.add_child(button)

	_back_button.pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _on_level_pressed(level: LevelDefinition) -> void:
	LevelState.selected_level = level
	get_tree().change_scene_to_file("res://scenes/demo.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
