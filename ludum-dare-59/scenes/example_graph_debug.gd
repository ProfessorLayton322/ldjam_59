extends Node2D

@export var tilemap_path: NodePath = ^"TileMap"
@export var tilemap_layer: int = 0
@export var require_mutual_connections: bool = true


func _ready() -> void:
	var level := get_node_or_null(tilemap_path)
	if level == null:
		push_error("Graph debug: level TileMap not found at %s" % tilemap_path)
		return

	var graph := Graph.new()
	graph.build_from_level(level, tilemap_layer, require_mutual_connections)

	print("Graph debug: parsed %d vertices from %s" % [graph.nodes.size(), level.get_path()])
	_print_graph_dfs(graph)


func _print_graph_dfs(graph: Graph) -> void:
	var visited := {}

	for vertex in graph.nodes:
		if visited.has(vertex.id):
			continue

		print("DFS component from vertex %d" % vertex.id)
		_print_vertex_dfs(graph, vertex.id, visited, 0)


func _print_vertex_dfs(graph: Graph, vertex_id: int, visited: Dictionary, depth: int) -> void:
	if visited.has(vertex_id):
		return

	var vertex := graph.get_node_by_id(vertex_id)
	if vertex == null:
		return

	visited[vertex_id] = true
	print("%s- id=%d degree=%d pos=%s neighbours=%s" % [
		"  ".repeat(depth),
		vertex.id,
		vertex.neighbour_ids.size(),
		vertex.position,
		vertex.neighbour_ids,
	])
	if vertex.neighbour_ids.size() != 2:
		push_warning("Graph debug: vertex %d has %d neighbours, expected 2 for loop tracks" % [
			vertex.id,
			vertex.neighbour_ids.size(),
		])

	for neighbour_id in vertex.neighbour_ids:
		_print_vertex_dfs(graph, neighbour_id, visited, depth + 1)
