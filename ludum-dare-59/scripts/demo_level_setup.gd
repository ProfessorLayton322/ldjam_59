extends RefCounted

const POSITION_MATCH_EPSILON := 1.0

var level: LevelDefinition
var trigger_timer_path: NodePath
var spawn_enemy_manager_path: NodePath
var demo: Node2D
var graph: Graph

var level_board: Node
var tiles: Array[BaseTile] = []
var tiles_by_node_id: Dictionary = {}
var cpu_node_ids: Dictionary = {}
var cpu_regions: Array[Dictionary] = []
var spawn_enemy_manager: SpawnEnemyManager


func instantiate_level_board() -> bool:
	if level == null:
		level_board = demo
		print("Demo scene: using embedded level board from %s" % demo.scene_file_path)
		return true

	if level.board_scene == null:
		push_error("Demo scene: LevelDefinition '%s' has no board_scene." % level.title)
		return false

	level_board = level.board_scene.instantiate()
	level_board.name = "LevelBoard"
	demo.add_child(level_board)
	print("Demo scene: loaded level '%s' from %s" % [level.title, level.board_scene.resource_path])
	return true


func build_graph() -> void:
	if level_board == null:
		return

	var tilemap_path := ^"TileMap" if level == null else level.tilemap_path
	var tilemap_layer := 0 if level == null else level.tilemap_layer
	var require_mutual_connections := true if level == null else level.require_mutual_connections
	var level_title := "embedded" if level == null else level.title

	var tilemap := level_board.get_node_or_null(tilemap_path)
	if tilemap == null:
		push_error("Demo scene: TileMap not found at %s in level %s" % [tilemap_path, level_title])
		return

	print("Demo scene: parsing graph from %s layer %d" % [tilemap.get_path(), tilemap_layer])
	graph.build_from_level(tilemap, tilemap_layer, require_mutual_connections, true)
	if graph.nodes.is_empty():
		push_error("Demo scene: TileMap at %s produced an empty graph" % tilemap.get_path())
		return

	for vertex: GraphVertex in graph.nodes:
		vertex.position = demo.to_local(vertex.position)

	print("Demo scene: parsed %d graph nodes" % graph.nodes.size())


func collect_tiles() -> void:
	tiles = _find_tiles(level_board)
	tiles_by_node_id.clear()
	var spawner_count := 0
	var cpu_count := 0
	for tile: BaseTile in tiles:
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
		tiles_by_node_id.size(),
		spawner_count,
		cpu_count,
	])
	if level != null and level.expected_spawner_count >= 0 and spawner_count != level.expected_spawner_count:
		push_warning("Demo scene: expected %d spawner tiles from TileMap, found %d" % [
			level.expected_spawner_count,
			spawner_count,
		])


func build_cpu_vertices() -> Array[CpuVertex]:
	var cpu_vertices: Array[CpuVertex] = []
	_collect_cpu_node_ids()

	for node_id in cpu_node_ids:
		var cv := CpuVertex.new()
		cv.node_id = int(node_id)
		cpu_vertices.append(cv)
		print("Demo scene: CPU target registered for node %d" % cv.node_id)

	return cpu_vertices


func configure_spawners(cpu_vertices: Array[CpuVertex]) -> void:
	spawn_enemy_manager = demo.get_node_or_null(spawn_enemy_manager_path) as SpawnEnemyManager
	if spawn_enemy_manager == null:
		push_error("Demo scene: SpawnEnemyManager not found at %s" % spawn_enemy_manager_path)
		return

	if level != null and level.spawn_cfg != null:
		spawn_enemy_manager.cfg = level.spawn_cfg

	spawn_enemy_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	spawn_enemy_manager.clear_spawners()
	for tile: BaseTile in tiles:
		if not (tile is SpawnerTile):
			continue

		var spawner := tile as SpawnerTile
		spawner.graph = graph
		spawner.cpu_vertices = cpu_vertices
		spawner.spawn_parent = demo
		spawn_enemy_manager.register_spawner(spawner)
		print("Demo scene: wired spawner %s on node %d" % [spawner.get_path(), spawner.node_id])


func configure_core_gates(enemy_reached_callback: Callable, cpu_hp: int) -> void:
	var core_positions: Dictionary = {}
	for node_id in cpu_node_ids:
		var vertex: GraphVertex = graph.get_node_by_id(node_id)
		if vertex != null:
			core_positions[node_id] = vertex.position

	var visited: Dictionary = {}
	var region_groups: Array = []
	for node_id in cpu_node_ids:
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

	cpu_regions.clear()

	for region_index in region_groups.size():
		var region_ids: Array[int] = region_groups[region_index]
		var cpu_positions: Array[Vector2] = []

		for node_id in region_ids:
			var gate := CoreGate.new()
			demo.add_child(gate)
			gate.graph = graph
			gate.vertex_id = node_id
			gate.enemy_reached.connect(enemy_reached_callback.bind(region_index))
			var tile: BaseTile = tiles_by_node_id.get(node_id) as BaseTile
			if tile != null:
				cpu_positions.append(demo.to_local(tile.global_position))
			elif graph != null:
				var vertex := graph.get_node_by_id(node_id)
				if vertex != null:
					cpu_positions.append(vertex.position)
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

		cpu_regions.append({"hp": cpu_hp, "bar": null, "world_pos": Vector2(center_x, top_y)})


func _collect_cpu_node_ids() -> void:
	cpu_node_ids.clear()

	for tile in tiles_by_node_id.values():
		if tile is CoreTile:
			cpu_node_ids[tile.node_id] = true

	var tilemap := _get_level_tilemap()
	if tilemap == null or tilemap.tile_set == null:
		return

	var tilemap_layer := _get_level_tilemap_layer()
	var used_rect := tilemap.get_used_rect()
	if used_rect.size.x <= 0:
		return

	for cell in tilemap.get_used_cells(tilemap_layer):
		var source_id := tilemap.get_cell_source_id(tilemap_layer, cell)
		if not _is_cpu_tile_source(tilemap.tile_set, source_id):
			continue

		var node_id := (cell.y - used_rect.position.y) * used_rect.size.x + (cell.x - used_rect.position.x)
		if graph != null and graph.get_node_by_id(node_id) != null:
			cpu_node_ids[node_id] = true


func _get_level_tilemap() -> TileMap:
	if level_board == null:
		return null
	var tilemap_path := ^"TileMap" if level == null else level.tilemap_path
	return level_board.get_node_or_null(tilemap_path) as TileMap


func _get_level_tilemap_layer() -> int:
	return 0 if level == null else level.tilemap_layer


func _is_cpu_tile_source(tile_set: TileSet, source_id: int) -> bool:
	if tile_set == null or source_id < 0 or not tile_set.has_source(source_id):
		return false

	var source := tile_set.get_source(source_id)
	if String(source.resource_name).strip_edges().to_lower() == "cpu":
		return true

	if source is TileSetAtlasSource:
		var atlas_source := source as TileSetAtlasSource
		return atlas_source.texture != null and atlas_source.texture.resource_path.get_file().to_lower() == "cpu.svg"

	return false


func _find_tiles(root: Node) -> Array[BaseTile]:
	var found: Array[BaseTile] = []
	for child in root.get_children():
		if child is BaseTile:
			found.append(child)
		found.append_array(_find_tiles(child))
	return found


func _register_tile_for_node(tile: BaseTile) -> void:
	var existing := tiles_by_node_id.get(tile.node_id) as BaseTile
	if existing != null and _get_tile_lookup_priority(existing) > _get_tile_lookup_priority(tile):
		return
	tiles_by_node_id[tile.node_id] = tile


func _get_tile_lookup_priority(tile: BaseTile) -> int:
	if tile is SpawnerTile or tile is CoreTile:
		return 2
	if tile is WireTile:
		return 1
	return 0


func _assign_tile_node_id_from_graph(tile: BaseTile) -> void:
	var tile_position := demo.to_local(tile.global_position)
	var best_vertex: GraphVertex
	var best_distance := INF
	for vertex: GraphVertex in graph.nodes:
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
