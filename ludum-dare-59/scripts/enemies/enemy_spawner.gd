class_name EnemySpawner
extends Node2D

@export var graph: Graph
@export var cpu_vertices: Array[CpuVertex] = []
@export var node_id: int = -1
@export var spawn_interval: float = 1.0
@export var enemy_scene: PackedScene


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_spawn_enemy)
	add_child(timer)


func _spawn_enemy() -> void:
	if graph == null or enemy_scene == null:
		return

	var node_index := _find_node_index()
	if node_index == -1:
		return

	var enemy: Enemy = enemy_scene.instantiate()
	enemy.graph = graph
	enemy.cpu_vertices = cpu_vertices
	enemy.current_node_index = node_index
	enemy.position = graph.nodes[node_index].position
	get_parent().add_child(enemy)


func _find_node_index() -> int:
	for i in graph.nodes.size():
		if graph.nodes[i].id == node_id:
			return i
	return -1
