extends Node

const CRYTTER := 0
const STUNNER := 1
const BRUTE := 2

const CRYTTER_SCENE := preload("res://scenes/enemies/crytter.tscn")
const STUNNER_SCENE := preload("res://scenes/enemies/raider_stunner.tscn")
const BRUTE_SCENE := preload("res://scenes/enemies/brute.tscn")
const DEFAULT_COLLECTION := preload("res://scripts/resources/level_enemies_config_collection_default.tres")

@export var collection: LevelEnemiesConfigCollection = DEFAULT_COLLECTION

var _rng := RandomNumberGenerator.new()
var _prepared_level_index := -1
var _enemy_order: Array[int] = []


func _ready() -> void:
	_rng.randomize()


func prepare_for_level(level_index: int) -> void:
	_prepared_level_index = level_index
	_enemy_order.clear()

	var config := get_level_config(level_index)
	if config == null:
		return

	for i in max(config.crytter_amount, 0):
		_enemy_order.append(CRYTTER)
	for i in max(config.stunner_amount, 0):
		_enemy_order.append(STUNNER)
	for i in max(config.brute_amount, 0):
		_enemy_order.append(BRUTE)

	_shuffle_enemy_order()


func prepare_for_current_level() -> void:
	prepare_for_level(_get_current_level_index())


func get_current_level_config() -> LevelEnemiesConfig:
	return get_level_config(_get_current_level_index())


func get_level_config(level_index: int) -> LevelEnemiesConfig:
	if collection == null or collection.levels.is_empty():
		return null
	if level_index < 0 or level_index >= collection.levels.size():
		return null
	return collection.levels[level_index]


func get_spawn_interval() -> float:
	var config := get_current_level_config()
	if config == null:
		return 1.0
	return maxf(config.spawn_interval, 0.01)


func get_spawn_batch() -> int:
	var config := get_current_level_config()
	if config == null:
		return 1
	return maxi(config.spawn_batch, 1)


func take_next_enemy_types() -> Array[int]:
	if _prepared_level_index != _get_current_level_index():
		prepare_for_current_level()

	var batch: Array[int] = []
	var amount := mini(get_spawn_batch(), _enemy_order.size())
	for i in amount:
		batch.append(_enemy_order.pop_front())
	return batch


func ensure_next_enemy_type(enemy_type: int) -> bool:
	if _prepared_level_index != _get_current_level_index():
		prepare_for_current_level()
	if _enemy_order.is_empty():
		return false
	if _enemy_order[0] == enemy_type:
		return true

	var enemy_index := _enemy_order.find(enemy_type)
	if enemy_index == -1:
		return false

	var previous_first := _enemy_order[0]
	_enemy_order[0] = _enemy_order[enemy_index]
	_enemy_order[enemy_index] = previous_first
	return true


func get_enemy_scene(enemy_type: int) -> PackedScene:
	match enemy_type:
		CRYTTER:
			return CRYTTER_SCENE
		STUNNER:
			return STUNNER_SCENE
		BRUTE:
			return BRUTE_SCENE
		_:
			return null


func has_enemies_left() -> bool:
	return not _enemy_order.is_empty()


func _shuffle_enemy_order() -> void:
	for i in range(_enemy_order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := _enemy_order[i]
		_enemy_order[i] = _enemy_order[j]
		_enemy_order[j] = temp


func _get_current_level_index() -> int:
	var level_state := get_node_or_null("/root/LevelState")
	if level_state != null:
		return level_state.current_level_index
	return 0
