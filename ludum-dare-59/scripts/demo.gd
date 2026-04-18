class_name DemoScene
extends Node2D

const DEFAULT_GATE_SCENE := preload("res://scenes/gates/default_gate.tscn")
const DEFAULT_GATE_TEXTURE := preload("res://assets/textures/gates/default_gate.svg")
const TRIGGER_INTERVAL := 1.0
const POSITION_MATCH_EPSILON := 1.0
const GATE_PLACEMENT_RADIUS := 32.0
const EXPECTED_SPAWNER_COUNT := 3
const MAX_TEMPERATURE := 5
const DEFAULT_GATE_TEMPERATURE_COST := 1

@export var tilemap_path: NodePath = ^"TileMap"
@export var trigger_timer_path: NodePath = ^"TriggerTimer"
@export var tilemap_layer := 0
@export var require_mutual_connections := true

var _graph: Graph
var _tiles: Array[BaseTile] = []
var _tiles_by_node_id: Dictionary = {}
var _placing_default_gate := false
var _temperature := 0
var _default_gate_button: Button
var _temperature_fill: ColorRect
var _temperature_label: Label


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return

	if not _placing_default_gate or not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var vertex_id := _get_track_vertex_id_at_global_position(get_global_mouse_position())
	if vertex_id == -1:
		return

	if _place_default_gate(vertex_id):
		_set_gate_placement_enabled(false)


func _ready() -> void:
	_graph = Graph.new()
	_build_graph_from_tilemap()

	await get_tree().process_frame
	_collect_tiles()
	var cpu_vertices := _build_cpu_vertices()
	_configure_spawners(cpu_vertices)
	_start_trigger_timer()
	_create_gate_button()


func _build_graph_from_tilemap() -> void:
	var level := get_node_or_null(tilemap_path)
	if level == null:
		push_error("Demo scene: TileMap not found at %s" % tilemap_path)
		return

	print("Demo scene: parsing graph from %s layer %d" % [level.get_path(), tilemap_layer])
	_graph.build_from_level(level, tilemap_layer, require_mutual_connections, true)
	if _graph.nodes.is_empty():
		push_error("Demo scene: TileMap at %s produced an empty graph" % tilemap_path)
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
	_tiles = _find_tiles(self)
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
	if spawner_count != EXPECTED_SPAWNER_COUNT:
		push_warning("Demo scene: expected %d spawner tiles from TileMap, found %d" % [
			EXPECTED_SPAWNER_COUNT,
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
	for tile in _tiles_by_node_id.values():
		if not (tile is SpawnerTile):
			continue

		var spawner := tile as SpawnerTile
		spawner.graph = _graph
		spawner.cpu_vertices = cpu_vertices
		spawner.spawn_parent = self
		print("Demo scene: wired spawner %s on node %d" % [spawner.get_path(), spawner.node_id])


func _start_trigger_timer() -> void:
	var timer := get_node_or_null(trigger_timer_path) as Timer
	if timer == null:
		timer = Timer.new()
		timer.name = "TriggerTimer"
		add_child(timer)

	timer.wait_time = TRIGGER_INTERVAL
	timer.autostart = true
	if not timer.timeout.is_connected(_trigger_tiles):
		timer.timeout.connect(_trigger_tiles)
	timer.start()


func _trigger_tiles() -> void:
	for tile: BaseTile in _tiles:
		if not is_instance_valid(tile):
			continue

		tile.OnTrigger(self)


func _create_gate_button() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var button := Button.new()
	button.name = "DefaultGateButton"
	button.icon = DEFAULT_GATE_TEXTURE
	button.expand_icon = true
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Place default gate"
	button.custom_minimum_size = Vector2(64.0, 64.0)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -80.0
	button.offset_top = 16.0
	button.offset_right = -16.0
	button.offset_bottom = 80.0
	button.pressed.connect(_on_default_gate_button_pressed)
	root.add_child(button)
	_default_gate_button = button

	_create_temperature_meter(root)
	_update_temperature_meter()


func _create_temperature_meter(root: Control) -> void:
	var meter := Panel.new()
	meter.name = "TemperatureMeter"
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.anchor_left = 1.0
	meter.anchor_right = 1.0
	meter.offset_left = -56.0
	meter.offset_right = -16.0
	meter.offset_top = 104.0
	meter.offset_bottom = 264.0

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
	label.name = "TemperatureLabel"
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


func _on_default_gate_button_pressed() -> void:
	_set_gate_placement_enabled(_default_gate_button.button_pressed)


func _set_gate_placement_enabled(enabled: bool) -> void:
	_placing_default_gate = enabled and _can_place_default_gate()
	if _default_gate_button != null:
		_default_gate_button.set_pressed_no_signal(_placing_default_gate)


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


func _place_default_gate(vertex_id: int) -> bool:
	if not _can_place_default_gate():
		_set_gate_placement_enabled(false)
		return false

	if Gate.get_gate(_graph, vertex_id) != null:
		return false

	var tile := _tiles_by_node_id.get(vertex_id) as BaseTile
	if not (tile is WireTile):
		return false

	var gate := DEFAULT_GATE_SCENE.instantiate() as Gate
	gate.graph = _graph
	gate.vertex_id = vertex_id
	add_child(gate)
	_change_temperature(DEFAULT_GATE_TEMPERATURE_COST)
	return true


func _can_place_default_gate() -> bool:
	return _temperature + DEFAULT_GATE_TEMPERATURE_COST <= MAX_TEMPERATURE


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

	if _default_gate_button != null:
		var can_place := _can_place_default_gate()
		_default_gate_button.disabled = not can_place
		if not can_place:
			_set_gate_placement_enabled(false)
