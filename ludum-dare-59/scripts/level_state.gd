extends Node

const LEVELS: Array[LevelDefinition] = [
	preload("res://scripts/resources/levels/level_01.tres"),
	preload("res://scripts/resources/levels/level_02.tres"),
	preload("res://scripts/resources/levels/level_03.tres"),
	preload("res://scripts/resources/levels/level_04.tres"),
]

var current_level_index := 0
var selected_level: LevelDefinition


func start_from_first_level() -> LevelDefinition:
	current_level_index = 0
	selected_level = get_current_level()
	return selected_level


func get_current_level() -> LevelDefinition:
	if LEVELS.is_empty():
		return null

	current_level_index = clampi(current_level_index, 0, LEVELS.size() - 1)
	return LEVELS[current_level_index]


func advance_to_next_level() -> bool:
	if current_level_index + 1 >= LEVELS.size():
		return false

	current_level_index += 1
	selected_level = get_current_level()
	return selected_level != null
