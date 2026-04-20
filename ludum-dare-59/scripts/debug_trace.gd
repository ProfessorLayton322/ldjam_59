class_name DebugTrace
extends RefCounted

const PREFIX := "[LDDBG]"


static func event(_category: String, _action: String, _data: Dictionary = {}) -> void:
	pass


static func gate_state(gate: Gate) -> Dictionary:
	if gate == null:
		return {"gate": "<null>"}

	var definition_id := ""
	var damage_power := 0
	var blocks_movement := false
	var indestructible := false
	if gate.definition != null:
		definition_id = gate.definition.id
		damage_power = gate.definition.damage_power
		blocks_movement = gate.definition.blocks_movement
		indestructible = gate.definition.indestructible

	return {
		"path": _node_path(gate),
		"instance_id": gate.get_instance_id(),
		"definition_id": definition_id,
		"vertex_id": gate.vertex_id,
		"graph_id": _instance_id(gate.graph),
		"registry_key": gate.get_debug_registry_key(),
		"current_hp": gate.get_debug_current_hp(),
		"stalled_count": gate.get_debug_stalled_enemy_count(),
		"stalled_hp_total": gate.get_debug_stalled_enemy_hp_total(),
		"stunned": gate.is_stunned(),
		"stunned_until_msec": gate.get_debug_stunned_until_msec(),
		"is_destroying": gate.get_debug_is_destroying(),
		"queued_for_deletion": gate.is_queued_for_deletion(),
		"inside_tree": gate.is_inside_tree(),
		"position": gate.position,
		"blocks_movement_def": blocks_movement,
		"indestructible": indestructible,
		"damage_power": damage_power,
	}


static func enemy_state(enemy: Enemy) -> Dictionary:
	if enemy == null:
		return {"enemy": "<null>"}

	var node_id := -1
	if enemy.graph != null and enemy.current_node_index >= 0 and enemy.current_node_index < enemy.graph.nodes.size():
		node_id = enemy.graph.nodes[enemy.current_node_index].id

	return {
		"path": _node_path(enemy),
		"instance_id": enemy.get_instance_id(),
		"class": enemy.get_class(),
		"balance_id": enemy.balance_id,
		"current_node_index": enemy.current_node_index,
		"current_node_id": node_id,
		"graph_id": _instance_id(enemy.graph),
		"hp": enemy.hp,
		"max_hp": enemy.max_hp,
		"damage": enemy.damage,
		"can_stun_gate": enemy.can_stun_gate,
		"gate_stun_duration": enemy.gate_stun_duration,
		"path_nodes": enemy.path,
		"stalled_gate_id": enemy.get_debug_stalled_gate_instance_id(),
		"movement_interrupted": enemy.get_debug_movement_interrupted(),
		"slow_extra_seconds_per_tile": enemy.get_debug_slow_extra_seconds_per_tile(),
		"slow_until_msec": enemy.get_debug_slow_until_msec(),
		"first_tutorial_crytter": enemy.get_debug_is_first_tutorial_crytter(),
		"tutorial_tiles_moved": enemy.get_debug_tutorial_tiles_moved(),
		"queued_for_deletion": enemy.is_queued_for_deletion(),
		"inside_tree": enemy.is_inside_tree(),
		"position": enemy.position,
	}


static func node_state(node: Node) -> Dictionary:
	if node == null:
		return {"node": "<null>"}

	return {
		"path": _node_path(node),
		"instance_id": node.get_instance_id(),
		"class": node.get_class(),
		"queued_for_deletion": node.is_queued_for_deletion(),
		"inside_tree": node.is_inside_tree(),
	}


static func _node_path(node: Node) -> String:
	if node == null:
		return "<null>"
	if not node.is_inside_tree():
		return "<outside-tree:%s>" % node.name
	return str(node.get_path())


static func _instance_id(value: Object) -> int:
	if value == null:
		return 0
	return value.get_instance_id()
