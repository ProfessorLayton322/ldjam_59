extends Node2D


const DebugTrace := preload("res://scripts/debug_trace.gd")
const TutorialManagerScene := preload("res://scripts/tutorial_manager.gd")
const HudScene := preload("res://scripts/hud.gd")
const GameCameraScene := preload("res://scripts/game_camera.gd")
const GameSidebarScene := preload("res://scripts/game_sidebar.gd")
const GateInteractionScene := preload("res://scripts/gate_interaction.gd")
const DemoLevelSetupScene := preload("res://scripts/demo_level_setup.gd")
const VICTORY_POPUP_SECONDS := 3.0

@export var level: LevelDefinition
@export var trigger_timer_path: NodePath = ^"TriggerTimer"
@export var spawn_enemy_manager_path: NodePath = ^"SpawnEnemyManager"

var _graph: Graph
var _level_board: Node
var _tiles: Array[BaseTile] = []
var _tiles_by_node_id: Dictionary = {}
var _cpu_node_ids: Dictionary = {}
var _spawn_enemy_manager: SpawnEnemyManager
var _selected_gate_definition: Resource
var _temperature: float = 0.0
var _despawn_temperature_cooldowns: Array[Dictionary] = []
var _gate_buttons: Dictionary = {}
var _pause_button: Button
var _hud: Node
var _cpu_regions: Array[Dictionary] = []
var _level_timer: Timer
var _level_finished := false
var _tutorial_manager
var _camera: Camera2D
var _sidebar: Node
var _gate_interaction: Node

var _gate_preview: Sprite2D
var _gate_cursor_layer: CanvasLayer
var _gate_cursor_icon: Sprite2D

var _moving_gate: Gate:
	get: return _gate_interaction.get_moving_gate() if _gate_interaction != null else null


func _get_balance_params() -> BalanceParams:
	return BalanceManager.get_params()


func _get_gate_definitions() -> Array[GateDefinition]:
	return BalanceManager.get_gate_definitions()


func _get_max_temperature() -> int:
	return _get_balance_params().max_temperature


func _get_cpu_hp() -> int:
	return _get_balance_params().cpu_hp


func _get_trigger_interval() -> float:
	return _get_balance_params().trigger_interval


func _get_gate_placement_radius() -> float:
	return _get_balance_params().gate_placement_radius


func _get_despawn_cooldown_timing() -> float:
	return _get_balance_params().despawn_cooldown_timing


func _get_moving_penalty() -> float:
	return _get_balance_params().moving_penalty


func _get_moving_penalty_cooldown() -> float:
	return _get_balance_params().moving_penalty_cooldown


func _center_camera_on_graph() -> void:
	if _camera == null or _graph == null or _graph.nodes.is_empty():
		return

	var bounds := Rect2(_graph.nodes[0].position, Vector2.ZERO)
	for vertex: GraphVertex in _graph.nodes:
		bounds = bounds.expand(vertex.position)

	_camera.position = bounds.get_center()


func _start_trigger_timer() -> void:
	var timer := get_node_or_null(trigger_timer_path) as Timer
	if timer == null:
		timer = Timer.new()
		timer.name = "TriggerTimer"
		add_child(timer)

	timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	timer.wait_time = _get_trigger_interval()
	timer.autostart = true
	if not timer.timeout.is_connected(_trigger_tiles):
		timer.timeout.connect(_trigger_tiles)
	timer.start()


func _trigger_tiles() -> void:
	for tile: BaseTile in _tiles:
		if not is_instance_valid(tile):
			continue
		if tile is SpawnerTile:
			continue
		tile.OnTrigger(self)


func _start_enemy_spawning() -> void:
	if _spawn_enemy_manager != null:
		_spawn_enemy_manager.start()


func _start_level_timer() -> void:
	if level == null:
		return

	_level_timer = Timer.new()
	_level_timer.name = "LevelTimer"
	_level_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_level_timer.one_shot = true
	_level_timer.wait_time = maxf(level.duration_seconds, 0.01)
	_level_timer.timeout.connect(Callable(self, "_complete_level_with_victory"))
	add_child(_level_timer)
	_level_timer.start()


func _create_gate_buttons() -> void:
	_sidebar = GameSidebarScene.new()
	add_child(_sidebar)
	_sidebar.build(_get_gate_definitions(), _cpu_regions, _get_cpu_hp())
	_sidebar.gate_button_pressed.connect(_on_gate_button_pressed)
	_sidebar.pause_toggled.connect(_on_pause_button_pressed)
	_sidebar.victory_debug_requested.connect(_complete_level_with_victory)
	_sidebar.menu_pressed.connect(_on_menu_button_pressed)
	_sidebar.settings_pressed.connect(_on_settings_button_pressed)
	for def: Resource in _get_gate_definitions():
		_gate_buttons[def.id] = _sidebar.get_gate_button(def.id)
	_pause_button = _sidebar.get_pause_button()
	_update_temperature_meter()


func _on_gate_button_pressed(definition: Resource, button: Button) -> void:
	AudioManager.play_ui_interaction()
	if _tutorial_manager != null and _tutorial_manager.handle_gate_button_pressed(definition, button):
		return

	if button.button_pressed:
		_set_gate_placement_enabled(true, definition)
	else:
		_set_gate_placement_enabled(false)


func _set_gate_placement_enabled(enabled: bool, definition: Resource = null) -> void:
	var next_definition: Resource = definition if definition != null else _selected_gate_definition
	_selected_gate_definition = next_definition if enabled and _can_place_gate(next_definition) else null
	for gate_definition: Resource in _get_gate_definitions():
		var button := _gate_buttons.get(gate_definition.id) as Button
		if button == null:
			continue
		button.set_pressed_no_signal(_selected_gate_definition == gate_definition)


func _can_place_gate(definition: Resource) -> bool:
	return definition != null and _temperature + definition.power_cost <= _get_max_temperature()


func _can_apply_moving_penalty() -> bool:
	var amount := _get_moving_penalty()
	return amount <= 0.0 or _temperature + amount <= float(_get_max_temperature())


func _change_temperature(amount: float) -> void:
	if amount < 0.0:
		_start_temperature_cooldown(-amount, _get_despawn_cooldown_timing())
		return
	_temperature = clampf(_temperature + amount, 0.0, float(_get_max_temperature()))
	_update_temperature_meter()


func _apply_moving_penalty() -> void:
	var amount := _get_moving_penalty()
	if amount <= 0.0:
		return
	var previous_temperature := _temperature
	_temperature = clampf(_temperature + amount, 0.0, float(_get_max_temperature()))
	var added_amount := _temperature - previous_temperature
	if added_amount <= 0.0:
		return
	_update_temperature_meter()
	_start_temperature_cooldown(added_amount, _get_moving_penalty_cooldown())


func _start_temperature_cooldown(amount: float, duration: float) -> void:
	if amount <= 0.0:
		return
	if duration <= 0.0:
		_temperature = clampf(_temperature - amount, 0.0, float(_get_max_temperature()))
		_update_temperature_meter()
		return
	_despawn_temperature_cooldowns.append({
		"remaining_amount": amount,
		"remaining_time": duration,
	})


func _process_despawn_temperature_cooldowns(delta: float) -> void:
	if _despawn_temperature_cooldowns.is_empty():
		return

	var total_decrease := 0.0
	var active_cooldowns: Array[Dictionary] = []
	for cooldown: Dictionary in _despawn_temperature_cooldowns:
		var remaining_amount := float(cooldown["remaining_amount"])
		var remaining_time := float(cooldown["remaining_time"])
		if remaining_amount <= 0.0 or remaining_time <= 0.0:
			continue

		var elapsed := minf(delta, remaining_time)
		var decrease := remaining_amount if elapsed >= remaining_time else remaining_amount * elapsed / remaining_time
		total_decrease += decrease
		remaining_amount -= decrease
		remaining_time -= elapsed

		if remaining_amount > 0.0 and remaining_time > 0.0:
			active_cooldowns.append({
				"remaining_amount": remaining_amount,
				"remaining_time": remaining_time,
			})

	_despawn_temperature_cooldowns = active_cooldowns
	_temperature = clampf(_temperature - total_decrease, 0.0, float(_get_max_temperature()))
	_update_temperature_meter()


func _update_temperature_meter() -> void:
	if _sidebar == null:
		return
	_sidebar.update_temperature(_temperature, _get_max_temperature())
	for definition: Resource in _get_gate_definitions():
		var button := _gate_buttons.get(definition.id) as Button
		if button == null:
			continue
		var can_place := _can_place_gate(definition)
		button.disabled = not can_place
		if not can_place and _selected_gate_definition == definition:
			_set_gate_placement_enabled(false)
	if _tutorial_manager != null:
		_tutorial_manager.apply_button_locks()


func _on_pause_button_pressed() -> void:
	_set_pause_mode_enabled(_pause_button.button_pressed)


func _on_menu_button_pressed() -> void:
	if _tutorial_manager != null and _tutorial_manager.is_menu_settings_locked():
		return
	if _hud != null:
		get_tree().paused = true
		_hud.set_paused(true)
		_hud.show_pause_menu()


func _on_settings_button_pressed() -> void:
	if _tutorial_manager != null and _tutorial_manager.is_menu_settings_locked():
		return
	if _hud != null:
		_set_pause_mode_enabled(true)
		_hud.show_settings()


func _on_pause_menu_resume_pressed() -> void:
	if _hud != null:
		_hud.hide_pause_menu()
	_set_pause_mode_enabled(false)


func _set_pause_mode_enabled(enabled: bool) -> void:
	get_tree().paused = enabled
	if enabled:
		AudioManager.play_pause_activated()
	else:
		AudioManager.play_pause_deactivated()
	if _sidebar != null:
		_sidebar.set_pause_button_state(enabled)
	if _hud != null:
		_hud.set_paused(enabled)


func _is_win_button_input_event(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	return _sidebar != null and _sidebar.has_method("is_point_over_debug_victory_button") and _sidebar.is_point_over_debug_victory_button(mouse_event.position)


func _despawn_level_objects() -> void:
	_cancel_moving_gate()
	for child in get_children():
		if child == _hud or child == _sidebar or child == _camera or child == _gate_interaction or child == _gate_cursor_layer or child == _spawn_enemy_manager or child == _level_timer:
			continue
		if child == get_node_or_null(trigger_timer_path):
			continue
		if child == _level_board or child == _gate_preview or child is Enemy or child is Gate or child is Label:
			child.queue_free()
	_tiles.clear()
	_tiles_by_node_id.clear()
	_cpu_node_ids.clear()
	_cpu_regions.clear()
	_gate_preview = null


func _stop_level_activity() -> void:
	get_tree().paused = false
	_set_gate_placement_enabled(false)
	if _spawn_enemy_manager != null:
		_spawn_enemy_manager.stop()
	if _level_timer != null:
		_level_timer.stop()
	var trigger_timer := get_node_or_null(trigger_timer_path) as Timer
	if trigger_timer != null:
		trigger_timer.stop()
	if _tutorial_manager != null and _tutorial_manager.has_method("abort_for_victory"):
		_tutorial_manager.abort_for_victory()


func _complete_level_with_victory() -> void:
	if _level_finished:
		return

	_level_finished = true
	_stop_level_activity()
	_despawn_level_objects()

	AudioManager.play_level_victory()
	if _hud != null:
		_hud.show_victory()

	await get_tree().create_timer(VICTORY_POPUP_SECONDS).timeout
	if not is_inside_tree():
		return

	AudioManager.stop_level_audio()
	if LevelState.advance_to_next_level():
		get_tree().change_scene_to_file("res://scenes/ld_gameplay.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _complete_level_with_game_over() -> void:
	if _level_finished:
		return

	_level_finished = true
	_stop_level_activity()
	_despawn_level_objects()
	AudioManager.stop_level_audio()
	AudioManager.play_cpu_death()
	if _sidebar != null:
		_sidebar.hide_ui()
	if _hud != null:
		_hud.show_game_over()


func _on_region_enemy_reached(damage: int, region_index: int) -> void:
	if region_index >= _cpu_regions.size():
		return
	var region: Dictionary = _cpu_regions[region_index]
	region["hp"] = clampi(int(region["hp"]) - damage, 0, _get_cpu_hp())
	var bar: Node2D = region["bar"] as Node2D
	if bar != null:
		bar.set_hp(region["hp"], _get_cpu_hp())
	_spawn_damage_label(damage, region["world_pos"])
	if region["hp"] <= 0:
		_complete_level_with_game_over()
	elif not _level_finished:
		AudioManager.play_cpu_damage()


func _spawn_damage_label(damage: int, world_pos: Vector2) -> void:
	var label := Label.new()
	if damage < 0:
		label.text = "+%d" % abs(damage)
		label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3, 1.0))
	else:
		label.text = "-%d" % damage
		label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 18)
	label.position = world_pos + Vector2(-12.0, 0.0)
	label.z_index = 10
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", world_pos.y - 40.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(label.queue_free)


# --- Gate interaction delegates (kept for tutorial_manager compatibility) ---

func _place_gate(vertex_id: int, definition: Resource) -> bool:
	return _gate_interaction.place_gate(vertex_id, definition, _can_place_gate(definition))


func _pickup_gate_at(vertex_id: int) -> bool:
	if not _can_apply_moving_penalty():
		AudioManager.play_not_enough_temperature()
		return false
	return _gate_interaction.pickup_gate_at(vertex_id)


func _drop_moving_gate(global_pos: Vector2) -> void:
	if not _can_apply_moving_penalty():
		AudioManager.play_not_enough_temperature()
		_cancel_moving_gate()
		return
	if _gate_interaction.drop_moving_gate(global_pos):
		_apply_moving_penalty()


func _cancel_moving_gate() -> void:
	_gate_interaction.cancel_moving_gate()


func _delete_gate_at(vertex_id: int) -> bool:
	if _tutorial_manager != null and _tutorial_manager.should_block_manual_gate_delete(vertex_id):
		AudioManager.play_invalid_gate_move()
		return false
	return _gate_interaction.delete_gate_at(vertex_id)


func _get_track_vertex_id_at_global_position(global_position: Vector2) -> int:
	return _gate_interaction.get_track_vertex_id_at_global_position(global_position)


func _unhandled_input(event: InputEvent) -> void:
	if _is_win_button_input_event(event):
		return
	if _level_finished:
		return
	if _tutorial_manager != null and _tutorial_manager.handle_unhandled_input(event):
		return

	if event.is_action_pressed("ui_cancel"):
		if _hud != null and _hud.is_pause_menu_open():
			_hud.hide_pause_menu()
			_set_pause_mode_enabled(false)
			return
		if _hud != null and _hud.is_settings_open():
			_hud.hide_settings()
			_set_pause_mode_enabled(false)
			return
		_on_settings_button_pressed()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var overlay_open: bool = _hud != null and (_hud.is_settings_open() or _hud.is_pause_menu_open())
		match key.keycode:
			KEY_Q:
				if _hud != null and _hud.is_pause_menu_open():
					get_tree().paused = false
					get_tree().change_scene_to_file("res://scenes/menu.tscn")
				elif not (_hud != null and _hud.is_settings_open()):
					_on_menu_button_pressed()
				return
			KEY_SPACE:
				if not overlay_open:
					_set_pause_mode_enabled(not get_tree().paused)
				return
			KEY_1, KEY_2, KEY_3, KEY_4:
				if not overlay_open:
					var idx := key.keycode - KEY_1
					if idx < _get_gate_definitions().size():
						var def: Resource = _get_gate_definitions()[idx]
						var btn := _gate_buttons.get(def.id) as Button
						if btn != null and not btn.disabled:
							btn.set_pressed_no_signal(not btn.button_pressed)
							_on_gate_button_pressed(def, btn)
				return

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		var vertex_id := _get_track_vertex_id_at_global_position(get_global_mouse_position())
		if vertex_id != -1:
			_delete_gate_at(vertex_id)
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not mouse_event.pressed:
		if _moving_gate != null:
			_drop_moving_gate(get_global_mouse_position())
		return

	var vertex_id := _get_track_vertex_id_at_global_position(get_global_mouse_position())
	if vertex_id == -1:
		if _selected_gate_definition != null:
			AudioManager.play_invalid_gate_tile()
		return

	if Gate.get_gate(_graph, vertex_id) != null:
		if _selected_gate_definition != null:
			_set_gate_placement_enabled(false)
		_pickup_gate_at(vertex_id)
		return

	if _selected_gate_definition == null:
		return

	_place_gate(vertex_id, _selected_gate_definition)


func _input(event: InputEvent) -> void:
	if _is_win_button_input_event(event):
		return
	if _level_finished:
		return
	if _tutorial_manager != null and _tutorial_manager.handle_input(event):
		return


func _process(_delta: float) -> void:
	if not get_tree().paused:
		_process_despawn_temperature_cooldowns(_delta)

	if _moving_gate != null:
		_moving_gate.position = _gate_interaction.get_nearest_wire_vertex_position(get_global_mouse_position())

	if _gate_preview == null:
		_update_gate_cursor_icon()
		return
	if _selected_gate_definition == null or _moving_gate != null:
		_gate_preview.visible = false
		_update_gate_cursor_icon()
		return
	var hover_vertex := _get_track_vertex_id_at_global_position(get_global_mouse_position())
	if hover_vertex == -1:
		_gate_preview.visible = false
		_update_gate_cursor_icon()
		return
	_gate_preview.texture = _selected_gate_definition.texture
	var vertex := _graph.get_node_by_id(hover_vertex)
	_gate_preview.position = vertex.position
	_gate_preview.visible = true
	_update_gate_cursor_icon()


func _update_gate_cursor_icon() -> void:
	if _gate_cursor_icon == null:
		return

	var cursor_definition: Resource = null
	var moving_gate := _moving_gate
	if moving_gate != null and is_instance_valid(moving_gate):
		cursor_definition = moving_gate.definition
	elif _selected_gate_definition != null:
		cursor_definition = _selected_gate_definition

	if cursor_definition == null:
		_gate_cursor_icon.visible = false
		return

	var texture := cursor_definition.icon_texture as Texture2D
	if texture == null:
		texture = cursor_definition.texture
	if texture == null:
		_gate_cursor_icon.visible = false
		return

	_gate_cursor_icon.texture = texture
	_gate_cursor_icon.position = get_viewport().get_mouse_position()
	var texture_size := texture.get_size()
	var max_texture_dimension := maxf(texture_size.x, texture_size.y)
	_gate_cursor_icon.scale = Vector2.ONE * (42.0 / max_texture_dimension) if max_texture_dimension > 0.0 else Vector2.ONE
	_gate_cursor_icon.visible = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if LevelState.selected_level != null:
		level = LevelState.selected_level
	elif LevelState.get_current_level() != null:
		level = LevelState.get_current_level()

	_tutorial_manager = TutorialManagerScene.new(self)
	_tutorial_manager.setup_state()

	_camera = GameCameraScene.new()
	_camera.name = "Camera"
	add_child(_camera)

	_gate_interaction = GateInteractionScene.new()
	_gate_interaction.name = "GateInteraction"
	_gate_interaction.scene = self
	add_child(_gate_interaction)
	_gate_interaction.temperature_changed.connect(_change_temperature)
	_gate_interaction.gate_placement_blocked.connect(func(): _set_gate_placement_enabled(false))

	var setup := DemoLevelSetupScene.new()
	setup.level = level
	setup.trigger_timer_path = trigger_timer_path
	setup.spawn_enemy_manager_path = spawn_enemy_manager_path
	setup.demo = self

	if not setup.instantiate_level_board():
		return

	_level_board = setup.level_board
	_graph = Graph.new()
	setup.graph = _graph
	setup.build_graph()
	_center_camera_on_graph()

	_hud = HudScene.new()
	add_child(_hud)
	_hud.settings_closed.connect(func(): _set_pause_mode_enabled(false))
	_hud.resume_pressed.connect(_on_pause_menu_resume_pressed)

	await get_tree().process_frame
	setup.collect_tiles()
	_tiles = setup.tiles
	_tiles_by_node_id = setup.tiles_by_node_id
	_cpu_node_ids = setup.cpu_node_ids

	var cpu_vertices := setup.build_cpu_vertices()
	setup.configure_spawners(cpu_vertices)
	_spawn_enemy_manager = setup.spawn_enemy_manager
	if _spawn_enemy_manager != null and not _spawn_enemy_manager.level_completed.is_connected(_complete_level_with_victory):
		_spawn_enemy_manager.level_completed.connect(_complete_level_with_victory)

	setup.configure_core_gates(Callable(self, "_on_region_enemy_reached"), _get_cpu_hp())
	_cpu_regions = setup.cpu_regions

	_gate_interaction.graph = _graph
	_gate_interaction.tiles_by_node_id = _tiles_by_node_id
	_gate_interaction.gate_placement_radius = _get_gate_placement_radius()

	_gate_preview = Sprite2D.new()
	_gate_preview.modulate = Color(1.0, 1.0, 1.0, 0.5)
	_gate_preview.z_index = 5
	_gate_preview.visible = false
	add_child(_gate_preview)

	_gate_cursor_layer = CanvasLayer.new()
	_gate_cursor_layer.name = "GateCursorPreview"
	_gate_cursor_layer.layer = 30
	_gate_cursor_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_gate_cursor_layer)

	_gate_cursor_icon = Sprite2D.new()
	_gate_cursor_icon.name = "Icon"
	_gate_cursor_icon.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_gate_cursor_icon.visible = false
	_gate_cursor_layer.add_child(_gate_cursor_icon)

	_start_trigger_timer()
	_create_gate_buttons()
	_tutorial_manager.configure_flow()
	LevelState.emit_level_started(level)
	AudioManager.play_level_beginning()
	_start_enemy_spawning()
