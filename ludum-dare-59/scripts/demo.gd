class_name DemoScene
extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
# 2x2 block: x=3-4, y=1-2 -> ids 8,9 (row 1) and 13,14 (row 2)
const CPU_NODE_IDS := [8, 9, 13, 14]
const SPAWNER_NODE_IDS := [0, 10]

const _STARTS := "res://assets/textures/start/"

@export var tilemap_path: NodePath = ^"TileMap"
@export var tilemap_layer := 0
@export var require_mutual_connections := true

var _graph: Graph
var _tiles_by_node_id: Dictionary = {}


func _ready() -> void:
	_graph = Graph.new()
	_build_graph_from_tilemap()

	var cpu_vertices: Array[CpuVertex] = []
	for cpu_id: int in CPU_NODE_IDS:
		var cv := CpuVertex.new()
		cv.node_id = cpu_id
		cpu_vertices.append(cv)

	_place_visuals(cpu_vertices)


func _build_graph_from_tilemap() -> void:
	var level := get_node_or_null(tilemap_path)
	if level == null:
		push_error("Demo scene: TileMap not found at %s" % tilemap_path)
		return

	_graph.build_from_level(level, tilemap_layer, require_mutual_connections, true)
	if _graph.nodes.is_empty():
		push_error("Demo scene: TileMap at %s produced an empty graph" % tilemap_path)
		return

	for vertex: GraphVertex in _graph.nodes:
		vertex.position = to_local(vertex.position)


func _place_visuals(cpu_vertices: Array[CpuVertex]) -> void:
	_tiles_by_node_id.clear()

	for vertex: GraphVertex in _graph.nodes:
		var tile := _create_tile(vertex, cpu_vertices)
		tile.position = vertex.position
		_tiles_by_node_id[vertex.id] = tile

		if vertex.id in SPAWNER_NODE_IDS:
			var key := _connection_key(vertex)
			var start_sprite := Sprite2D.new()
			start_sprite.texture = load(_STARTS + "start_" + _dir_name(key) + ".svg")
			tile.add_child(start_sprite)

		add_child(tile)

	# Single cpu sprite centered on the 2x2 block, scaled to cover 2x2 tiles.
	var tl := _graph.get_node_by_id(CPU_NODE_IDS[0])
	var br := _graph.get_node_by_id(CPU_NODE_IDS[3])
	if tl == null or br == null:
		return

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
		spawner.tiles_by_node_id = _tiles_by_node_id
		return spawner

	if vertex.id in CPU_NODE_IDS:
		return CoreTile.new()

	return BaseTile.new()


func _connection_key(vertex: GraphVertex) -> int:
	var key := 0
	for nid: int in vertex.neighbour_ids:
		var nv := _graph.get_node_by_id(nid)
		if nv == null:
			continue
		var diff := nv.position - vertex.position
		if diff.x > 0.0:
			key |= 2
		elif diff.x < 0.0:
			key |= 1
		elif diff.y < 0.0:
			key |= 8
		else:
			key |= 4
	return key


func _dir_name(key: int) -> String:
	return ("N" if key & 8 else "") + ("S" if key & 4 else "") + \
		   ("E" if key & 2 else "") + ("W" if key & 1 else "")
