extends Node2D


const DebugTrace := preload("res://scripts/debug_trace.gd")
const TutorialManagerScene := preload("res://scripts/tutorial_manager.gd")
const HudScene := preload("res://scripts/hud.gd")
const GameCameraScene := preload("res://scripts/game_camera.gd")
const GameSidebarScene := preload("res://scripts/game_sidebar.gd")
const GateInteractionScene := preload("res://scripts/gate_interaction.gd")
const DemoLevelSetupScene := preload("res://scripts/demo_level_setup.gd")

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
var _temperature := 0
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


func _change_temperature(amount: int) -> void:
	_temperature = clampi(_temperature + amount, 0, _get_max_temperature())
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


func _complete_level_with_victory() -> void:
	if _level_finished:
		return

	_level_finished = true
	get_tree().paused = false
	if _spawn_enemy_manager != null:
		_spawn_enemy_manager.stop()
	if _level_timer != null:
		_level_timer.stop()

	AudioManager.play_level_victory()
	if LevelState.advance_to_next_level():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ld_gameplay.tscn")
	else:
		_hud.show_victory()


func _on_region_enemy_reached(damage: int, region_index: int) -> void:
	if not _level_finished:
		AudioManager.play_cpu_damage()
	if region_index >= _cpu_regions.size():
		return
	var region: Dictionary = _cpu_regions[region_index]
	region["hp"] = clampi(int(region["hp"]) - damage, 0, _get_cpu_hp())
	var bar: Node2D = region["bar"] as Node2D
	if bar != null:
		bar.set_hp(region["hp"], _get_cpu_hp())
	_spawn_damage_label(damage, region["world_pos"])
	if region["hp"] <= 0:
		if not _level_finished:
			AudioManager.play_cpu_death()
		_level_finished = true
		_hud.show_game_over()


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


func _pickup_gate_at(vertex_id: int) -> void:
	_gate_interaction.pickup_gate_at(vertex_id)


func _drop_moving_gate(global_pos: Vector2) -> void:
	_gate_interaction.drop_moving_gate(global_pos)


func _cancel_moving_gate() -> void:
	_gate_interaction.cancel_moving_gate()


func _delete_gate_at(vertex_id: int) -> void:
	_gate_interaction.delete_gate_at(vertex_id)


func _get_track_vertex_id_at_global_position(global_position: Vector2) -> int:
	return _gate_interaction.get_track_vertex_id_at_global_position(global_position)


func _unhandled_input(event: InputEvent) -> void:
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
					_hud.hide_pause_menu()
					_set_pause_mode_enabled(false)
				elif not _hud.is_settings_open():
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
			AudioManager.play_invalid_gate_tile()
			return
		_pickup_gate_at(vertex_id)
		return

	if _selected_gate_definition == null:
		return

	_place_gate(vertex_id, _selected_gate_definition)


func _input(event: InputEvent) -> void:
	if _tutorial_manager != null and _tutorial_manager.handle_input(event):
		return


func _process(_delta: float) -> void:
	if _moving_gate != null:
		_moving_gate.position = _gate_interaction.get_nearest_wire_vertex_position(get_global_mouse_position())

	if _gate_preview == null:
		return
	if _selected_gate_definition == null or _moving_gate != null:
		_gate_preview.visible = false
		return
	var hover_vertex := _get_track_vertex_id_at_global_position(get_global_mouse_position())
	if hover_vertex == -1:
		_gate_preview.visible = false
		return
	_gate_preview.texture = _selected_gate_definition.texture
	var vertex := _graph.get_node_by_id(hover_vertex)
	_gate_preview.position = vertex.position
	_gate_preview.visible = true


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

	await get_tree().process_frame
	setup.collect_tiles()
	_tiles = setup.tiles
	_tiles_by_node_id = setup.tiles_by_node_id
	_cpu_node_ids = setup.cpu_node_ids

	var cpu_vertices := setup.build_cpu_vertices()
	setup.configure_spawners(cpu_vertices)
	_spawn_enemy_manager = setup.spawn_enemy_manager

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

	_start_trigger_timer()
	_create_gate_buttons()
	_tutorial_manager.configure_flow()
	AudioManager.play_level_beginning()
	_start_enemy_spawning()
	_start_level_timer()
	AudioManager.play_music()
