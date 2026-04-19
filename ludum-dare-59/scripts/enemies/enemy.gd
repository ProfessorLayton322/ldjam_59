class_name Enemy
extends Node2D

const DebugTrace := preload("res://scripts/debug_trace.gd")

@export var graph: Graph
@export var cpu_vertices: Array[CpuVertex] = []
@export var current_node_index: int = -1
@export var balance_id := "enemy"
@export var move_duration: float = 3.0
@export var damage: int = 1
@export var max_hp: int = 10
@export var hp: int = 10
@export var can_stun_gate := false
@export var gate_stun_duration := 3.0

var path: Array[int] = []

var _active_tween: Tween
var _node_id_to_index: Dictionary = {}
var _slow_extra_seconds_per_tile := 0.0
var _slow_until_msec := 0
var _stalled_gate: Gate
var _movement_interrupted := false
var _is_first_tutorial_crytter := false
var _tutorial_tiles_moved := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	DebugTrace.event("enemy", "ready:start", {"enemy": DebugTrace.enemy_state(self)})
	_apply_balance_params()
	AudioManager.play_enemy_spawn(_get_balance_id())
	_ensure_icon()
	start_pathing()
	DebugTrace.event("enemy", "ready:done", {"enemy": DebugTrace.enemy_state(self)})


func _exit_tree() -> void:
	DebugTrace.event("enemy", "exit_tree", {"enemy": DebugTrace.enemy_state(self)})


func start_pathing() -> void:
	DebugTrace.event("enemy_path", "start_pathing:start", {"enemy": DebugTrace.enemy_state(self)})
	if _active_tween:
		DebugTrace.event("enemy_path", "start_pathing:kill_existing_tween", {"enemy": DebugTrace.enemy_state(self)})
		_active_tween.kill()
		_active_tween = null

	if _has_valid_node_index(current_node_index):
		position = _get_node_position(current_node_index)
		DebugTrace.event("enemy_path", "start_pathing:snap_to_node", {"enemy": DebugTrace.enemy_state(self), "position": position})

	path = _calculate_path()
	DebugTrace.event("enemy_path", "start_pathing:path_calculated", {"enemy": DebugTrace.enemy_state(self), "path": path})
	if path.is_empty():
		DebugTrace.event("enemy_path", "start_pathing:empty_path", {"enemy": DebugTrace.enemy_state(self)})
		return

	_move_to_next_node()


func _ensure_icon() -> void:
	var icon := get_node_or_null("Icon") as Sprite2D
	if icon == null:
		icon = Sprite2D.new()
		icon.name = "Icon"
		add_child(icon)

	var params := BalanceManager.get_enemy_params(_get_balance_id())
	if params != null and params.texture != null:
		icon.texture = params.texture
	else:
		icon.texture = load("res://assets/textures/enemies/circle_crytter.svg")


func _calculate_path() -> Array[int]:
	_node_id_to_index = _build_node_id_to_index()

	if not _has_valid_node_index(current_node_index):
		DebugTrace.event("enemy_path", "calculate_path:invalid_current_node", {"enemy": DebugTrace.enemy_state(self)})
		return []

	var cpu_index_set := _build_cpu_index_set()
	if cpu_index_set.is_empty():
		DebugTrace.event("enemy_path", "calculate_path:no_cpu_targets", {"enemy": DebugTrace.enemy_state(self)})
		return []

	var queue: Array[int] = [current_node_index]
	var visited := {
		current_node_index: true,
	}
	var came_from := {}

	while not queue.is_empty():
		var node_index: int = queue.pop_front()
		if cpu_index_set.has(node_index):
			DebugTrace.event("enemy_path", "calculate_path:target_found", {
				"enemy": DebugTrace.enemy_state(self),
				"target_index": node_index,
			})
			return _reconstruct_path(came_from, node_index)

		var node := graph.nodes[node_index]
		for neighbour_id in node.neighbour_ids:
			if not _node_id_to_index.has(neighbour_id):
				continue

			var neighbour_index: int = _node_id_to_index[neighbour_id]
			if visited.has(neighbour_index):
				continue

			visited[neighbour_index] = true
			came_from[neighbour_index] = node_index
			queue.append(neighbour_index)

	DebugTrace.event("enemy_path", "calculate_path:no_route", {"enemy": DebugTrace.enemy_state(self)})
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
		DebugTrace.event("enemy_path", "move_to_next_node:path_complete_queue_free", {"enemy": DebugTrace.enemy_state(self)})
		queue_free()
		return

	var next_node_index := path[1]
	var duration := _get_current_move_duration()
	DebugTrace.event("enemy_path", "move_to_next_node:start", {
		"enemy": DebugTrace.enemy_state(self),
		"next_node_index": next_node_index,
		"next_node_id": graph.nodes[next_node_index].id if graph != null and next_node_index >= 0 and next_node_index < graph.nodes.size() else -1,
		"target_position": _get_node_position(next_node_index),
		"duration": duration,
	})
	var dir := _get_node_position(next_node_index) - position
	var icon := get_node_or_null("Icon") as Node2D
	if icon != null and dir != Vector2.ZERO:
		icon.rotation = dir.angle()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position", _get_node_position(next_node_index), duration)
	_active_tween.finished.connect(_on_move_finished.bind(next_node_index), CONNECT_ONE_SHOT)


func _on_move_finished(reached_node_index: int) -> void:
	DebugTrace.event("enemy_path", "move_finished:start", {
		"enemy": DebugTrace.enemy_state(self),
		"reached_node_index": reached_node_index,
		"reached_node_id": graph.nodes[reached_node_index].id if graph != null and reached_node_index >= 0 and reached_node_index < graph.nodes.size() else -1,
	})
	_active_tween = null
	current_node_index = reached_node_index
	_track_tutorial_movement()
	_enter_current_node()
	if is_queued_for_deletion():
		DebugTrace.event("enemy_path", "move_finished:enemy_queued_return", {"enemy": DebugTrace.enemy_state(self)})
		return
	if _movement_interrupted:
		DebugTrace.event("enemy_path", "move_finished:movement_interrupted_return", {"enemy": DebugTrace.enemy_state(self)})
		_movement_interrupted = false
		return

	if not path.is_empty() and path[0] == reached_node_index:
		path.pop_front()
	elif path.size() > 1 and path[1] == reached_node_index:
		path.pop_front()

	DebugTrace.event("enemy_path", "move_finished:advance", {"enemy": DebugTrace.enemy_state(self), "path": path})
	_move_to_next_node()


func _get_node_position(node_index: int) -> Vector2:
	return graph.nodes[node_index].position


func _enter_current_node() -> void:
	if not _has_valid_node_index(current_node_index):
		DebugTrace.event("enemy_gate", "enter_current_node:invalid_node", {"enemy": DebugTrace.enemy_state(self)})
		return

	var node_id := graph.nodes[current_node_index].id
	DebugTrace.event("enemy_gate", "enter_current_node:start", {
		"enemy": DebugTrace.enemy_state(self),
		"node_id": node_id,
		"tutorial_target_vertex_id": TutorialEvents.target_ballista_vertex_id,
	})
	var gate := Gate.get_gate(graph, node_id)
	if gate != null:
		DebugTrace.event("enemy_gate", "enter_current_node:gate_found", {
			"enemy": DebugTrace.enemy_state(self),
			"gate": DebugTrace.gate_state(gate),
		})
		gate.on_enter(self)
	else:
		DebugTrace.event("enemy_gate", "enter_current_node:no_gate", {
			"enemy": DebugTrace.enemy_state(self),
			"node_id": node_id,
		})

	DebugTrace.event("enemy_gate", "enter_current_node:done", {"enemy": DebugTrace.enemy_state(self), "node_id": node_id})


func _has_valid_node_index(node_index: int) -> bool:
	return graph != null and node_index >= 0 and node_index < graph.nodes.size()


func apply_damage(amount: int) -> void:
	DebugTrace.event("enemy_damage", "apply_damage:before", {
		"enemy": DebugTrace.enemy_state(self),
		"amount": amount,
	})
	hp -= amount
	if hp <= 0:
		play_death_sound()
		DebugTrace.event("enemy_damage", "apply_damage:queue_free", {
			"enemy": DebugTrace.enemy_state(self),
			"amount": amount,
		})
		if _is_first_tutorial_crytter:
			TutorialEvents.emit_first_crytter_despawned(self)
		queue_free()
	else:
		play_damage_sound()
	DebugTrace.event("enemy_damage", "apply_damage:after", {
		"enemy": DebugTrace.enemy_state(self),
		"amount": amount,
	})


func play_damage_sound() -> void:
	AudioManager.play_enemy_damage(_get_balance_id())


func play_death_sound() -> void:
	AudioManager.play_enemy_death(_get_balance_id())


func apply_slow(extra_seconds_per_tile: float, duration: float) -> void:
	DebugTrace.event("enemy", "apply_slow:before", {
		"enemy": DebugTrace.enemy_state(self),
		"extra_seconds_per_tile": extra_seconds_per_tile,
		"duration": duration,
	})
	_slow_extra_seconds_per_tile = maxf(_slow_extra_seconds_per_tile, extra_seconds_per_tile)
	_slow_until_msec = max(_slow_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))
	DebugTrace.event("enemy", "apply_slow:after", {"enemy": DebugTrace.enemy_state(self)})


func consume_gate_stun(gate: Gate) -> float:
	if not can_stun_gate:
		DebugTrace.event("enemy_stun", "consume_gate_stun:none", {
			"enemy": DebugTrace.enemy_state(self),
			"gate": DebugTrace.gate_state(gate),
		})
		return 0.0

	DebugTrace.event("enemy_stun", "consume_gate_stun:before", {
		"enemy": DebugTrace.enemy_state(self),
		"gate": DebugTrace.gate_state(gate),
		"duration": gate_stun_duration,
	})
	can_stun_gate = false
	_on_gate_stun_consumed(gate)
	DebugTrace.event("enemy_stun", "consume_gate_stun:after", {
		"enemy": DebugTrace.enemy_state(self),
		"gate": DebugTrace.gate_state(gate),
		"duration": gate_stun_duration,
	})
	return gate_stun_duration


func stall_at_gate(gate: Gate) -> void:
	DebugTrace.event("enemy_gate", "stall_at_gate:start", {
		"enemy": DebugTrace.enemy_state(self),
		"gate": DebugTrace.gate_state(gate),
	})
	_stalled_gate = gate
	_movement_interrupted = true
	if _active_tween:
		DebugTrace.event("enemy_gate", "stall_at_gate:kill_tween", {"enemy": DebugTrace.enemy_state(self), "gate": DebugTrace.gate_state(gate)})
		_active_tween.kill()
		_active_tween = null
	DebugTrace.event("enemy_gate", "stall_at_gate:done", {
		"enemy": DebugTrace.enemy_state(self),
		"gate": DebugTrace.gate_state(gate),
	})


func release_from_gate(gate: Gate) -> void:
	if _stalled_gate != gate:
		DebugTrace.event("enemy_gate", "release_from_gate:wrong_gate", {
			"enemy": DebugTrace.enemy_state(self),
			"requested_gate": DebugTrace.gate_state(gate),
			"stalled_gate_id": _stalled_gate.get_instance_id() if _stalled_gate != null else 0,
		})
		return

	DebugTrace.event("enemy_gate", "release_from_gate:start", {
		"enemy": DebugTrace.enemy_state(self),
		"gate": DebugTrace.gate_state(gate),
	})
	_stalled_gate = null
	start_pathing()
	DebugTrace.event("enemy_gate", "release_from_gate:done", {"enemy": DebugTrace.enemy_state(self)})


func mark_as_first_tutorial_crytter() -> void:
	_is_first_tutorial_crytter = true
	_tutorial_tiles_moved = 0
	DebugTrace.event("enemy_tutorial", "mark_as_first_tutorial_crytter", {"enemy": DebugTrace.enemy_state(self)})


func _track_tutorial_movement() -> void:
	if not _is_first_tutorial_crytter:
		return

	_tutorial_tiles_moved += 1
	DebugTrace.event("enemy_tutorial", "track_movement", {"enemy": DebugTrace.enemy_state(self)})
	if _tutorial_tiles_moved == 2:
		DebugTrace.event("enemy_tutorial", "moved_two_tiles_emit", {"enemy": DebugTrace.enemy_state(self)})
		TutorialEvents.emit_first_crytter_moved_two_tiles(self)


func _on_gate_stun_consumed(_gate: Gate) -> void:
	pass


func _get_balance_id() -> String:
	return balance_id


func _apply_balance_params() -> void:
	var params := BalanceManager.get_enemy_params(_get_balance_id())
	if params == null:
		DebugTrace.event("enemy", "apply_balance_params:missing", {"enemy": DebugTrace.enemy_state(self), "balance_id": _get_balance_id()})
		return

	DebugTrace.event("enemy", "apply_balance_params:before", {"enemy": DebugTrace.enemy_state(self), "balance_id": _get_balance_id()})
	balance_id = params.id
	damage = params.damage
	max_hp = params.max_hp
	hp = max_hp
	move_duration = params.move_duration
	can_stun_gate = params.can_stun_gate
	gate_stun_duration = params.gate_stun_duration
	modulate = params.modulate
	DebugTrace.event("enemy", "apply_balance_params:after", {"enemy": DebugTrace.enemy_state(self)})


func _get_current_move_duration() -> float:
	if Time.get_ticks_msec() <= _slow_until_msec:
		return move_duration + _slow_extra_seconds_per_tile

	_slow_extra_seconds_per_tile = 0.0
	return move_duration


func get_debug_stalled_gate_instance_id() -> int:
	if _stalled_gate == null:
		return 0
	return _stalled_gate.get_instance_id()


func get_debug_movement_interrupted() -> bool:
	return _movement_interrupted


func get_debug_slow_extra_seconds_per_tile() -> float:
	return _slow_extra_seconds_per_tile


func get_debug_slow_until_msec() -> int:
	return _slow_until_msec


func get_debug_is_first_tutorial_crytter() -> bool:
	return _is_first_tutorial_crytter


func get_debug_tutorial_tiles_moved() -> int:
	return _tutorial_tiles_moved
