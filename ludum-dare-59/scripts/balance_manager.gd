extends Node

const DEFAULT_PARAMS_PATH := "res://balance_params.tres"

var params: BalanceParams


func _ready() -> void:
	reload()


func reload(path := DEFAULT_PARAMS_PATH) -> void:
	var loaded := load(path) as BalanceParams
	if loaded == null:
		push_error("BalanceManager: could not load BalanceParams from %s." % path)
		params = BalanceParams.new()
		return

	params = loaded.duplicate(true) as BalanceParams
	_copy_nested_resources()


func get_params() -> BalanceParams:
	_ensure_params()
	return params


func get_enemy_params(id: String) -> EnemyParams:
	_ensure_params()
	return params.get_enemy_params(id)


func get_gate_definitions() -> Array[GateDefinition]:
	_ensure_params()
	return params.gate_definitions


func get_gate_definition(id: String) -> GateDefinition:
	_ensure_params()
	return params.get_gate_definition(id)


func _ensure_params() -> void:
	if params == null:
		reload()


func _copy_nested_resources() -> void:
	for i in params.gate_definitions.size():
		var definition := params.gate_definitions[i]
		if definition != null:
			params.gate_definitions[i] = definition.duplicate(true) as GateDefinition

	for i in params.enemy_params.size():
		var enemy := params.enemy_params[i]
		if enemy != null:
			params.enemy_params[i] = enemy.duplicate(true) as EnemyParams

	if params.default_spawner_cfg != null:
		params.default_spawner_cfg = params.default_spawner_cfg.duplicate(true) as SpawnerCfg
