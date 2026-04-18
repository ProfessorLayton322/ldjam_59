class_name Gate
extends Node2D

static var _gates_by_graph_vertex: Dictionary = {}

@export var graph: Graph:
	set(value):
		if graph == value:
			return

		_unregister_gate()
		graph = value
		_update_position_from_vertex()
		_register_gate()

@export var vertex_id: int = -1:
	set(value):
		if vertex_id == value:
			return

		_unregister_gate()
		vertex_id = value
		_update_position_from_vertex()
		_register_gate()

var _registry_key := ""


static func get_gate(target_graph: Graph, target_vertex_id: int) -> Gate:
	if target_graph == null:
		return null

	var key := _get_registry_key(target_graph, target_vertex_id)
	var gate: Gate = _gates_by_graph_vertex.get(key) as Gate
	if gate == null or not is_instance_valid(gate):
		_gates_by_graph_vertex.erase(key)
		return null

	return gate


func _ready() -> void:
	_update_position_from_vertex()


func _enter_tree() -> void:
	_register_gate()


func _exit_tree() -> void:
	_unregister_gate()


func on_enter(enemy: Enemy) -> void:
	print("ENEMY IN CONTACT")


func _register_gate() -> void:
	if not is_inside_tree() or graph == null or vertex_id < 0:
		return

	var key := _get_registry_key(graph, vertex_id)
	var existing: Gate = _gates_by_graph_vertex.get(key) as Gate
	if existing != null and is_instance_valid(existing) and existing != self:
		push_warning("Gate already exists at vertex id %d." % vertex_id)
		return

	_gates_by_graph_vertex[key] = self
	_registry_key = key


func _unregister_gate() -> void:
	if _registry_key.is_empty():
		return

	var existing: Gate = _gates_by_graph_vertex.get(_registry_key) as Gate
	if existing == self or existing == null or not is_instance_valid(existing):
		_gates_by_graph_vertex.erase(_registry_key)

	_registry_key = ""


func _update_position_from_vertex() -> void:
	if graph == null or vertex_id < 0:
		return

	var vertex := graph.get_node_by_id(vertex_id)
	if vertex == null:
		push_warning("Gate vertex id %d does not exist in graph." % vertex_id)
		return

	position = vertex.position


static func _get_registry_key(target_graph: Graph, target_vertex_id: int) -> String:
	return "%d:%d" % [target_graph.get_instance_id(), target_vertex_id]
