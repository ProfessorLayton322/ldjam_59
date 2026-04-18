class_name Graph
extends Resource

var nodes: Array[GraphVertex] = []


func get_node_by_id(node_id: int) -> GraphVertex:
	for node in nodes:
		if node.id == node_id:
			return node

	return null


func add_node(node: GraphVertex) -> void:
	if node == null:
		return

	nodes.append(node)


func clear() -> void:
	nodes.clear()


func build_from_grid(size: Vector2i, tile_size: Vector2, origin: Vector2 = Vector2.ZERO) -> void:
	clear()

	if size.x <= 0 or size.y <= 0:
		return

	for y in size.y:
		for x in size.x:
			var node_id := _get_grid_node_id(x, y, size.x)
			var center := origin + Vector2(
				(float(x) + 0.5) * tile_size.x,
				(float(y) + 0.5) * tile_size.y
			)

			nodes.append(GraphVertex.new(node_id, center, _get_grid_neighbour_ids(x, y, size)))


func _get_grid_node_id(x: int, y: int, width: int) -> int:
	return y * width + x


func _get_grid_neighbour_ids(x: int, y: int, size: Vector2i) -> Array[int]:
	var neighbours: Array[int] = []

	if y < size.y - 1:
		neighbours.append(_get_grid_node_id(x, y + 1, size.x))

	if y > 0:
		neighbours.append(_get_grid_node_id(x, y - 1, size.x))

	if x > 0:
		neighbours.append(_get_grid_node_id(x - 1, y, size.x))

	if x < size.x - 1:
		neighbours.append(_get_grid_node_id(x + 1, y, size.x))

	return neighbours
