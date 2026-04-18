class_name DemoScene
extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const GRID_SIZE := Vector2i(5, 3)
const TILE_SIZE := Vector2(64.0, 64.0)
const ORIGIN := Vector2(100.0, 100.0)
# 2x2 block: x=3-4, y=1-2  →  ids 8,9 (row 1) and 13,14 (row 2)
const CPU_NODE_IDS := [8, 9, 13, 14]
const SPAWNER_NODE_IDS := [0, 10]

const _TRACKS := "res://assets/textures/tracks/"
const _STARTS := "res://assets/textures/start/"

var _graph: Graph


func _ready() -> void:
	_graph = Graph.new()
	_graph.build_from_grid(GRID_SIZE, TILE_SIZE, ORIGIN)

	_place_visuals()

	var cpu_vertices: Array[CpuVertex] = []
	for cpu_id: int in CPU_NODE_IDS:
		var cv := CpuVertex.new()
		cv.node_id = cpu_id
		cpu_vertices.append(cv)

	for spawner_node_id: int in SPAWNER_NODE_IDS:
		var spawner := EnemySpawner.new()
		spawner.graph = _graph
		spawner.cpu_vertices = cpu_vertices
		spawner.node_id = spawner_node_id
		spawner.enemy_scene = ENEMY_SCENE
		spawner.spawn_interval = 2.0
		add_child(spawner)


func _place_visuals() -> void:
	for vertex: GraphVertex in _graph.nodes:
		var key := _connection_key(vertex)

		var tile := Node2D.new()
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

	# Single cpu sprite centered on the 2x2 block, scaled to cover 2×2 tiles
	var tl := _graph.get_node_by_id(CPU_NODE_IDS[0])
	var br := _graph.get_node_by_id(CPU_NODE_IDS[3])
	var cpu_sprite := Sprite2D.new()
	cpu_sprite.texture = load("res://assets/textures/base/cpu.svg")
	cpu_sprite.position = (tl.position + br.position) * 0.5
	cpu_sprite.scale = Vector2(1.0, 1.0)
	add_child(cpu_sprite)


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
