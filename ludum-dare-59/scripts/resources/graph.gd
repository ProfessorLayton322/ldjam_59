class_name Graph
extends Resource

var nodes: Array[GraphVertex] = []

const CONNECTION_MASK_NORTH := 8
const CONNECTION_MASK_SOUTH := 4
const CONNECTION_MASK_EAST := 2
const CONNECTION_MASK_WEST := 1


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


func build_from_tilemap_layer(tilemap_layer: TileMapLayer, require_mutual_connections: bool = true, use_global_positions: bool = false) -> void:
	clear()

	if tilemap_layer == null:
		return

	var cells := tilemap_layer.get_used_cells()
	if cells.is_empty():
		return

	var cell_to_id := _get_tilemap_cell_ids(tilemap_layer, cells)
	cells.sort_custom(_sort_cells_row_major)

	for cell in cells:
		var position := tilemap_layer.map_to_local(cell)
		if use_global_positions:
			position = tilemap_layer.to_global(position)

		nodes.append(GraphVertex.new(
			cell_to_id[cell],
			position,
			_get_tilemap_neighbour_ids(tilemap_layer, cell, cell_to_id, require_mutual_connections)
		))


func build_from_tilemap(tilemap: TileMap, layer: int = 0, require_mutual_connections: bool = true, use_global_positions: bool = false) -> void:
	clear()

	if tilemap == null:
		return

	var cells := tilemap.get_used_cells(layer)
	if cells.is_empty():
		return

	var cell_to_id := _get_legacy_tilemap_cell_ids(tilemap, cells)
	cells.sort_custom(_sort_cells_row_major)

	for cell in cells:
		var position := tilemap.map_to_local(cell)
		if use_global_positions:
			position = tilemap.to_global(position)

		nodes.append(GraphVertex.new(
			cell_to_id[cell],
			position,
			_get_legacy_tilemap_neighbour_ids(tilemap, layer, cell, cell_to_id, require_mutual_connections)
		))


func build_from_level(level: Node, layer: int = 0, require_mutual_connections: bool = true, use_global_positions: bool = false) -> void:
	if level is TileMapLayer:
		build_from_tilemap_layer(level as TileMapLayer, require_mutual_connections, use_global_positions)
	elif level is TileMap:
		build_from_tilemap(level as TileMap, layer, require_mutual_connections, use_global_positions)
	else:
		clear()


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


func _get_tilemap_cell_ids(tilemap_layer: TileMapLayer, cells: Array[Vector2i]) -> Dictionary:
	var cell_to_id := {}
	var used_rect := tilemap_layer.get_used_rect()

	for cell in cells:
		cell_to_id[cell] = _get_grid_node_id(
			cell.x - used_rect.position.x,
			cell.y - used_rect.position.y,
			used_rect.size.x
		)

	return cell_to_id


func _get_legacy_tilemap_cell_ids(tilemap: TileMap, cells: Array[Vector2i]) -> Dictionary:
	var cell_to_id := {}
	var used_rect := tilemap.get_used_rect()

	for cell in cells:
		cell_to_id[cell] = _get_grid_node_id(
			cell.x - used_rect.position.x,
			cell.y - used_rect.position.y,
			used_rect.size.x
		)

	return cell_to_id


func _get_tilemap_neighbour_ids(tilemap_layer: TileMapLayer, cell: Vector2i, cell_to_id: Dictionary, require_mutual_connections: bool) -> Array[int]:
	var neighbours: Array[int] = []

	for direction: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbour_cell: Vector2i = cell + direction
		if not cell_to_id.has(neighbour_cell):
			continue
		if not _tile_allows_direction(tilemap_layer, cell, direction):
			continue
		if require_mutual_connections and not _tile_allows_direction(tilemap_layer, neighbour_cell, -direction):
			continue

		neighbours.append(cell_to_id[neighbour_cell])

	return neighbours


func _get_legacy_tilemap_neighbour_ids(tilemap: TileMap, layer: int, cell: Vector2i, cell_to_id: Dictionary, require_mutual_connections: bool) -> Array[int]:
	var neighbours: Array[int] = []

	for direction: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbour_cell: Vector2i = cell + direction
		if not cell_to_id.has(neighbour_cell):
			continue
		if not _legacy_tile_allows_direction(tilemap, layer, cell, direction):
			continue
		if require_mutual_connections and not _legacy_tile_allows_direction(tilemap, layer, neighbour_cell, -direction):
			continue

		neighbours.append(cell_to_id[neighbour_cell])

	return neighbours


func _tile_allows_direction(tilemap_layer: TileMapLayer, cell: Vector2i, direction: Vector2i) -> bool:
	var scene_tile_mask := _get_tilemap_layer_scene_tile_mask(tilemap_layer, cell)
	if scene_tile_mask >= 0:
		return (scene_tile_mask & _get_direction_mask(direction)) != 0

	var tile_data := tilemap_layer.get_cell_tile_data(cell)
	if tile_data == null:
		return false

	var direction_name := _get_direction_name(direction)
	var custom_data_found := false

	for name in ["north", "south", "east", "west"]:
		var value: Variant = _get_tile_custom_data(tilemap_layer, tile_data, name)
		if value != null:
			custom_data_found = true
			if name == direction_name:
				return _custom_data_is_enabled(value)

	var connections: Variant = _get_tile_custom_data(tilemap_layer, tile_data, "connections")
	if connections != null:
		return _connections_include_direction(connections, direction_name, _get_direction_abbreviation(direction))

	var connection_mask: Variant = _get_tile_custom_data(tilemap_layer, tile_data, "connection_mask")
	if connection_mask != null:
		return (int(connection_mask) & _get_direction_mask(direction)) != 0

	return not custom_data_found


func _legacy_tile_allows_direction(tilemap: TileMap, layer: int, cell: Vector2i, direction: Vector2i) -> bool:
	var scene_tile_mask := _get_legacy_tilemap_scene_tile_mask(tilemap, layer, cell)
	if scene_tile_mask >= 0:
		return (scene_tile_mask & _get_direction_mask(direction)) != 0

	var tile_data := tilemap.get_cell_tile_data(layer, cell)
	if tile_data == null:
		return false

	var direction_name := _get_direction_name(direction)
	var custom_data_found := false

	for name in ["north", "south", "east", "west"]:
		var value: Variant = _get_legacy_tile_custom_data(tilemap, tile_data, name)
		if value != null:
			custom_data_found = true
			if name == direction_name:
				return _custom_data_is_enabled(value)

	var connections: Variant = _get_legacy_tile_custom_data(tilemap, tile_data, "connections")
	if connections != null:
		return _connections_include_direction(connections, direction_name, _get_direction_abbreviation(direction))

	var connection_mask: Variant = _get_legacy_tile_custom_data(tilemap, tile_data, "connection_mask")
	if connection_mask != null:
		return (int(connection_mask) & _get_direction_mask(direction)) != 0

	return not custom_data_found


func _get_tile_custom_data(tilemap_layer: TileMapLayer, tile_data: TileData, data_name: String) -> Variant:
	if tilemap_layer.tile_set == null:
		return null
	if not _tileset_has_custom_data_layer(tilemap_layer.tile_set, data_name):
		return null

	return tile_data.get_custom_data(data_name)


func _get_legacy_tile_custom_data(tilemap: TileMap, tile_data: TileData, data_name: String) -> Variant:
	if tilemap.tile_set == null:
		return null
	if not _tileset_has_custom_data_layer(tilemap.tile_set, data_name):
		return null

	return tile_data.get_custom_data(data_name)


func _get_tilemap_layer_scene_tile_mask(tilemap_layer: TileMapLayer, cell: Vector2i) -> int:
	if tilemap_layer.tile_set == null:
		return -1

	var source_id := tilemap_layer.get_cell_source_id(cell)
	if source_id < 0:
		return -1

	var source := tilemap_layer.tile_set.get_source(source_id)
	if not (source is TileSetScenesCollectionSource):
		return -1

	return tilemap_layer.get_cell_alternative_tile(cell)


func _get_legacy_tilemap_scene_tile_mask(tilemap: TileMap, layer: int, cell: Vector2i) -> int:
	if tilemap.tile_set == null:
		return -1

	var source_id := tilemap.get_cell_source_id(layer, cell)
	if source_id < 0:
		return -1

	var source := tilemap.tile_set.get_source(source_id)
	if not (source is TileSetScenesCollectionSource):
		return -1

	return tilemap.get_cell_alternative_tile(layer, cell)


func _tileset_has_custom_data_layer(tile_set: TileSet, data_name: String) -> bool:
	for index in range(tile_set.get_custom_data_layers_count()):
		if tile_set.get_custom_data_layer_name(index) == data_name:
			return true

	return false


func _custom_data_is_enabled(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String or value is StringName:
		var text := String(value).strip_edges().to_lower()
		return text in ["1", "true", "yes", "y", "on"]

	return value != null


func _connections_include_direction(connections: Variant, direction_name: String, abbreviation: String) -> bool:
	if connections is Dictionary:
		if connections.has(direction_name):
			return _custom_data_is_enabled(connections[direction_name])
		if connections.has(abbreviation):
			return _custom_data_is_enabled(connections[abbreviation])
		if connections.has(abbreviation.to_upper()):
			return _custom_data_is_enabled(connections[abbreviation.to_upper()])
		return false

	if connections is String or connections is StringName:
		var text := String(connections).strip_edges().to_lower()
		if text in ["all", "any", "*"]:
			return true

		var parts := text.split(",", false)
		if parts.size() == 1:
			parts = text.split(" ", false)

		for part in parts:
			var normalized := part.strip_edges()
			if normalized == direction_name or normalized == abbreviation:
				return true

		return abbreviation in text

	if connections is Array or connections is PackedStringArray:
		for item in connections:
			var text := String(item).strip_edges().to_lower()
			if text == direction_name or text == abbreviation:
				return true

	return false


func _get_direction_name(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "north"
	if direction == Vector2i.DOWN:
		return "south"
	if direction == Vector2i.RIGHT:
		return "east"
	if direction == Vector2i.LEFT:
		return "west"

	return ""


func _get_direction_abbreviation(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "n"
	if direction == Vector2i.DOWN:
		return "s"
	if direction == Vector2i.RIGHT:
		return "e"
	if direction == Vector2i.LEFT:
		return "w"

	return ""


func _get_direction_mask(direction: Vector2i) -> int:
	if direction == Vector2i.UP:
		return CONNECTION_MASK_NORTH
	if direction == Vector2i.DOWN:
		return CONNECTION_MASK_SOUTH
	if direction == Vector2i.RIGHT:
		return CONNECTION_MASK_EAST
	if direction == Vector2i.LEFT:
		return CONNECTION_MASK_WEST

	return 0


func _sort_cells_row_major(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x

	return a.y < b.y
