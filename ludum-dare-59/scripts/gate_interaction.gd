extends Node

signal temperature_changed(amount: float)
signal gate_placement_blocked

const GATE_SCENE := preload("res://scenes/gates/gate.tscn")
const DebugTrace := preload("res://scripts/debug_trace.gd")

var graph: Graph
var tiles_by_node_id: Dictionary
var gate_placement_radius: float
var scene: Node2D

var _moving_gate: Gate = null
var _moving_gate_origin := -1


func get_moving_gate() -> Gate:
	return _moving_gate


func get_nearest_wire_vertex_position(global_position: Vector2) -> Vector2:
	var local_position := scene.to_local(global_position)
	var best_vertex: GraphVertex
	var best_distance := INF
	for vertex: GraphVertex in graph.nodes:
		if not (tiles_by_node_id.get(vertex.id) is WireTile):
			continue
		var distance := local_position.distance_to(vertex.position)
		if distance < best_distance:
			best_vertex = vertex
			best_distance = distance
	return best_vertex.position if best_vertex != null else local_position


func get_track_vertex_id_at_global_position(global_position: Vector2) -> int:
	var local_position := scene.to_local(global_position)
	var best_vertex_id := -1
	var best_distance := INF
	for vertex: GraphVertex in graph.nodes:
		var tile := tiles_by_node_id.get(vertex.id) as BaseTile
		if not (tile is WireTile):
			continue
		var distance := local_position.distance_to(vertex.position)
		if distance >= best_distance:
			continue
		best_vertex_id = vertex.id
		best_distance = distance
	if best_distance > gate_placement_radius:
		return -1
	return best_vertex_id


func place_gate(vertex_id: int, definition: Resource, can_place: bool) -> bool:
	DebugTrace.event("demo_gate", "place_gate:start", {
		"vertex_id": vertex_id,
		"definition_id": definition.id if definition != null else "",
	})
	if not can_place:
		DebugTrace.event("demo_gate", "place_gate:cannot_place", {
			"vertex_id": vertex_id,
			"definition_id": definition.id if definition != null else "",
		})
		AudioManager.play_not_enough_temperature()
		gate_placement_blocked.emit()
		return false

	var existing_gate := Gate.get_gate(graph, vertex_id)
	if existing_gate != null:
		DebugTrace.event("demo_gate", "place_gate:occupied", {
			"vertex_id": vertex_id,
			"existing_gate": DebugTrace.gate_state(existing_gate),
		})
		AudioManager.play_invalid_gate_tile()
		return false

	var tile := tiles_by_node_id.get(vertex_id) as BaseTile
	if not (tile is WireTile):
		DebugTrace.event("demo_gate", "place_gate:not_wire_tile", {
			"vertex_id": vertex_id,
			"tile": DebugTrace.node_state(tile),
		})
		AudioManager.play_invalid_gate_tile()
		return false

	var gate := GATE_SCENE.instantiate() as Gate
	gate.definition = definition
	gate.graph = graph
	gate.vertex_id = vertex_id
	gate.destroyed.connect(Callable(self, "_on_gate_destroyed"))
	scene.add_child(gate)
	temperature_changed.emit(definition.power_cost)
	DebugTrace.event("demo_gate", "place_gate:done", {
		"vertex_id": vertex_id,
		"gate": DebugTrace.gate_state(gate),
	})
	return true


func pickup_gate_at(vertex_id: int) -> bool:
	var gate := Gate.get_gate(graph, vertex_id)
	if gate == null:
		DebugTrace.event("demo_gate", "pickup_gate:missing", {"vertex_id": vertex_id})
		return false
	if gate.is_stunned():
		DebugTrace.event("demo_gate", "pickup_gate:stunned_blocked", {
			"vertex_id": vertex_id,
			"gate": DebugTrace.gate_state(gate),
		})
		AudioManager.play_invalid_gate_move()
		return false
	DebugTrace.event("demo_gate", "pickup_gate:start", {"vertex_id": vertex_id, "gate": DebugTrace.gate_state(gate)})
	_moving_gate = gate
	_moving_gate_origin = vertex_id
	gate.modulate = Color(1.3, 1.3, 0.5)
	_set_gate_icon_visible(gate, false)
	DebugTrace.event("demo_gate", "pickup_gate:done", {"vertex_id": vertex_id, "gate": DebugTrace.gate_state(gate)})
	return true


func drop_moving_gate(global_pos: Vector2) -> bool:
	var gate := _moving_gate
	DebugTrace.event("demo_gate", "drop_moving_gate:start", {
		"gate": DebugTrace.gate_state(gate),
		"origin": _moving_gate_origin,
		"global_pos": global_pos,
	})
	_moving_gate = null
	gate.modulate = Color.WHITE
	_set_gate_icon_visible(gate, true)

	if gate.is_stunned():
		AudioManager.play_invalid_gate_move()
		_snap_gate_to_vertex(gate, _moving_gate_origin)
		_moving_gate_origin = -1
		DebugTrace.event("demo_gate", "drop_moving_gate:stunned_returned_origin", {
			"gate": DebugTrace.gate_state(gate),
		})
		return false

	var target_vertex_id := get_track_vertex_id_at_global_position(global_pos)
	if target_vertex_id == -1 or target_vertex_id == _moving_gate_origin:
		AudioManager.play_invalid_gate_move()
		_snap_gate_to_vertex(gate, _moving_gate_origin)
		_moving_gate_origin = -1
		DebugTrace.event("demo_gate", "drop_moving_gate:returned_origin", {
			"gate": DebugTrace.gate_state(gate),
			"target_vertex_id": target_vertex_id,
		})
		return false

	var existing_gate := Gate.get_gate(graph, target_vertex_id)
	if existing_gate != null:
		AudioManager.play_invalid_gate_move()
		_snap_gate_to_vertex(gate, _moving_gate_origin)
		_moving_gate_origin = -1
		DebugTrace.event("demo_gate", "drop_moving_gate:occupied_returned_origin", {
			"gate": DebugTrace.gate_state(gate),
			"target_vertex_id": target_vertex_id,
			"existing_gate": DebugTrace.gate_state(existing_gate),
		})
		return false

	gate.vertex_id = target_vertex_id
	_moving_gate_origin = -1
	DebugTrace.event("demo_gate", "drop_moving_gate:moved", {
		"gate": DebugTrace.gate_state(gate),
		"target_vertex_id": target_vertex_id,
	})
	return true


func cancel_moving_gate() -> void:
	if _moving_gate == null:
		DebugTrace.event("demo_gate", "cancel_moving_gate:none", {})
		return
	DebugTrace.event("demo_gate", "cancel_moving_gate:start", {
		"gate": DebugTrace.gate_state(_moving_gate),
		"origin": _moving_gate_origin,
	})
	_moving_gate.modulate = Color.WHITE
	_set_gate_icon_visible(_moving_gate, true)
	_snap_gate_to_vertex(_moving_gate, _moving_gate_origin)
	_moving_gate = null
	_moving_gate_origin = -1
	DebugTrace.event("demo_gate", "cancel_moving_gate:done", {})


func delete_gate_at(vertex_id: int) -> bool:
	var gate := Gate.get_gate(graph, vertex_id)
	if gate == null:
		DebugTrace.event("demo_gate", "delete_gate:missing", {"vertex_id": vertex_id})
		return false
	if gate.is_stunned():
		DebugTrace.event("demo_gate", "delete_gate:stunned_blocked", {
			"vertex_id": vertex_id,
			"gate": DebugTrace.gate_state(gate),
		})
		AudioManager.play_invalid_gate_move()
		return false
	DebugTrace.event("demo_gate", "delete_gate:start", {"vertex_id": vertex_id, "gate": DebugTrace.gate_state(gate)})
	temperature_changed.emit(-gate.get_power_cost())
	AudioManager.play_gate_deleted()
	gate.queue_free()
	DebugTrace.event("demo_gate", "delete_gate:queued_free", {"vertex_id": vertex_id, "gate": DebugTrace.gate_state(gate)})
	return true


func _on_gate_destroyed(gate: Gate) -> void:
	DebugTrace.event("demo_gate", "gate_destroyed_signal", {"gate": DebugTrace.gate_state(gate)})
	temperature_changed.emit(-gate.get_power_cost())


func _set_gate_icon_visible(gate: Gate, visible: bool) -> void:
	if gate == null or not is_instance_valid(gate):
		return
	var icon_sprite := gate.get_node_or_null("IconSprite2D") as Sprite2D
	if icon_sprite != null:
		icon_sprite.visible = visible


func _snap_gate_to_vertex(gate: Gate, vertex_id: int) -> void:
	if gate == null or vertex_id < 0:
		return
	gate.vertex_id = vertex_id
	var vertex := graph.get_node_by_id(vertex_id) if graph != null else null
	if vertex != null:
		gate.position = vertex.position
