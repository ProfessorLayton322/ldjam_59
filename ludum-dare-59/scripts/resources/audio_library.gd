class_name AudioLibrary
extends Resource

@export_group("UI")
@export var pause_activated_sounds: Array[AudioStream] = []
@export var pause_deactivated_sounds: Array[AudioStream] = []
@export var ui_interaction_sounds: Array[AudioStream] = []

@export_group("Gates")
@export var barricade_gate_spawn_sounds: Array[AudioStream] = []
@export var barricade_gate_activation_sounds: Array[AudioStream] = []
@export var ballista_gate_spawn_sounds: Array[AudioStream] = []
@export var ballista_gate_activation_sounds: Array[AudioStream] = []
@export var tar_gate_spawn_sounds: Array[AudioStream] = []
@export var tar_gate_activation_sounds: Array[AudioStream] = []
@export var divider_gate_spawn_sounds: Array[AudioStream] = []
@export var divider_gate_activation_sounds: Array[AudioStream] = []

@export_group("Enemies")
@export var crytter_spawn_sounds: Array[AudioStream] = []
@export var crytter_damage_sounds: Array[AudioStream] = []
@export var crytter_death_sounds: Array[AudioStream] = []
@export var raider_stunner_spawn_sounds: Array[AudioStream] = []
@export var raider_stunner_damage_sounds: Array[AudioStream] = []
@export var raider_stunner_death_sounds: Array[AudioStream] = []
@export var brute_spawn_sounds: Array[AudioStream] = []
@export var brute_damage_sounds: Array[AudioStream] = []
@export var brute_death_sounds: Array[AudioStream] = []

@export_group("CPU")
@export var cpu_damage_sounds: Array[AudioStream] = []
@export var cpu_death_sounds: Array[AudioStream] = []

@export_group("Gate Placement")
@export var not_enough_temperature_sounds: Array[AudioStream] = []
@export var invalid_gate_tile_sounds: Array[AudioStream] = []
@export var invalid_gate_move_sounds: Array[AudioStream] = []
@export var gate_deleted_sounds: Array[AudioStream] = []

@export_group("Level")
@export var level_beginning_sounds: Array[AudioStream] = []
@export var level_victory_sounds: Array[AudioStream] = []
@export var background_music: Array[AudioStream] = []


func get_gate_spawn_sounds(gate_id: String) -> Array[AudioStream]:
	match gate_id:
		"barricade":
			return barricade_gate_spawn_sounds
		"ballista":
			return ballista_gate_spawn_sounds
		"tar":
			return tar_gate_spawn_sounds
		"divider":
			return divider_gate_spawn_sounds
		_:
			return []


func get_gate_activation_sounds(gate_id: String) -> Array[AudioStream]:
	match gate_id:
		"barricade":
			return barricade_gate_activation_sounds
		"ballista":
			return ballista_gate_activation_sounds
		"tar":
			return tar_gate_activation_sounds
		"divider":
			return divider_gate_activation_sounds
		_:
			return []


func get_enemy_spawn_sounds(enemy_id: String) -> Array[AudioStream]:
	match enemy_id:
		"crytter":
			return crytter_spawn_sounds
		"raider_stunner":
			return raider_stunner_spawn_sounds
		"brute":
			return brute_spawn_sounds
		_:
			return []


func get_enemy_damage_sounds(enemy_id: String) -> Array[AudioStream]:
	match enemy_id:
		"crytter":
			return crytter_damage_sounds
		"raider_stunner":
			return raider_stunner_damage_sounds
		"brute":
			return brute_damage_sounds
		_:
			return []


func get_enemy_death_sounds(enemy_id: String) -> Array[AudioStream]:
	match enemy_id:
		"crytter":
			return crytter_death_sounds
		"raider_stunner":
			return raider_stunner_death_sounds
		"brute":
			return brute_death_sounds
		_:
			return []
