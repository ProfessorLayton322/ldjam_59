class_name SpawnerTile
extends BaseTile

@export var graph: Graph
@export var cpu_vertices: Array[CpuVertex] = []
@export var enemy_scene: PackedScene

var spawn_parent: Node


func OnTrigger(source: Node = null) -> void:
	super.OnTrigger(source)

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
	var parent := spawn_parent if spawn_parent != null else get_parent()
	parent.add_child(enemy)


func OnEnter(source: Node = null) -> void:
	super.OnEnter(source)


func _find_node_index() -> int:
	for i in graph.nodes.size():
		if graph.nodes[i].id == node_id:
			return i
	return -1
