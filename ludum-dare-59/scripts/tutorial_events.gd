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


func start_highlighter(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return

	var instance_id := target.get_instance_id()
	if _highlight_tweens.has(instance_id):
		return

	if target is Control:
		var control := target as Control
		control.pivot_offset = control.size * 0.5

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

	_highlight_original_scales.erase(instance_id)
	_highlight_targets.erase(instance_id)


func stop_all_highlighters() -> void:
	for instance_id in _highlight_tweens.keys():
		var tween := _highlight_tweens[instance_id] as Tween
		if tween is Tween:
			(tween as Tween).kill()

		var target := _highlight_targets.get(instance_id) as Node
		if target != null and is_instance_valid(target) and _highlight_original_scales.has(instance_id):
			target.set("scale", _highlight_original_scales[instance_id])

	_highlight_tweens.clear()
	_highlight_original_scales.clear()
	_highlight_targets.clear()
