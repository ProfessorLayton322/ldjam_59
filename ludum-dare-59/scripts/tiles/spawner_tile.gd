class_name SpawnerTile
extends BaseTile

const DebugTrace := preload("res://scripts/debug_trace.gd")

@export var graph: Graph
@export var cpu_vertices: Array[CpuVertex] = []
@export var enemy_scene: PackedScene

var spawn_parent: Node
var last_spawned_enemy: Enemy


func OnTrigger(source: Node = null) -> void:
	super.OnTrigger(source)

	DebugTrace.event("spawn", "spawner_trigger:start", {
		"spawner": DebugTrace.node_state(self),
		"source": DebugTrace.node_state(source),
		"node_id": node_id,
		"graph_id": graph.get_instance_id() if graph != null else 0,
		"enemy_scene": enemy_scene.resource_path if enemy_scene != null else "",
	})
	last_spawned_enemy = null
	if graph == null or enemy_scene == null:
		DebugTrace.event("spawn", "spawner_trigger:missing_graph_or_scene", {"spawner": DebugTrace.node_state(self)})
		return

	var node_index := _find_node_index()
	if node_index == -1:
		DebugTrace.event("spawn", "spawner_trigger:missing_node_index", {"spawner": DebugTrace.node_state(self), "node_id": node_id})
		return

	var enemy: Enemy = enemy_scene.instantiate()
	enemy.graph = graph
	enemy.cpu_vertices = cpu_vertices
	enemy.current_node_index = node_index
	enemy.position = graph.nodes[node_index].position
	var parent := spawn_parent if spawn_parent != null else get_parent()
	parent.add_child(enemy)
	last_spawned_enemy = enemy
	DebugTrace.event("spawn", "spawner_trigger:spawned", {
		"spawner": DebugTrace.node_state(self),
		"enemy": DebugTrace.enemy_state(enemy),
		"parent": DebugTrace.node_state(parent),
		"node_index": node_index,
		"node_id": node_id,
	})


func OnEnter(source: Node = null) -> void:
	super.OnEnter(source)


func _find_node_index() -> int:
	for i in graph.nodes.size():
		if graph.nodes[i].id == node_id:
			DebugTrace.event("spawn", "find_node_index:found", {"spawner": DebugTrace.node_state(self), "node_id": node_id, "node_index": i})
			return i
	DebugTrace.event("spawn", "find_node_index:miss", {"spawner": DebugTrace.node_state(self), "node_id": node_id})
	return -1
