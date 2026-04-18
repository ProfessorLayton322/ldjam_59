class_name Enemy
extends Node2D

@export var graph: Graph
@export var cpu_vertices: Array[CpuVertex] = []
@export var current_node_index: int = -1
@export var move_duration: float = 3.0
@export var damage: int = 1
@export var hp: int = 10

var path: Array[int] = []

var _active_tween: Tween
var _node_id_to_index: Dictionary = {}
var _slow_extra_seconds_per_tile := 0.0
var _slow_until_msec := 0


func _ready() -> void:
	_ensure_icon()
	start_pathing()


func start_pathing() -> void:
	if _active_tween:
		_active_tween.kill()
		_active_tween = null

	if _has_valid_node_index(current_node_index):
		position = _get_node_position(current_node_index)

	path = _calculate_path(false)
	if path.is_empty():
		path = _calculate_path(true)
	if path.is_empty():
		return

	_move_to_next_node()


func _ensure_icon() -> void:
	var icon := get_node_or_null("Icon") as Sprite2D
	if icon == null:
		icon = Sprite2D.new()
		icon.name = "Icon"
		add_child(icon)

	icon.texture = load("res://assets/textures/enemies/circle_enemy.svg")


func _calculate_path(allow_blocking_gate_target: bool) -> Array[int]:
	_node_id_to_index = _build_node_id_to_index()

	if not _has_valid_node_index(current_node_index):
		return []

	var cpu_index_set := _build_cpu_index_set()
	if cpu_index_set.is_empty():
		return []

	var queue: Array[int] = [current_node_index]
	var visited := {
		current_node_index: true,
	}
	var came_from := {}

	while not queue.is_empty():
		var node_index: int = queue.pop_front()
		if cpu_index_set.has(node_index):
			return _reconstruct_path(came_from, node_index)

		var node := graph.nodes[node_index]
		for neighbour_id in node.neighbour_ids:
			if not _node_id_to_index.has(neighbour_id):
				continue

			var neighbour_index: int = _node_id_to_index[neighbour_id]
			if visited.has(neighbour_index):
				continue

			var blocking_gate := _get_blocking_gate_at_node_id(neighbour_id)
			if blocking_gate != null:
				if allow_blocking_gate_target:
					came_from[neighbour_index] = node_index
					return _reconstruct_path(came_from, neighbour_index)
				continue

			visited[neighbour_index] = true
			came_from[neighbour_index] = node_index
			queue.append(neighbour_index)

	return []


func _build_cpu_index_set() -> Dictionary:
	var result := {}
	for cpu in cpu_vertices:
		if cpu == null:
			continue
		if _node_id_to_index.has(cpu.node_id):
			result[_node_id_to_index[cpu.node_id]] = true
	return result


func _build_node_id_to_index() -> Dictionary:
	var result := {}
	if graph == null:
		return result

	for index in graph.nodes.size():
		result[graph.nodes[index].id] = index

	return result


func _reconstruct_path(came_from: Dictionary, target_index: int) -> Array[int]:
	var reversed_path: Array[int] = [target_index]
	var node_index := target_index

	while node_index != current_node_index:
		if not came_from.has(node_index):
			return []

		node_index = came_from[node_index]
		reversed_path.append(node_index)

	reversed_path.reverse()
	return reversed_path


func _move_to_next_node() -> void:
	if path.size() <= 1:
		queue_free()
		return

	var next_node_index := path[1]
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position", _get_node_position(next_node_index), _get_current_move_duration())
	_active_tween.finished.connect(_on_move_finished.bind(next_node_index), CONNECT_ONE_SHOT)


func _on_move_finished(reached_node_index: int) -> void:
	_active_tween = null
	current_node_index = reached_node_index
	_enter_current_node()
	if is_queued_for_deletion():
		return

	if not path.is_empty() and path[0] == reached_node_index:
		path.pop_front()
	elif path.size() > 1 and path[1] == reached_node_index:
		path.pop_front()

	_move_to_next_node()


func _get_node_position(node_index: int) -> Vector2:
	return graph.nodes[node_index].position


func _enter_current_node() -> void:
	if not _has_valid_node_index(current_node_index):
		return

	var node_id := graph.nodes[current_node_index].id
	var gate := Gate.get_gate(graph, node_id)
	if gate == null:
		return

	gate.on_enter(self)


func _has_valid_node_index(node_index: int) -> bool:
	return graph != null and node_index >= 0 and node_index < graph.nodes.size()


func apply_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()


func apply_slow(extra_seconds_per_tile: float, duration: float) -> void:
	_slow_extra_seconds_per_tile = maxf(_slow_extra_seconds_per_tile, extra_seconds_per_tile)
	_slow_until_msec = max(_slow_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))


func _get_current_move_duration() -> float:
	if Time.get_ticks_msec() <= _slow_until_msec:
		return move_duration + _slow_extra_seconds_per_tile

	_slow_extra_seconds_per_tile = 0.0
	return move_duration


func _get_blocking_gate_at_node_id(node_id: int) -> Gate:
	var gate := Gate.get_gate(graph, node_id)
	if gate == null or not gate.blocks_movement():
		return null

	return gate
