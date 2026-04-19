class_name SpawnerTile
extends BaseTile

const DebugTrace := preload("res://scripts/debug_trace.gd")

@export var graph: Graph:
	set(value):
		graph = value
		_update_sprite_rotation()
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


func _update_sprite_rotation() -> void:
	if not is_inside_tree():
		return
	var sprite := get_node_or_null("StartSprite") as Sprite2D
	if sprite == null or graph == null:
		return

	if spawn_parent is Node2D:
		var my_pos := (spawn_parent as Node2D).to_local(global_position)
		var best_vertex: GraphVertex
		var best_dist := INF
		for v: GraphVertex in graph.nodes:
			var d := my_pos.distance_to(v.position)
			if d < best_dist:
				best_dist = d
				best_vertex = v
		if best_vertex != null and best_dist > 0.5:
			var dir := (best_vertex.position - my_pos).normalized()
			sprite.rotation = dir.angle() - PI / 2.0
			return

	if node_id == -1:
		return
	var vertex := graph.get_node_by_id(node_id)
	if vertex == null or vertex.neighbour_ids.is_empty():
		return
	var neighbor := graph.get_node_by_id(vertex.neighbour_ids[0])
	if neighbor == null:
		return
	var dir := (neighbor.position - vertex.position).normalized()
	sprite.rotation = dir.angle() - PI / 2.0


func _find_node_index() -> int:
	for i in graph.nodes.size():
		if graph.nodes[i].id == node_id:
			DebugTrace.event("spawn", "find_node_index:found", {"spawner": DebugTrace.node_state(self), "node_id": node_id, "node_index": i})
			return i
	DebugTrace.event("spawn", "find_node_index:miss", {"spawner": DebugTrace.node_state(self), "node_id": node_id})
	return -1
