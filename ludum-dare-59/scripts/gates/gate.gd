class_name Gate
extends Node2D

signal destroyed(gate: Gate)

static var _gates_by_graph_vertex: Dictionary = {}

@export var definition: Resource:
	set(value):
		definition = value
		_current_hp = _get_max_hp()
		_update_icon()

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
var _current_hp := 1
var _stalled_enemies: Array[Enemy] = []
var _stalled_enemy_power := 0
var _is_destroying := false


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
	_current_hp = _get_max_hp()
	_update_icon()


func _enter_tree() -> void:
	_register_gate()


func _exit_tree() -> void:
	_unregister_gate()


func on_enter(enemy: Enemy) -> void:
	if definition == null or enemy == null:
		return

	if definition.blocks_movement:
		_stall_enemy(enemy)
		if not definition.indestructible and _stalled_enemy_power > _current_hp:
			_destroy_gate()
		return

	if definition.damage_power > 0:
		enemy.apply_damage(definition.damage_power)
		if enemy.is_queued_for_deletion():
			return

	if definition.slow_extra_seconds_per_tile > 0.0 and definition.slow_duration > 0.0:
		enemy.apply_slow(definition.slow_extra_seconds_per_tile, definition.slow_duration)


func blocks_movement() -> bool:
	return definition != null and definition.blocks_movement


func get_power_cost() -> int:
	if definition == null:
		return 0

	return definition.power_cost


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


func _stall_enemy(enemy: Enemy) -> void:
	if _stalled_enemies.has(enemy):
		return

	_stalled_enemies.append(enemy)
	_stalled_enemy_power += enemy.damage
	enemy.stall_at_gate(self)


func _destroy_gate() -> void:
	if _is_destroying:
		return

	_is_destroying = true
	_unregister_gate()
	_release_stalled_enemies()
	destroyed.emit(self)
	queue_free()


func _release_stalled_enemies() -> void:
	var enemies := _stalled_enemies.duplicate()
	_stalled_enemies.clear()
	_stalled_enemy_power = 0

	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue

		enemy.release_from_gate(self)


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


func _get_max_hp() -> int:
	if definition == null:
		return 1

	return definition.max_hp


func _update_icon() -> void:
	if not is_inside_tree():
		return

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

	if definition != null:
		sprite.texture = definition.texture
