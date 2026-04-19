class_name BalanceParams
extends Resource

@export_group("Game")
@export var max_temperature := 38
@export var cpu_hp := 20
@export var trigger_interval := 1.0
@export var gate_placement_radius := 32.0
@export var despawn_cooldown_timing := 3.0
@export var moving_penalty := 3.0
@export var moving_penalty_cooldown := 3.0

@export_group("Gates")
@export var gate_definitions: Array[GateDefinition] = []

@export_group("Enemies")
@export var enemy_params: Array[EnemyParams] = []
@export var default_spawner_cfg: SpawnerCfg


func get_enemy_params(id: String) -> EnemyParams:
	for params in enemy_params:
		if params != null and params.id == id:
			return params

	return null


func get_gate_definition(id: String) -> GateDefinition:
	for definition in gate_definitions:
		if definition != null and definition.id == id:
			return definition

	return null
