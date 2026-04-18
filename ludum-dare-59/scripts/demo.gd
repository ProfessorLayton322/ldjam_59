class_name DemoScene
extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const DEFAULT_GATE_SCENE := preload("res://scenes/gates/default_gate.tscn")
const DEFAULT_GATE_TEXTURE := preload("res://assets/textures/gates/default_gate.svg")
const GRID_SIZE := Vector2i(5, 3)
const TILE_SIZE := Vector2(64.0, 64.0)
const ORIGIN := Vector2(100.0, 100.0)
const MAX_TEMPERATURE := 5
const DEFAULT_GATE_TEMPERATURE_COST := 1
# 2x2 block: x=3-4, y=1-2  -> ids 8,9 (row 1) and 13,14 (row 2)
const CPU_NODE_IDS := [8, 9, 13, 14]
const SPAWNER_NODE_IDS := [0, 10]

const _TRACKS := "res://assets/textures/tracks/"
const _STARTS := "res://assets/textures/start/"

var _graph: Graph
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
	_graph.build_from_grid(GRID_SIZE, TILE_SIZE, ORIGIN)

	var cpu_vertices: Array[CpuVertex] = []
	for cpu_id: int in CPU_NODE_IDS:
		var cv := CpuVertex.new()
		cv.node_id = cpu_id
		cpu_vertices.append(cv)

	_place_visuals(cpu_vertices)
	_create_gate_button()


func _place_visuals(cpu_vertices: Array[CpuVertex]) -> void:
	for vertex: GraphVertex in _graph.nodes:
		var key := _connection_key(vertex)

		var tile := _create_tile(vertex, cpu_vertices)
		tile.position = vertex.position
		var bg := Sprite2D.new()
		bg.texture = load(_TRACKS + "pcb_empty.svg")
		tile.add_child(bg)

		if vertex.id in SPAWNER_NODE_IDS:
			var fg := Sprite2D.new()
			fg.texture = load(_STARTS + "start_" + _dir_name(key) + ".svg")
			tile.add_child(fg)
		elif vertex.id not in CPU_NODE_IDS:
			var info := _track_info(key)
			if not info[0].is_empty():
				var fg := Sprite2D.new()
				fg.texture = load(info[0])
				fg.rotation_degrees = info[1]
				tile.add_child(fg)

		add_child(tile)

	# Single cpu sprite centered on the 2x2 block, scaled to cover 2x2 tiles.
	var tl := _graph.get_node_by_id(CPU_NODE_IDS[0])
	var br := _graph.get_node_by_id(CPU_NODE_IDS[3])
	var cpu_sprite := Sprite2D.new()
	cpu_sprite.texture = load("res://assets/textures/base/cpu.svg")
	cpu_sprite.position = (tl.position + br.position) * 0.5
	cpu_sprite.scale = Vector2(1.0, 1.0)
	add_child(cpu_sprite)


func _create_tile(vertex: GraphVertex, cpu_vertices: Array[CpuVertex]) -> BaseTile:
	if vertex.id in SPAWNER_NODE_IDS:
		var spawner := SpawnerTile.new()
		spawner.graph = _graph
		spawner.cpu_vertices = cpu_vertices
		spawner.node_id = vertex.id
		spawner.enemy_scene = ENEMY_SCENE
		spawner.spawn_interval = 2.0
		return spawner

	if vertex.id in CPU_NODE_IDS:
		return CoreTile.new()

	return BaseTile.new()


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
	var local_position := global_position - ORIGIN
	if local_position.x < 0.0 or local_position.y < 0.0:
		return -1

	var cell := Vector2i(
		floori(local_position.x / TILE_SIZE.x),
		floori(local_position.y / TILE_SIZE.y)
	)
	if cell.x < 0 or cell.x >= GRID_SIZE.x or cell.y < 0 or cell.y >= GRID_SIZE.y:
		return -1

	var vertex_id := cell.y * GRID_SIZE.x + cell.x
	if vertex_id in CPU_NODE_IDS:
		return -1

	return vertex_id


func _place_default_gate(vertex_id: int) -> bool:
	if not _can_place_default_gate():
		_set_gate_placement_enabled(false)
		return false

	if Gate.get_gate(_graph, vertex_id) != null:
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


func _connection_key(vertex: GraphVertex) -> int:
	var key := 0
	for nid: int in vertex.neighbour_ids:
		var nv := _graph.get_node_by_id(nid)
		if nv == null:
			continue
		var diff := nv.position - vertex.position
		if   diff.x > 0.0: key |= 2  # east
		elif diff.x < 0.0: key |= 1  # west
		elif diff.y < 0.0: key |= 8  # north
		else:               key |= 4  # south
	return key


func _dir_name(key: int) -> String:
	return ("N" if key & 8 else "") + ("S" if key & 4 else "") + \
		   ("E" if key & 2 else "") + ("W" if key & 1 else "")


func _track_info(key: int) -> Array:
	match key:
		0b1100: return [_TRACKS + "track_straight_v.svg",   0.0]
		0b0011: return [_TRACKS + "track_straight_h.svg",   0.0]
		0b1000, 0b0100: return [_TRACKS + "track_straight_v.svg",   0.0]
		0b0010, 0b0001: return [_TRACKS + "track_straight_h.svg",   0.0]
		0b0110: return [_TRACKS + "track_corner_ne.svg",    0.0]
		0b0101: return [_TRACKS + "track_corner_ne.svg",   90.0]
		0b1001: return [_TRACKS + "track_corner_ne.svg",  180.0]
		0b1010: return [_TRACKS + "track_corner_ne.svg",  270.0]
		0b1011: return [_TRACKS + "track_t_junction.svg", 180.0]
		0b1110: return [_TRACKS + "track_t_junction.svg",  -90.0]
		0b0111: return [_TRACKS + "track_t_junction.svg",   0.0]
		0b1101: return [_TRACKS + "track_t_junction.svg",  90.0]
		0b1111: return [_TRACKS + "track_cross.svg",        0.0]
	return ["", 0.0]
