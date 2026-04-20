class_name Gate
extends Node2D

const DebugTrace := preload("res://scripts/debug_trace.gd")

signal destroyed(gate: Gate)

static var _gates_by_graph_vertex: Dictionary = {}

@export var definition: GateDefinition:
	set(value):
		DebugTrace.event("gate", "definition:set", {
			"gate": DebugTrace.gate_state(self),
			"old_definition": definition_id,
			"new_definition": value.id if value != null else "",
		})
		definition = value
		if definition != null:
			definition_id = definition.id
		_current_hp = _get_max_hp()
		_update_icon()
		DebugTrace.event("gate", "definition:set:done", {"gate": DebugTrace.gate_state(self)})

@export var definition_id := ""

@export var graph: Graph:
	set(value):
		if graph == value:
			DebugTrace.event("gate", "graph:set:unchanged", {"gate": DebugTrace.gate_state(self)})
			return

		DebugTrace.event("gate", "graph:set:start", {
			"gate": DebugTrace.gate_state(self),
			"old_graph_id": graph.get_instance_id() if graph != null else 0,
			"new_graph_id": value.get_instance_id() if value != null else 0,
		})
		_unregister_gate()
		graph = value
		_update_position_from_vertex()
		_register_gate()
		DebugTrace.event("gate", "graph:set:done", {"gate": DebugTrace.gate_state(self)})

@export var vertex_id: int = -1:
	set(value):
		if vertex_id == value:
			DebugTrace.event("gate", "vertex:set:unchanged", {"gate": DebugTrace.gate_state(self), "vertex_id": value})
			return

		DebugTrace.event("gate", "vertex:set:start", {
			"gate": DebugTrace.gate_state(self),
			"old_vertex_id": vertex_id,
			"new_vertex_id": value,
		})
		_unregister_gate()
		_release_stalled_enemies()
		vertex_id = value
		_update_position_from_vertex()
		_register_gate()
		DebugTrace.event("gate", "vertex:set:done", {"gate": DebugTrace.gate_state(self)})

var _registry_key := ""
var _current_hp := 1
var _stalled_enemies: Array[Enemy] = []
var _stalled_enemy_power := 0
var _is_destroying := false
var _stunned_until_msec := 0
var _stun_generation := 0


static func get_gate(target_graph: Graph, target_vertex_id: int) -> Gate:
	if target_graph == null:
		DebugTrace.event("gate_registry", "get_gate:null_graph", {"vertex_id": target_vertex_id})
		return null

	var key := _get_registry_key(target_graph, target_vertex_id)
	var gate: Gate = _gates_by_graph_vertex.get(key) as Gate
	if gate == null or not is_instance_valid(gate):
		_gates_by_graph_vertex.erase(key)
		DebugTrace.event("gate_registry", "get_gate:miss", {
			"key": key,
			"graph_id": target_graph.get_instance_id(),
			"vertex_id": target_vertex_id,
			"registry_size": _gates_by_graph_vertex.size(),
		})
		return null

	DebugTrace.event("gate_registry", "get_gate:hit", {
		"key": key,
		"graph_id": target_graph.get_instance_id(),
		"vertex_id": target_vertex_id,
		"gate": DebugTrace.gate_state(gate),
		"registry_size": _gates_by_graph_vertex.size(),
	})
	return gate


func _ready() -> void:
	DebugTrace.event("gate", "ready:start", {"gate": DebugTrace.gate_state(self)})
	z_index = 1
	_load_definition_from_balance()
	_update_position_from_vertex()
	_current_hp = _get_max_hp()
	_update_icon()

	AudioManager.play_gate_spawn(definition_id)
	DebugTrace.event("gate", "ready:done", {"gate": DebugTrace.gate_state(self)})


func _enter_tree() -> void:
	DebugTrace.event("gate", "enter_tree", {"gate": DebugTrace.gate_state(self)})
	_register_gate()


func _exit_tree() -> void:
	DebugTrace.event("gate", "exit_tree:start", {"gate": DebugTrace.gate_state(self)})
	_unregister_gate()
	_release_stalled_enemies()
	DebugTrace.event("gate", "exit_tree:done", {"gate": DebugTrace.gate_state(self)})


func on_enter(enemy: Enemy) -> void:
	if definition == null or enemy == null:
		DebugTrace.event("gate", "on_enter:ignored_null", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
		})
		return

	DebugTrace.event("gate", "on_enter:start", {
		"gate": DebugTrace.gate_state(self),
		"enemy": DebugTrace.enemy_state(enemy),
	})
	var stun_duration := enemy.consume_gate_stun(self)
	if stun_duration > 0.0:
		DebugTrace.event("gate", "on_enter:enemy_stun_consumed", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
			"duration": stun_duration,
		})
		apply_stun(stun_duration)

	if is_stunned():
		DebugTrace.event("gate", "on_enter:stunned_skip_effects", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
		})
		return

	AudioManager.play_gate_activation(definition.id)

	if definition.blocks_movement and enemy.hp >= 0:
		DebugTrace.event("gate", "on_enter:blocking_stall_start", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
		})
		_stall_enemy(enemy)
		if not definition.indestructible and _stalled_enemy_power > _current_hp:
			if definition.id == "barricade":
				AudioManager.play_barricade_overpowered_despawn()
			DebugTrace.event("gate", "on_enter:stalled_power_destroy", {
				"gate": DebugTrace.gate_state(self),
				"enemy": DebugTrace.enemy_state(enemy),
			})
			_destroy_gate()
		DebugTrace.event("gate", "on_enter:blocking_return", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
		})
		return

	if definition.damage_power > 0:
		DebugTrace.event("gate_damage", "damage_power:before", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
			"amount": definition.damage_power,
		})
		enemy.apply_damage(definition.damage_power)
		_spawn_damage_label(definition.damage_power, enemy.position)
		DebugTrace.event("gate_damage", "damage_power:after", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
			"amount": definition.damage_power,
		})
		if enemy.is_queued_for_deletion():
			DebugTrace.event("gate_damage", "damage_power:enemy_deleted_return", {
				"gate": DebugTrace.gate_state(self),
				"enemy": DebugTrace.enemy_state(enemy),
			})
			return

	if definition.halve_hp_round_up:
		var target_hp := ceili(float(enemy.hp) / 2.0)
		var damage_amount := enemy.hp - target_hp
		if damage_amount > 0:
			DebugTrace.event("gate_damage", "halve_hp:before", {
				"gate": DebugTrace.gate_state(self),
				"enemy": DebugTrace.enemy_state(enemy),
				"amount": damage_amount,
				"target_hp": target_hp,
			})
			enemy.apply_damage(damage_amount)
			_spawn_damage_label(damage_amount, enemy.position)
			DebugTrace.event("gate_damage", "halve_hp:after", {
				"gate": DebugTrace.gate_state(self),
				"enemy": DebugTrace.enemy_state(enemy),
				"amount": damage_amount,
				"target_hp": target_hp,
			})
			if enemy.is_queued_for_deletion():
				DebugTrace.event("gate_damage", "halve_hp:enemy_deleted_return", {
					"gate": DebugTrace.gate_state(self),
					"enemy": DebugTrace.enemy_state(enemy),
				})
				return

	if definition.slow_extra_seconds_per_tile > 0.0 and definition.slow_duration > 0.0:
		DebugTrace.event("gate", "on_enter:slow_apply", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
			"extra_seconds": definition.slow_extra_seconds_per_tile,
			"duration": definition.slow_duration,
		})
		enemy.apply_slow(definition.slow_extra_seconds_per_tile, definition.slow_duration)
	DebugTrace.event("gate", "on_enter:done", {
		"gate": DebugTrace.gate_state(self),
		"enemy": DebugTrace.enemy_state(enemy),
	})


func apply_stun(duration: float) -> void:
	if duration <= 0.0:
		DebugTrace.event("gate", "apply_stun:ignored", {"gate": DebugTrace.gate_state(self), "duration": duration})
		return

	DebugTrace.event("gate", "apply_stun:start", {"gate": DebugTrace.gate_state(self), "duration": duration})
	_stunned_until_msec = max(_stunned_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))
	_stun_generation += 1
	var generation := _stun_generation
	_release_stalled_enemies()
	_update_stun_visual()
	DebugTrace.event("gate", "apply_stun:armed", {
		"gate": DebugTrace.gate_state(self),
		"duration": duration,
		"generation": generation,
	})

	await get_tree().create_timer(duration, false).timeout
	if generation != _stun_generation:
		DebugTrace.event("gate", "apply_stun:timer_stale", {
			"gate": DebugTrace.gate_state(self),
			"timer_generation": generation,
			"current_generation": _stun_generation,
		})
		return

	if Time.get_ticks_msec() >= _stunned_until_msec:
		_stunned_until_msec = 0
		_update_stun_visual()
		DebugTrace.event("gate", "apply_stun:expired", {"gate": DebugTrace.gate_state(self), "generation": generation})


func is_stunned() -> bool:
	if _stunned_until_msec <= 0:
		return false

	if Time.get_ticks_msec() <= _stunned_until_msec:
		return true

	_stunned_until_msec = 0
	_update_stun_visual()
	DebugTrace.event("gate", "is_stunned:expired_lazy", {"gate": DebugTrace.gate_state(self)})
	return false


func blocks_movement() -> bool:
	var result := definition != null and definition.blocks_movement and not is_stunned()
	DebugTrace.event("gate", "blocks_movement", {"gate": DebugTrace.gate_state(self), "result": result})
	return result


func get_power_cost() -> int:
	if definition == null:
		return 0

	return definition.power_cost


func _load_definition_from_balance() -> void:
	var id := definition_id
	if id.is_empty() and definition != null:
		id = definition.id
	if id.is_empty():
		return

	var balanced_definition := BalanceManager.get_gate_definition(id)
	if balanced_definition != null:
		definition = balanced_definition


func _register_gate() -> void:
	if not is_inside_tree() or graph == null or vertex_id < 0:
		DebugTrace.event("gate_registry", "register:skipped", {
			"gate": DebugTrace.gate_state(self),
			"inside_tree": is_inside_tree(),
			"has_graph": graph != null,
			"vertex_id": vertex_id,
		})
		return

	var key := _get_registry_key(graph, vertex_id)
	var existing: Gate = _gates_by_graph_vertex.get(key) as Gate
	if existing != null and is_instance_valid(existing) and existing != self:
		push_warning("Gate already exists at vertex id %d." % vertex_id)
		DebugTrace.event("gate_registry", "register:collision", {
			"key": key,
			"gate": DebugTrace.gate_state(self),
			"existing": DebugTrace.gate_state(existing),
		})
		return

	_gates_by_graph_vertex[key] = self
	_registry_key = key
	DebugTrace.event("gate_registry", "register:done", {
		"key": key,
		"gate": DebugTrace.gate_state(self),
		"registry_size": _gates_by_graph_vertex.size(),
	})


func _unregister_gate() -> void:
	if _registry_key.is_empty():
		DebugTrace.event("gate_registry", "unregister:skipped_empty_key", {"gate": DebugTrace.gate_state(self)})
		return

	var existing: Gate = _gates_by_graph_vertex.get(_registry_key) as Gate
	if existing == self or existing == null or not is_instance_valid(existing):
		_gates_by_graph_vertex.erase(_registry_key)
		DebugTrace.event("gate_registry", "unregister:erased", {
			"key": _registry_key,
			"gate": DebugTrace.gate_state(self),
			"existing_valid": existing != null and is_instance_valid(existing),
			"registry_size": _gates_by_graph_vertex.size(),
		})
	else:
		DebugTrace.event("gate_registry", "unregister:not_owner", {
			"key": _registry_key,
			"gate": DebugTrace.gate_state(self),
			"existing": DebugTrace.gate_state(existing),
		})

	_registry_key = ""


func _stall_enemy(enemy: Enemy) -> void:
	if _stalled_enemies.has(enemy):
		DebugTrace.event("gate", "stall_enemy:duplicate", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
		})
		return

	DebugTrace.event("gate", "stall_enemy:start", {"gate": DebugTrace.gate_state(self), "enemy": DebugTrace.enemy_state(enemy)})
	_stalled_enemies.append(enemy)
	_stalled_enemy_power += enemy.damage
	enemy.stall_at_gate(self)
	_update_capacity_label()
	DebugTrace.event("gate", "stall_enemy:done", {"gate": DebugTrace.gate_state(self), "enemy": DebugTrace.enemy_state(enemy)})


func _destroy_gate() -> void:
	if _is_destroying:
		DebugTrace.event("gate", "destroy_gate:already_destroying", {"gate": DebugTrace.gate_state(self)})
		return

	DebugTrace.event("gate", "destroy_gate:start", {"gate": DebugTrace.gate_state(self)})
	_is_destroying = true
	_unregister_gate()
	_release_stalled_enemies()
	destroyed.emit(self)
	queue_free()
	DebugTrace.event("gate", "destroy_gate:queued_free", {"gate": DebugTrace.gate_state(self)})


func _release_stalled_enemies() -> void:
	var enemies := _stalled_enemies.duplicate()
	DebugTrace.event("gate", "release_stalled_enemies:start", {
		"gate": DebugTrace.gate_state(self),
		"count": enemies.size(),
	})
	_stalled_enemies.clear()
	_stalled_enemy_power = 0
	_update_capacity_label()

	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			DebugTrace.event("gate", "release_stalled_enemies:skip_invalid", {"gate": DebugTrace.gate_state(self)})
			continue

		DebugTrace.event("gate", "release_stalled_enemies:release_one", {
			"gate": DebugTrace.gate_state(self),
			"enemy": DebugTrace.enemy_state(enemy),
		})
		enemy.release_from_gate(self)
	DebugTrace.event("gate", "release_stalled_enemies:done", {"gate": DebugTrace.gate_state(self)})


func _update_position_from_vertex() -> void:
	if graph == null or vertex_id < 0:
		return

	var vertex := graph.get_node_by_id(vertex_id)
	if vertex == null:
		push_warning("Gate vertex id %d does not exist in graph." % vertex_id)
		DebugTrace.event("gate", "update_position:missing_vertex", {"gate": DebugTrace.gate_state(self), "vertex_id": vertex_id})
		return

	position = vertex.position
	DebugTrace.event("gate", "update_position:done", {"gate": DebugTrace.gate_state(self), "vertex_position": vertex.position})


static func _get_registry_key(target_graph: Graph, target_vertex_id: int) -> String:
	return "%d:%d" % [target_graph.get_instance_id(), target_vertex_id]


func _get_max_hp() -> int:
	if definition == null:
		return 1

	return definition.max_hp


func _spawn_damage_label(amount: int, spawn_position: Vector2) -> void:
	DebugTrace.event("gate_damage", "spawn_damage_label", {
		"gate": DebugTrace.gate_state(self),
		"amount": amount,
		"spawn_position": spawn_position,
	})
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	label.add_theme_font_size_override("font_size", 18)
	label.position = spawn_position - Vector2(16, 24)
	get_parent().add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -40), 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


func _update_icon() -> void:
	if not is_inside_tree():
		return

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

	var icon_sprite := get_node_or_null("IconSprite2D") as Sprite2D
	if definition != null:
		sprite.texture = definition.texture
		if definition.icon_texture != null:
			if icon_sprite == null:
				icon_sprite = Sprite2D.new()
				icon_sprite.name = "IconSprite2D"
				add_child(icon_sprite)
			icon_sprite.texture = definition.icon_texture
			icon_sprite.z_index = sprite.z_index + 1
			var icon_size := definition.icon_texture.get_size()
			var max_icon_dimension := maxf(icon_size.x, icon_size.y)
			icon_sprite.scale = Vector2.ONE * (42.0 / max_icon_dimension) if max_icon_dimension > 0.0 else Vector2.ONE
		elif icon_sprite != null:
			icon_sprite.queue_free()
	_update_stun_visual()
	_update_capacity_label()


func _update_capacity_label() -> void:
	if not is_inside_tree():
		return

	var label := get_node_or_null("CapacityLabel") as Label
	if definition == null or not definition.blocks_movement:
		if label != null:
			label.queue_free()
		return

	if label == null:
		label = Label.new()
		label.name = "CapacityLabel"
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-32, -10)
		label.size = Vector2(64, 20)
		add_child(label)

	var remaining := _current_hp - _stalled_enemy_power
	label.text = "%d / %d" % [remaining, _current_hp]


func _update_stun_visual() -> void:
	if not is_inside_tree():
		return

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	if _stunned_until_msec > 0 and Time.get_ticks_msec() <= _stunned_until_msec:
		sprite.modulate = Color(0.5, 0.5, 0.55, 0.65)
	else:
		sprite.modulate = Color.WHITE

	var icon_sprite := get_node_or_null("IconSprite2D") as Sprite2D
	if icon_sprite != null:
		icon_sprite.modulate = sprite.modulate


func get_debug_registry_key() -> String:
	return _registry_key


func get_debug_current_hp() -> int:
	return _current_hp


func get_debug_stalled_enemy_count() -> int:
	return _stalled_enemies.size()


func get_debug_stalled_enemy_power() -> int:
	return _stalled_enemy_power


func get_debug_stunned_until_msec() -> int:
	return _stunned_until_msec


func get_debug_is_destroying() -> bool:
	return _is_destroying
