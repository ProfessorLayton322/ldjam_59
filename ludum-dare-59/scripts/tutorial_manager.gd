extends RefCounted
class_name TutorialManager
const DebugTrace := preload("res://scripts/debug_trace.gd")
const TUTORIAL_DIALOGUE_1_ID := "tutorial_dialogue_1_1"
const TUTORIAL_DIALOGUE_1_PATH := "res://assets/dialogues/tutorials/1/tutorial_dialogue_1_1.dtl"
const TUTORIAL_DIALOGUE_2_ID := "tutorial_dialogue_1_2"
const TUTORIAL_DIALOGUE_2_PATH := "res://assets/dialogues/tutorials/1/tutorial_dialogue_1_2.dtl"
const TUTORIAL_DIALOGUE_3_ID := "tutorial_dialogue_1_3"
const TUTORIAL_DIALOGUE_3_PATH := "res://assets/dialogues/tutorials/1/tutorial_dialogue_1_3.dtl"
const TUTORIAL_DIALOGUE_BOX_SIZE := Vector2(520.0, 150.0)
const TUTORIAL_DIALOGUE_MARGIN := Vector2(24.0, 24.0)
const TUTORIAL_BALLISTA_ID := "ballista"
enum Step {
	NONE,
	SELECT_BALLISTA,
	PLACE_BALLISTA,
	WAIT_FIRST_CRYTTER_DEATH,
	MOVE_BALLISTA,
	REMOVE_BALLISTA,
	DONE,
}
var demo
var step := Step.NONE
var target_vertex_id := -1
var target_tile: BaseTile
var move_target_vertex_id := -1
var move_target_tile: BaseTile
var ballista_gate: Gate
var ballista_button: Button
var dialog_manual_advance_was_enabled := true
var dialog_layout: Node
func _init(p_demo: Node) -> void:
	demo = p_demo
func setup_state() -> void:
	if LevelState.current_level_index == 0:
		TutorialEvents.start_first_level_tutorial()
	else:
		TutorialEvents.reset_first_level_tutorial()
func configure_flow() -> void:
	if not TutorialEvents.first_level_tutorial_active:
		return
	if not TutorialEvents.first_crytter_spawned.is_connected(_on_first_crytter_spawned):
		TutorialEvents.first_crytter_spawned.connect(_on_first_crytter_spawned)
	if not TutorialEvents.first_crytter_moved_two_tiles.is_connected(_on_first_crytter_moved_two_tiles):
		TutorialEvents.first_crytter_moved_two_tiles.connect(_on_first_crytter_moved_two_tiles)
	if not TutorialEvents.target_ballista_placed.is_connected(_on_target_ballista_placed):
		TutorialEvents.target_ballista_placed.connect(_on_target_ballista_placed)
	if not TutorialEvents.first_crytter_despawned.is_connected(_on_first_crytter_despawned):
		TutorialEvents.first_crytter_despawned.connect(_on_first_crytter_despawned)
	ballista_button = demo._gate_buttons.get(TUTORIAL_BALLISTA_ID) as Button
	apply_button_locks()
func handle_gate_button_pressed(definition: Resource, button: Button) -> bool:
	if step == Step.SELECT_BALLISTA:
		if definition == null or definition.id != TUTORIAL_BALLISTA_ID:
			button.set_pressed_no_signal(false)
			return true
		TutorialEvents.stop_highlighter(button)
		TutorialEvents.emit_ballista_spawn_button_pressed()
		demo._set_gate_placement_enabled(true, definition)
		_begin_ballista_placement()
		return true
	if step == Step.PLACE_BALLISTA:
		if definition == null or definition.id != TUTORIAL_BALLISTA_ID:
			button.set_pressed_no_signal(false)
			return true
	return false
func handle_input(event: InputEvent) -> bool:
	if step == Step.SELECT_BALLISTA:
		if _try_select_ballista_from_key(event):
			demo.get_viewport().set_input_as_handled()
			return true
		if event is InputEventMouseButton:
			var tutorial_mouse := event as InputEventMouseButton
			if tutorial_mouse.button_index == MOUSE_BUTTON_LEFT:
				return false
		demo.get_viewport().set_input_as_handled()
		return true
	if step == Step.PLACE_BALLISTA:
		if event is InputEventMouseButton:
			var tutorial_mouse := event as InputEventMouseButton
			if tutorial_mouse.button_index == MOUSE_BUTTON_LEFT:
				if tutorial_mouse.pressed:
					_try_place_ballista(demo.get_global_mouse_position())
				demo.get_viewport().set_input_as_handled()
				return true
		demo.get_viewport().set_input_as_handled()
		return true
	if step == Step.MOVE_BALLISTA:
		_handle_ballista_move_input(event)
		demo.get_viewport().set_input_as_handled()
		return true
	if step == Step.REMOVE_BALLISTA:
		_handle_ballista_remove_input(event)
		demo.get_viewport().set_input_as_handled()
		return true
	return false
func _on_first_crytter_spawned(_enemy: Enemy, spawner_node_id: int) -> void:
	target_vertex_id = _find_target_vertex_id(spawner_node_id)
	TutorialEvents.target_ballista_vertex_id = target_vertex_id
	target_tile = demo._tiles_by_node_id.get(target_vertex_id) as BaseTile
	DebugTrace.event("tutorial", "first_crytter_spawned", {
		"enemy": DebugTrace.enemy_state(_enemy),
		"spawner_node_id": spawner_node_id,
		"target_vertex_id": target_vertex_id,
		"target_tile": DebugTrace.node_state(target_tile),
	})
func _on_first_crytter_moved_two_tiles(_enemy: Enemy) -> void:
	DebugTrace.event("tutorial", "first_crytter_moved_two_tiles", {
		"enemy": DebugTrace.enemy_state(_enemy),
		"current_step": step,
	})
	if step != Step.NONE:
		return
	step = Step.SELECT_BALLISTA
	demo._set_pause_mode_enabled(true)
	_start_tutorial_dialogue(TUTORIAL_DIALOGUE_1_ID, TUTORIAL_DIALOGUE_1_PATH)
	apply_button_locks()
	if ballista_button != null:
		TutorialEvents.start_highlighter(ballista_button)
func _begin_ballista_placement() -> void:
	DebugTrace.event("tutorial", "begin_ballista_placement", {
		"target_vertex_id": target_vertex_id,
		"target_tile": DebugTrace.node_state(target_tile),
	})
	step = Step.PLACE_BALLISTA
	apply_button_locks()
	if target_tile != null:
		TutorialEvents.start_highlighter(target_tile)
func _on_target_ballista_placed(_vertex_id: int, _gate: Gate) -> void:
	DebugTrace.event("tutorial", "target_ballista_placed", {
		"vertex_id": _vertex_id,
		"gate": DebugTrace.gate_state(_gate),
	})
	if target_tile != null:
		TutorialEvents.stop_highlighter(target_tile)
	ballista_gate = _gate
	step = Step.WAIT_FIRST_CRYTTER_DEATH
	TutorialEvents.finish_first_level_tutorial()
	_end_tutorial_dialogue()
	demo._set_pause_mode_enabled(false)
	apply_button_locks()
func _on_first_crytter_despawned(_enemy: Enemy) -> void:
	DebugTrace.event("tutorial", "first_crytter_despawned", {"enemy": DebugTrace.enemy_state(_enemy)})
	if step == Step.WAIT_FIRST_CRYTTER_DEATH:
		_begin_ballista_move()
func _begin_ballista_move() -> void:
	if ballista_gate == null or not is_instance_valid(ballista_gate):
		ballista_gate = Gate.get_gate(demo._graph, target_vertex_id)
	if ballista_gate == null:
		DebugTrace.event("tutorial", "begin_ballista_move:missing_gate", {"vertex_id": target_vertex_id})
		step = Step.DONE
		apply_button_locks()
		return
	move_target_vertex_id = _find_wire_vertex_two_steps_right(ballista_gate.vertex_id)
	move_target_tile = demo._tiles_by_node_id.get(move_target_vertex_id) as BaseTile
	DebugTrace.event("tutorial", "begin_ballista_move", {
		"gate": DebugTrace.gate_state(ballista_gate),
		"target_vertex_id": move_target_vertex_id,
		"target_tile": DebugTrace.node_state(move_target_tile),
	})
	if move_target_vertex_id == -1:
		step = Step.DONE
		apply_button_locks()
		return
	step = Step.MOVE_BALLISTA
	demo._set_pause_mode_enabled(true)
	_start_tutorial_dialogue(TUTORIAL_DIALOGUE_2_ID, TUTORIAL_DIALOGUE_2_PATH)
	apply_button_locks()
	_restart_ballista_move_highlighters()
func _complete_ballista_move() -> void:
	if ballista_gate != null and is_instance_valid(ballista_gate):
		TutorialEvents.stop_highlighter(ballista_gate)
	if move_target_tile != null:
		TutorialEvents.stop_highlighter(move_target_tile)
	step = Step.REMOVE_BALLISTA
	apply_button_locks()
	if ballista_gate != null and is_instance_valid(ballista_gate):
		TutorialEvents.start_highlighter(ballista_gate)
	_replace_tutorial_dialogue(TUTORIAL_DIALOGUE_3_ID, TUTORIAL_DIALOGUE_3_PATH, Step.REMOVE_BALLISTA)
func _complete_ballista_remove() -> void:
	if ballista_gate != null and is_instance_valid(ballista_gate):
		TutorialEvents.stop_highlighter(ballista_gate)
	_end_tutorial_dialogue()
	step = Step.DONE
	TutorialEvents.stop_all_highlighters()
	demo._set_pause_mode_enabled(false)
	apply_button_locks()
func handle_unhandled_input(event: InputEvent) -> bool:
	if step == Step.SELECT_BALLISTA:
		if event is InputEventKey and event.pressed and not event.echo:
			_try_select_ballista_from_key(event)
			demo.get_viewport().set_input_as_handled()
			return true
		if event is InputEventMouseButton:
			demo.get_viewport().set_input_as_handled()
			return true
		demo.get_viewport().set_input_as_handled()
		return true
	if step == Step.MOVE_BALLISTA or step == Step.REMOVE_BALLISTA:
		demo.get_viewport().set_input_as_handled()
		return true
	if step != Step.PLACE_BALLISTA:
		return false
	if not event is InputEventMouseButton:
		demo.get_viewport().set_input_as_handled()
		return true
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		demo.get_viewport().set_input_as_handled()
		return true
	if not mouse_event.pressed:
		demo.get_viewport().set_input_as_handled()
		return true
	_try_place_ballista(demo.get_global_mouse_position())
	demo.get_viewport().set_input_as_handled()
	return true
func _try_select_ballista_from_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_2 or ballista_button == null:
		return false
	ballista_button.set_pressed_no_signal(true)
	demo._on_gate_button_pressed(BalanceManager.get_gate_definition(TUTORIAL_BALLISTA_ID), ballista_button)
	return true
func _handle_ballista_move_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_try_pickup_ballista(demo.get_global_mouse_position())
		return
	if demo._moving_gate != null:
		_try_drop_ballista(demo.get_global_mouse_position())
func _handle_ballista_remove_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	var vertex_id: int = demo._get_track_vertex_id_at_global_position(demo.get_global_mouse_position())
	if vertex_id != move_target_vertex_id:
		return
	var gate := Gate.get_gate(demo._graph, vertex_id)
	if gate == null or gate != ballista_gate:
		return
	demo._delete_gate_at(vertex_id)
	_complete_ballista_remove()
func _try_pickup_ballista(global_position: Vector2) -> void:
	ballista_gate = _get_current_ballista_gate()
	if ballista_gate == null:
		return
	var vertex_id: int = demo._get_track_vertex_id_at_global_position(global_position)
	if vertex_id != ballista_gate.vertex_id:
		return
	TutorialEvents.stop_highlighter(ballista_gate)
	demo._pickup_gate_at(vertex_id)
func _try_drop_ballista(global_position: Vector2) -> void:
	var gate: Gate = demo._moving_gate
	var target_vertex_id: int = demo._get_track_vertex_id_at_global_position(global_position)
	if target_vertex_id != move_target_vertex_id:
		demo._cancel_moving_gate()
		ballista_gate = _get_current_ballista_gate()
		_restart_ballista_move_highlighters()
		DebugTrace.event("tutorial", "try_drop_ballista:wrong_target_returned", {
			"target_vertex_id": target_vertex_id,
			"required_vertex_id": move_target_vertex_id,
			"gate": DebugTrace.gate_state(ballista_gate),
		})
		return
	demo._drop_moving_gate(global_position)
	if gate == null or not is_instance_valid(gate):
		ballista_gate = _get_current_ballista_gate()
		_restart_ballista_move_highlighters()
		return
	ballista_gate = gate
	if gate.vertex_id != move_target_vertex_id:
		_restart_ballista_move_highlighters()
		return
	_complete_ballista_move()
func _get_current_ballista_gate() -> Gate:
	if _is_ballista_gate(demo._moving_gate):
		return demo._moving_gate
	if _is_ballista_gate(ballista_gate):
		return ballista_gate
	for vertex_id in [target_vertex_id, move_target_vertex_id]:
		var gate := Gate.get_gate(demo._graph, vertex_id)
		if _is_ballista_gate(gate):
			return gate
	for child in demo.get_children():
		if _is_ballista_gate(child):
			return child as Gate
	return null
func _is_ballista_gate(gate: Node) -> bool:
	if gate == null or not is_instance_valid(gate) or gate.is_queued_for_deletion():
		return false
	if not (gate is Gate):
		return false
	var typed_gate := gate as Gate
	return typed_gate.graph == demo._graph and typed_gate.definition_id == TUTORIAL_BALLISTA_ID
func _restart_ballista_move_highlighters() -> void:
	if step != Step.MOVE_BALLISTA:
		return
	TutorialEvents.stop_all_highlighters()
	ballista_gate = _get_current_ballista_gate()
	if ballista_gate != null:
		TutorialEvents.start_highlighter(ballista_gate)
	if move_target_tile != null and is_instance_valid(move_target_tile):
		TutorialEvents.start_highlighter(move_target_tile)
func _find_wire_vertex_two_steps_right(vertex_id: int) -> int:
	var source: GraphVertex = demo._graph.get_node_by_id(vertex_id)
	if source == null:
		return -1
	var target_position: Vector2 = source.position + Vector2(256.0, 0.0)
	var best_vertex_id := -1
	var best_distance := INF
	for vertex: GraphVertex in demo._graph.nodes:
		if not (demo._tiles_by_node_id.get(vertex.id) is WireTile):
			continue
		var distance: float = target_position.distance_to(vertex.position)
		if distance >= best_distance:
			continue
		best_vertex_id = vertex.id
		best_distance = distance
	return best_vertex_id
func _try_place_ballista(global_position: Vector2) -> bool:
	DebugTrace.event("tutorial", "try_place_ballista:start", {
		"global_position": global_position,
		"selected_definition_id": demo._selected_gate_definition.id if demo._selected_gate_definition != null else "",
		"target_vertex_id": target_vertex_id,
	})
	if demo._selected_gate_definition == null or demo._selected_gate_definition.id != TUTORIAL_BALLISTA_ID:
		DebugTrace.event("tutorial", "try_place_ballista:no_selected_ballista", {})
		return false
	var vertex_id: int = demo._get_track_vertex_id_at_global_position(global_position)
	if vertex_id != target_vertex_id:
		if not _is_global_position_on_target(global_position):
			DebugTrace.event("tutorial", "try_place_ballista:not_target", {
				"computed_vertex_id": vertex_id,
				"target_vertex_id": target_vertex_id,
			})
			return false
		vertex_id = target_vertex_id
	if vertex_id == -1:
		DebugTrace.event("tutorial", "try_place_ballista:no_vertex", {})
		return false
	if not demo._place_gate(vertex_id, demo._selected_gate_definition):
		DebugTrace.event("tutorial", "try_place_ballista:place_failed", {"vertex_id": vertex_id})
		return false
	var gate := Gate.get_gate(demo._graph, vertex_id)
	demo._set_gate_placement_enabled(false)
	TutorialEvents.emit_target_ballista_placed(vertex_id, gate)
	DebugTrace.event("tutorial", "try_place_ballista:done", {
		"vertex_id": vertex_id,
		"gate": DebugTrace.gate_state(gate),
	})
	return true
func _is_global_position_on_target(global_position: Vector2) -> bool:
	if target_vertex_id == -1:
		return false
	var target_position := Vector2.ZERO
	var target_vertex: GraphVertex = demo._graph.get_node_by_id(target_vertex_id)
	if target_vertex != null:
		target_position = target_vertex.position
	elif target_tile != null:
		target_position = demo.to_local(target_tile.global_position)
	else:
		return false
	var click_position: Vector2 = demo.to_local(global_position)
	var target_radius := maxf(demo._get_gate_placement_radius(), 48.0)
	return click_position.distance_to(target_position) <= target_radius
func apply_button_locks() -> void:
	if demo._gate_buttons.is_empty():
		return
	if step == Step.SELECT_BALLISTA or step == Step.PLACE_BALLISTA:
		for gate_definition: Resource in demo._get_gate_definitions():
			var button := demo._gate_buttons.get(gate_definition.id) as Button
			if button == null:
				continue
			button.disabled = gate_definition.id != TUTORIAL_BALLISTA_ID
		if demo._pause_button != null:
			demo._pause_button.disabled = true
	elif step == Step.MOVE_BALLISTA or step == Step.REMOVE_BALLISTA:
		demo._set_gate_placement_enabled(false)
		for gate_definition: Resource in demo._get_gate_definitions():
			var button := demo._gate_buttons.get(gate_definition.id) as Button
			if button != null:
				button.disabled = true
		if demo._pause_button != null:
			demo._pause_button.disabled = true
	else:
		for gate_definition: Resource in demo._get_gate_definitions():
			var button := demo._gate_buttons.get(gate_definition.id) as Button
			if button == null:
				continue
			button.disabled = not demo._can_place_gate(gate_definition)
		if demo._pause_button != null:
			demo._pause_button.disabled = false
func _start_tutorial_dialogue(dialogue_id: String, dialogue_path: String) -> void:
	if dialog_layout != null and is_instance_valid(dialog_layout):
		return
	dialog_manual_advance_was_enabled = Dialogic.Inputs.manual_advance.system_enabled
	Dialogic.Inputs.manual_advance.system_enabled = false
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	var timeline: String = dialogue_id
	if not Dialogic.timeline_exists(timeline):
		timeline = dialogue_path
	dialog_layout = Dialogic.start(timeline)
	if dialog_layout == null:
		Dialogic.Inputs.manual_advance.system_enabled = dialog_manual_advance_was_enabled
		push_error("Tutorial dialogue failed to start: %s" % timeline)
		return
	dialog_layout.process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_position_tutorial_dialogue")
func _end_tutorial_dialogue() -> void:
	Dialogic.Inputs.manual_advance.system_enabled = dialog_manual_advance_was_enabled
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)
	elif dialog_layout != null and is_instance_valid(dialog_layout):
		dialog_layout.queue_free()
	dialog_layout = null

func _replace_tutorial_dialogue(dialogue_id: String, dialogue_path: String, expected_step: int = Step.NONE) -> void:
	var had_current_timeline := Dialogic.current_timeline != null
	_end_tutorial_dialogue()
	if had_current_timeline:
		await Dialogic.timeline_ended
	await demo.get_tree().process_frame
	if expected_step != Step.NONE and step != expected_step:
		return
	_start_tutorial_dialogue(dialogue_id, dialogue_path)
func _position_tutorial_dialogue() -> void:
	if dialog_layout == null or not is_instance_valid(dialog_layout):
		return
	if not dialog_layout.is_node_ready():
		await dialog_layout.ready
	_disable_tutorial_dialogue_input_catcher()
	var textbox_layer := dialog_layout.get_node_or_null("VN_TextboxLayer") as Control
	if textbox_layer == null:
		return
	textbox_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	if "box_size" in textbox_layer:
		textbox_layer.set("box_size", TUTORIAL_DIALOGUE_BOX_SIZE)
	if "box_margin_bottom" in textbox_layer:
		textbox_layer.set("box_margin_bottom", int(TUTORIAL_DIALOGUE_MARGIN.y))
	var anchor := textbox_layer.get_node_or_null("Anchor") as Control
	if anchor == null:
		return
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	var anchor_offset := Vector2(-(TUTORIAL_DIALOGUE_MARGIN.x + TUTORIAL_DIALOGUE_BOX_SIZE.x * 0.5), 0.0)
	anchor.offset_left = anchor_offset.x
	anchor.offset_right = anchor_offset.x
	anchor.offset_top = anchor_offset.y
	anchor.offset_bottom = anchor_offset.y
	if textbox_layer.has_method("_apply_export_overrides"):
		textbox_layer.call("_apply_export_overrides")
func _disable_tutorial_dialogue_input_catcher() -> void:
	if dialog_layout == null or not is_instance_valid(dialog_layout):
		return
	var input_layer := dialog_layout.get_node_or_null("FullAdvanceInputLayer") as Control
	if input_layer != null:
		input_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		input_layer.process_mode = Node.PROCESS_MODE_DISABLED
	var input_node := dialog_layout.get_node_or_null("FullAdvanceInputLayer/DialogicNode_Input") as Control
	if input_node != null:
		input_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		input_node.process_mode = Node.PROCESS_MODE_DISABLED
func _find_target_vertex_id(spawner_node_id: int) -> int:
	var spawner_vertex: GraphVertex = demo._graph.get_node_by_id(spawner_node_id)
	if spawner_vertex == null:
		DebugTrace.event("tutorial", "find_target:missing_spawner", {"spawner_node_id": spawner_node_id})
		return -1
	var target_position: Vector2 = spawner_vertex.position + Vector2(256.0, 0.0)
	var best_vertex_id := -1
	var best_distance := INF
	for vertex: GraphVertex in demo._graph.nodes:
		if not (demo._tiles_by_node_id.get(vertex.id) is WireTile):
			continue
		var distance: float = target_position.distance_to(vertex.position)
		if distance >= best_distance:
			continue
		best_vertex_id = vertex.id
		best_distance = distance
	DebugTrace.event("tutorial", "find_target:done", {
		"spawner_node_id": spawner_node_id,
		"target_position": target_position,
		"best_vertex_id": best_vertex_id,
		"best_distance": best_distance,
	})
	return best_vertex_id
