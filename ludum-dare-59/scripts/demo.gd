class_name DemoScene
extends Node2D

const GATE_SCENE := preload("res://scenes/gates/gate.tscn")
const GATE_DEFINITIONS := [
	preload("res://scripts/resources/gate_def_barricade.tres"),
	preload("res://scripts/resources/gate_def_ballista.tres"),
	preload("res://scripts/resources/gate_def_tar.tres"),
]
const TRIGGER_INTERVAL := 1.0
const POSITION_MATCH_EPSILON := 1.0
const GATE_PLACEMENT_RADIUS := 32.0
const MAX_TEMPERATURE := 38
const DEFAULT_LEVEL := preload("res://scripts/resources/levels/demo_level.tres")

@export var level: LevelDefinition = DEFAULT_LEVEL
@export var trigger_timer_path: NodePath = ^"TriggerTimer"
@export var spawn_enemy_manager_path: NodePath = ^"SpawnEnemyManager"

const CPU_HP := 20

var _graph: Graph
var _level_board: Node
var _tiles: Array[BaseTile] = []
var _tiles_by_node_id: Dictionary = {}
var _spawn_enemy_manager: SpawnEnemyManager
var _selected_gate_definition: Resource
var _temperature := 0
var _gate_buttons: Dictionary = {}
var _moving_gate: Gate = null
var _moving_gate_origin := -1
var _pause_button: Button
var _camera: Camera2D
var _panning := false
const ZOOM_STEP := 1.15
const ZOOM_MIN := Vector2(0.25, 0.25)
const ZOOM_MAX := Vector2(4.0, 4.0)
var _temperature_fill: ColorRect
var _temperature_label: Label
const HudScene := preload("res://scripts/hud.gd")
const CpuHpBarScene := preload("res://scripts/cpu_hp_bar.gd")
var _hud: Node
var _cpu_regions: Array[Dictionary] = []


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_SPACE:
				_set_pause_mode_enabled(not get_tree().paused)
				return
			KEY_1, KEY_2, KEY_3:
				var idx := key.keycode - KEY_1
				if idx < GATE_DEFINITIONS.size():
					var def: Resource = GATE_DEFINITIONS[idx]
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
		return

	if Gate.get_gate(_graph, vertex_id) != null:
		_pickup_gate_at(vertex_id)
		return

	if _selected_gate_definition == null:
		return

	if _place_gate(vertex_id, _selected_gate_definition):
		_set_gate_placement_enabled(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var factor := ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
			var old_zoom := _camera.zoom
			var new_zoom: Vector2 = (old_zoom * factor).clamp(ZOOM_MIN, ZOOM_MAX)
			var mouse_screen := get_viewport().get_mouse_position()
			var viewport_center := get_viewport_rect().size / 2.0
			var offset := mouse_screen - viewport_center
			_camera.position += offset / old_zoom - offset / new_zoom
			_camera.zoom = new_zoom
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _panning:
		var motion := event as InputEventMouseMotion
		_camera.position -= motion.relative
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _moving_gate != null:
		_moving_gate.position = _nearest_wire_vertex_position(get_global_mouse_position())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if LevelState.selected_level != null:
		level = LevelState.selected_level

	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)

	if not _instantiate_level_board():
		return

	_hud = HudScene.new()
	add_child(_hud)

	_graph = Graph.new()
	_build_graph_from_tilemap()

	await get_tree().process_frame
	_collect_tiles()
	var cpu_vertices := _build_cpu_vertices()
	_configure_spawners(cpu_vertices)
	_configure_core_gates()
	_start_trigger_timer()
	_create_gate_buttons()


func _instantiate_level_board() -> bool:
	if level == null:
		push_error("Demo scene: no LevelDefinition assigned.")
		return false
	if level.board_scene == null:
		push_error("Demo scene: LevelDefinition '%s' has no board_scene." % level.title)
		return false

	_level_board = level.board_scene.instantiate()
	_level_board.name = "LevelBoard"
	add_child(_level_board)
	print("Demo scene: loaded level '%s' from %s" % [level.title, level.board_scene.resource_path])
	return true


func _build_graph_from_tilemap() -> void:
	if level == null or _level_board == null:
		return

	var tilemap := _level_board.get_node_or_null(level.tilemap_path)
	if tilemap == null:
		push_error("Demo scene: TileMap not found at %s in level '%s'" % [level.tilemap_path, level.title])
		return

	print("Demo scene: parsing graph from %s layer %d" % [tilemap.get_path(), level.tilemap_layer])
	_graph.build_from_level(tilemap, level.tilemap_layer, level.require_mutual_connections, true)
	if _graph.nodes.is_empty():
		push_error("Demo scene: TileMap at %s produced an empty graph" % tilemap.get_path())
		return

	for vertex: GraphVertex in _graph.nodes:
		vertex.position = to_local(vertex.position)

	print("Demo scene: parsed %d graph nodes" % _graph.nodes.size())


func _build_cpu_vertices() -> Array[CpuVertex]:
	var cpu_vertices: Array[CpuVertex] = []
	for tile in _tiles_by_node_id.values():
		if not (tile is CoreTile):
			continue

		var cv := CpuVertex.new()
		cv.node_id = tile.node_id
		cpu_vertices.append(cv)
		print("Demo scene: CPU target registered for node %d from %s" % [tile.node_id, tile.get_path()])

	return cpu_vertices


func _collect_tiles() -> void:
	_tiles = _find_tiles(_level_board)
	_tiles_by_node_id.clear()
	var spawner_count := 0
	var cpu_count := 0
	for tile: BaseTile in _tiles:
		_assign_tile_node_id_from_graph(tile)
		if tile.node_id == -1:
			continue

		_register_tile_for_node(tile)
		var kind := "tile"
		if tile is SpawnerTile:
			kind = "spawner"
			spawner_count += 1
		elif tile is CoreTile:
			kind = "cpu"
			cpu_count += 1

		print("Demo scene: found %s tile %s for node %d" % [kind, tile.get_path(), tile.node_id])

	print("Demo scene: collected %d tile nodes with graph IDs (%d spawners, %d cpu)" % [
		_tiles_by_node_id.size(),
		spawner_count,
		cpu_count,
	])
	if level != null and level.expected_spawner_count >= 0 and spawner_count != level.expected_spawner_count:
		push_warning("Demo scene: expected %d spawner tiles from TileMap, found %d" % [
			level.expected_spawner_count,
			spawner_count,
		])


func _find_tiles(root: Node) -> Array[BaseTile]:
	var tiles: Array[BaseTile] = []
	for child in root.get_children():
		if child is BaseTile:
			tiles.append(child)

		tiles.append_array(_find_tiles(child))

	return tiles


func _register_tile_for_node(tile: BaseTile) -> void:
	var existing := _tiles_by_node_id.get(tile.node_id) as BaseTile
	if existing != null and _get_tile_lookup_priority(existing) > _get_tile_lookup_priority(tile):
		return

	_tiles_by_node_id[tile.node_id] = tile


func _get_tile_lookup_priority(tile: BaseTile) -> int:
	if tile is SpawnerTile or tile is CoreTile:
		return 2
	if tile is WireTile:
		return 1

	return 0


func _assign_tile_node_id_from_graph(tile: BaseTile) -> void:
	var tile_position := to_local(tile.global_position)
	var best_vertex: GraphVertex
	var best_distance := INF
	for vertex: GraphVertex in _graph.nodes:
		var distance := tile_position.distance_to(vertex.position)
		if distance >= best_distance:
			continue

		best_vertex = vertex
		best_distance = distance

	if best_vertex == null or best_distance > POSITION_MATCH_EPSILON:
		push_warning("Demo scene: could not match tile %s at %s to graph node" % [tile.get_path(), tile_position])
		return

	if tile.node_id != best_vertex.id:
		print("Demo scene: tile %s node id %d -> %d from TileMap position" % [
			tile.get_path(),
			tile.node_id,
			best_vertex.id,
		])

	tile.node_id = best_vertex.id


func _configure_spawners(cpu_vertices: Array[CpuVertex]) -> void:
	_spawn_enemy_manager = get_node_or_null(spawn_enemy_manager_path) as SpawnEnemyManager
	if _spawn_enemy_manager == null:
		push_error("Demo scene: SpawnEnemyManager not found at %s" % spawn_enemy_manager_path)
		return

	if level != null and level.spawn_cfg != null:
		_spawn_enemy_manager.cfg = level.spawn_cfg

	_spawn_enemy_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	_spawn_enemy_manager.clear_spawners()
	for tile: BaseTile in _tiles:
		if not (tile is SpawnerTile):
			continue

		var spawner := tile as SpawnerTile
		spawner.graph = _graph
		spawner.cpu_vertices = cpu_vertices
		spawner.spawn_parent = self
		_spawn_enemy_manager.register_spawner(spawner)
		print("Demo scene: wired spawner %s on node %d" % [spawner.get_path(), spawner.node_id])

	_spawn_enemy_manager.start()


func _configure_core_gates() -> void:
	var core_node_ids: Dictionary = {}
	for tile in _tiles_by_node_id.values():
		if tile is CoreTile:
			core_node_ids[tile.node_id] = true

	var core_positions: Dictionary = {}
	for node_id in core_node_ids:
		var vertex: GraphVertex = _graph.get_node_by_id(node_id)
		if vertex != null:
			core_positions[node_id] = vertex.position

	var visited: Dictionary = {}
	var region_groups: Array = []
	for node_id in core_node_ids:
		if visited.has(node_id):
			continue
		var region_ids: Array[int] = []
		var queue: Array[int] = [node_id]
		visited[node_id] = true
		while not queue.is_empty():
			var current: int = queue.pop_front()
			region_ids.append(current)
			if not core_positions.has(current):
				continue
			var pos_a: Vector2 = core_positions[current]
			for other_id in core_positions:
				if visited.has(other_id):
					continue
				if pos_a.distance_to(core_positions[other_id]) < 70.0:
					visited[other_id] = true
					queue.append(other_id)
		region_groups.append(region_ids)

	_cpu_regions.clear()

	for region_index in region_groups.size():
		var region_ids: Array[int] = region_groups[region_index]
		var cpu_positions: Array[Vector2] = []

		for node_id in region_ids:
			var tile: BaseTile = _tiles_by_node_id.get(node_id) as BaseTile
			if tile == null:
				continue
			var gate := CoreGate.new()
			add_child(gate)
			gate.graph = _graph
			gate.vertex_id = node_id
			gate.enemy_reached.connect(_on_region_enemy_reached.bind(region_index))
			cpu_positions.append(to_local(tile.global_position))
			print("Demo scene: CoreGate registered at node %d (region %d)" % [node_id, region_index])

		if cpu_positions.is_empty():
			continue

		var top_y := cpu_positions[0].y
		var center_x := 0.0
		for p in cpu_positions:
			if p.y < top_y:
				top_y = p.y
			center_x += p.x
		center_x /= cpu_positions.size()

		var bar := CpuHpBarScene.new()
		bar.position = Vector2(center_x, top_y - 18)
		add_child(bar)
		bar.set_hp(CPU_HP, CPU_HP)
		_cpu_regions.append({"hp": CPU_HP, "bar": bar})


func _start_trigger_timer() -> void:
	var timer := get_node_or_null(trigger_timer_path) as Timer
	if timer == null:
		timer = Timer.new()
		timer.name = "TriggerTimer"
		add_child(timer)

	timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	timer.wait_time = TRIGGER_INTERVAL
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


func _create_gate_buttons() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	for i in GATE_DEFINITIONS.size():
		var definition: Resource = GATE_DEFINITIONS[i]
		var button := Button.new()
		button.name = "%sButton" % definition.id.capitalize().replace(" ", "")
		button.icon = definition.texture
		button.expand_icon = true
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "%s: %d power" % [definition.display_name, definition.power_cost]
		button.custom_minimum_size = Vector2(64.0, 64.0)
		button.anchor_left = 1.0
		button.anchor_right = 1.0
		button.offset_left = -80.0
		button.offset_top = 16.0 + float(i) * 72.0
		button.offset_right = -16.0
		button.offset_bottom = button.offset_top + 64.0
		button.pressed.connect(_on_gate_button_pressed.bind(definition, button))
		root.add_child(button)
		_gate_buttons[definition.id] = button
		_add_key_hint(root, str(i + 1), button.offset_top)

	var pause_btn := Button.new()
	pause_btn.name = "PauseButton"
	pause_btn.text = "II"
	pause_btn.toggle_mode = true
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.tooltip_text = "Pause / resume"
	pause_btn.custom_minimum_size = Vector2(64.0, 64.0)
	pause_btn.anchor_left = 1.0
	pause_btn.anchor_right = 1.0
	pause_btn.offset_left = -80.0
	pause_btn.offset_top = 16.0 + float(GATE_DEFINITIONS.size()) * 72.0
	pause_btn.offset_right = -16.0
	pause_btn.offset_bottom = pause_btn.offset_top + 64.0
	pause_btn.pressed.connect(_on_pause_button_pressed)
	root.add_child(pause_btn)
	_pause_button = pause_btn
	_add_key_hint(root, "Spc", pause_btn.offset_top)

	_create_temperature_meter(root)
	_update_temperature_meter()


func _add_key_hint(root: Control, key_text: String, top_offset: float) -> void:
	var hint := Label.new()
	hint.text = "[%s]" % key_text
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.add_theme_font_size_override("font_size", 11)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -80.0 - 36.0
	hint.offset_right = -80.0
	hint.offset_top = top_offset + 26.0
	hint.offset_bottom = top_offset + 44.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(hint)


func _create_temperature_meter(root: Control) -> void:
	var meter := Panel.new()
	meter.name = "PowerMeter"
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.anchor_left = 1.0
	meter.anchor_right = 1.0
	meter.offset_left = -56.0
	meter.offset_right = -16.0
	meter.offset_top = 16.0 + float(GATE_DEFINITIONS.size()) * 72.0 + 64.0 + 8.0
	meter.offset_bottom = meter.offset_top + 160.0

	var meter_style := StyleBoxFlat.new()
	meter_style.bg_color = Color(0.08, 0.08, 0.08, 0.82)
	meter_style.border_color = Color(0.32, 0.05, 0.04, 1.0)
	meter_style.border_width_left = 2
	meter_style.border_width_top = 2
	meter_style.border_width_right = 2
	meter_style.border_width_bottom = 2
	meter_style.corner_radius_top_left = 4
	meter_style.corner_radius_top_right = 4
	meter_style.corner_radius_bottom_right = 4
	meter_style.corner_radius_bottom_left = 4
	meter.add_theme_stylebox_override("panel", meter_style)
	root.add_child(meter)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.92, 0.05, 0.02, 1.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_left = 0.0
	fill.anchor_top = 1.0
	fill.anchor_right = 1.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 4.0
	fill.offset_top = 0.0
	fill.offset_right = -4.0
	fill.offset_bottom = -4.0
	meter.add_child(fill)
	_temperature_fill = fill

	var label := Label.new()
	label.name = "PowerLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	meter.add_child(label)
	_temperature_label = label


func _on_gate_button_pressed(definition: Resource, button: Button) -> void:
	if button.button_pressed:
		_set_gate_placement_enabled(true, definition)
	else:
		_set_gate_placement_enabled(false)


func _set_gate_placement_enabled(enabled: bool, definition: Resource = null) -> void:
	var next_definition: Resource = definition if definition != null else _selected_gate_definition
	_selected_gate_definition = next_definition if enabled and _can_place_gate(next_definition) else null
	for gate_definition: Resource in GATE_DEFINITIONS:
		var button := _gate_buttons.get(gate_definition.id) as Button
		if button == null:
			continue
		button.set_pressed_no_signal(_selected_gate_definition == gate_definition)


func _nearest_wire_vertex_position(global_position: Vector2) -> Vector2:
	var local_position := to_local(global_position)
	var best_vertex: GraphVertex
	var best_distance := INF
	for vertex: GraphVertex in _graph.nodes:
		if not (_tiles_by_node_id.get(vertex.id) is WireTile):
			continue
		var distance := local_position.distance_to(vertex.position)
		if distance < best_distance:
			best_vertex = vertex
			best_distance = distance
	return best_vertex.position if best_vertex != null else local_position


func _get_track_vertex_id_at_global_position(global_position: Vector2) -> int:
	var local_position := to_local(global_position)
	var best_vertex_id := -1
	var best_distance := INF
	for vertex: GraphVertex in _graph.nodes:
		var tile := _tiles_by_node_id.get(vertex.id) as BaseTile
		if not (tile is WireTile):
			continue

		var distance := local_position.distance_to(vertex.position)
		if distance >= best_distance:
			continue

		best_vertex_id = vertex.id
		best_distance = distance

	if best_distance > GATE_PLACEMENT_RADIUS:
		return -1

	return best_vertex_id


func _place_gate(vertex_id: int, definition: Resource) -> bool:
	if not _can_place_gate(definition):
		_set_gate_placement_enabled(false)
		return false

	if Gate.get_gate(_graph, vertex_id) != null:
		return false

	var tile := _tiles_by_node_id.get(vertex_id) as BaseTile
	if not (tile is WireTile):
		return false

	var gate := GATE_SCENE.instantiate() as Gate
	gate.definition = definition
	gate.graph = _graph
	gate.vertex_id = vertex_id
	gate.destroyed.connect(_on_gate_destroyed)
	add_child(gate)
	_change_temperature(definition.power_cost)
	return true


func _can_place_gate(definition: Resource) -> bool:
	return definition != null and _temperature + definition.power_cost <= MAX_TEMPERATURE


func _change_temperature(amount: int) -> void:
	_temperature = clampi(_temperature + amount, 0, MAX_TEMPERATURE)
	_update_temperature_meter()


func _update_temperature_meter() -> void:
	if _temperature_fill != null:
		var ratio := float(_temperature) / float(MAX_TEMPERATURE)
		_temperature_fill.anchor_top = 1.0 - ratio
		_temperature_fill.offset_top = 0.0

	if _temperature_label != null:
		_temperature_label.text = "%d/%d" % [_temperature, MAX_TEMPERATURE]

	for definition: Resource in GATE_DEFINITIONS:
		var button := _gate_buttons.get(definition.id) as Button
		if button == null:
			continue
		var can_place := _can_place_gate(definition)
		button.disabled = not can_place
		if not can_place and _selected_gate_definition == definition:
			_set_gate_placement_enabled(false)


func _on_pause_button_pressed() -> void:
	_set_pause_mode_enabled(_pause_button.button_pressed)


func _set_pause_mode_enabled(enabled: bool) -> void:
	get_tree().paused = enabled
	if _pause_button != null:
		_pause_button.set_pressed_no_signal(enabled)



func _pickup_gate_at(vertex_id: int) -> void:
	var gate := Gate.get_gate(_graph, vertex_id)
	if gate == null:
		return
	_moving_gate = gate
	_moving_gate_origin = vertex_id
	gate.modulate = Color(1.3, 1.3, 0.5)


func _drop_moving_gate(global_pos: Vector2) -> void:
	var gate := _moving_gate
	_moving_gate = null
	gate.modulate = Color.WHITE

	var target_vertex_id := _get_track_vertex_id_at_global_position(global_pos)
	if target_vertex_id == -1 or target_vertex_id == _moving_gate_origin:
		gate.vertex_id = _moving_gate_origin
		_moving_gate_origin = -1
		return

	if Gate.get_gate(_graph, target_vertex_id) != null:
		gate.vertex_id = _moving_gate_origin
		_moving_gate_origin = -1
		return

	gate.vertex_id = target_vertex_id
	_moving_gate_origin = -1


func _cancel_moving_gate() -> void:
	if _moving_gate == null:
		return
	_moving_gate.modulate = Color.WHITE
	_moving_gate.vertex_id = _moving_gate_origin
	_moving_gate = null
	_moving_gate_origin = -1


func _delete_gate_at(vertex_id: int) -> void:
	var gate := Gate.get_gate(_graph, vertex_id)
	if gate == null:
		return
	_change_temperature(-gate.get_power_cost())
	gate.queue_free()


func _on_gate_destroyed(gate: Gate) -> void:
	_change_temperature(-gate.get_power_cost())


func _on_region_enemy_reached(damage: int, region_index: int) -> void:
	if region_index >= _cpu_regions.size():
		return
	var region: Dictionary = _cpu_regions[region_index]
	region["hp"] = max(region["hp"] - damage, 0)
	var bar: Node2D = region["bar"] as Node2D
	if bar != null:
		bar.set_hp(region["hp"], CPU_HP)
		_spawn_damage_label(damage, bar.position)
	if region["hp"] <= 0:
		_hud.show_game_over()


func _spawn_damage_label(damage: int, world_pos: Vector2) -> void:
	var label := Label.new()
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
