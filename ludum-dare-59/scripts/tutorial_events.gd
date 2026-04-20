extends Node

signal first_crytter_spawned(enemy: Enemy, spawner_node_id: int)
signal first_crytter_moved_two_tiles(enemy: Enemy)
signal ballista_spawn_button_pressed
signal target_ballista_placed(vertex_id: int, gate: Gate)
signal first_crytter_despawned(enemy: Enemy)
signal first_level_tutorial_finished

var first_level_tutorial_active := false
var first_crytter_spawned_emitted := false
var first_crytter_moved_two_tiles_emitted := false
var ballista_spawn_button_pressed_emitted := false
var target_ballista_vertex_id := -1
var target_ballista_placed_emitted := false
var first_crytter_despawned_emitted := false
var first_level_tutorial_finished_emitted := false

var _highlight_tweens: Dictionary = {}
var _highlight_original_scales: Dictionary = {}
var _highlight_original_pivot_offsets: Dictionary = {}
var _highlight_original_positions: Dictionary = {}
var _highlight_targets: Dictionary = {}


func reset_first_level_tutorial() -> void:
	first_level_tutorial_active = false
	first_crytter_spawned_emitted = false
	first_crytter_moved_two_tiles_emitted = false
	ballista_spawn_button_pressed_emitted = false
	target_ballista_vertex_id = -1
	target_ballista_placed_emitted = false
	first_crytter_despawned_emitted = false
	first_level_tutorial_finished_emitted = false
	stop_all_highlighters()


func start_first_level_tutorial() -> void:
	reset_first_level_tutorial()
	first_level_tutorial_active = true


func should_run_first_level_tutorial() -> bool:
	return first_level_tutorial_active and not first_crytter_despawned_emitted


func finish_first_level_tutorial() -> void:
	if first_level_tutorial_finished_emitted:
		return

	first_level_tutorial_finished_emitted = true
	first_level_tutorial_active = false
	first_level_tutorial_finished.emit()


func emit_first_crytter_spawned(enemy: Enemy, spawner_node_id: int) -> void:
	first_crytter_spawned_emitted = true
	first_crytter_spawned.emit(enemy, spawner_node_id)


func emit_first_crytter_moved_two_tiles(enemy: Enemy) -> void:
	if first_crytter_moved_two_tiles_emitted:
		return

	first_crytter_moved_two_tiles_emitted = true
	first_crytter_moved_two_tiles.emit(enemy)


func emit_ballista_spawn_button_pressed() -> void:
	if ballista_spawn_button_pressed_emitted:
		return

	ballista_spawn_button_pressed_emitted = true
	ballista_spawn_button_pressed.emit()


func emit_target_ballista_placed(vertex_id: int, gate: Gate) -> void:
	target_ballista_placed_emitted = true
	target_ballista_placed.emit(vertex_id, gate)


func emit_first_crytter_despawned(enemy: Enemy) -> void:
	if first_crytter_despawned_emitted:
		return

	first_crytter_despawned_emitted = true
	first_level_tutorial_active = false
	first_crytter_despawned.emit(enemy)




func start_highlighter(target: Node, pivot_offset: Variant = null) -> void:
	if target == null or not is_instance_valid(target):
		return

	var instance_id := target.get_instance_id()
	if _highlight_tweens.has(instance_id):
		return

	if target is Control:
		var control := target as Control
		var original_pivot_offset := control.pivot_offset
		var new_pivot_offset := control.size * 0.5
		if pivot_offset is Vector2:
			new_pivot_offset = pivot_offset
		_highlight_original_pivot_offsets[instance_id] = original_pivot_offset
		_highlight_original_positions[instance_id] = control.position
		control.position += (original_pivot_offset - new_pivot_offset) * (Vector2.ONE - control.scale)
		control.pivot_offset = new_pivot_offset

	var original_scale: Vector2 = target.get("scale")
	_highlight_original_scales[instance_id] = original_scale
	_highlight_targets[instance_id] = target

	var tween := target.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_loops()
	tween.tween_property(target, "scale", original_scale * 1.3, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "scale", original_scale, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tweens[instance_id] = tween


func stop_highlighter(target: Node) -> void:
	if target == null:
		return

	var instance_id := target.get_instance_id()
	var tween := _highlight_tweens.get(instance_id) as Tween
	if tween != null:
		tween.kill()

	_highlight_tweens.erase(instance_id)

	if _highlight_original_scales.has(instance_id) and is_instance_valid(target):
		target.set("scale", _highlight_original_scales[instance_id])
	if is_instance_valid(target) and target is Control:
		var control := target as Control
		if _highlight_original_positions.has(instance_id):
			control.position = _highlight_original_positions[instance_id]
		if _highlight_original_pivot_offsets.has(instance_id):
			control.pivot_offset = _highlight_original_pivot_offsets[instance_id]

	_highlight_original_scales.erase(instance_id)
	_highlight_original_pivot_offsets.erase(instance_id)
	_highlight_original_positions.erase(instance_id)
	_highlight_targets.erase(instance_id)


func stop_all_highlighters() -> void:
	for instance_id in _highlight_tweens.keys():
		var tween := _highlight_tweens[instance_id] as Tween
		if tween is Tween:
			(tween as Tween).kill()

		var raw_target = _highlight_targets.get(instance_id)
		if raw_target != null and is_instance_valid(raw_target) and _highlight_original_scales.has(instance_id):
			(raw_target as Node).set("scale", _highlight_original_scales[instance_id])
		if raw_target != null and is_instance_valid(raw_target) and raw_target is Control:
			var control := raw_target as Control
			if _highlight_original_positions.has(instance_id):
				control.position = _highlight_original_positions[instance_id]
			if _highlight_original_pivot_offsets.has(instance_id):
				control.pivot_offset = _highlight_original_pivot_offsets[instance_id]

	_highlight_tweens.clear()
	_highlight_original_scales.clear()
	_highlight_original_pivot_offsets.clear()
	_highlight_original_positions.clear()
	_highlight_targets.clear()
