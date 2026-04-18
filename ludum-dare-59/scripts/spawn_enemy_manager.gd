class_name SpawnEnemyManager
extends Node

const TUTORIAL_CRYTTER_SCENE := preload("res://scenes/enemies/crytter.tscn")

@export var cfg: SpawnerCfg

var _spawners: Array[SpawnerTile] = []
var _timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if cfg == null:
		cfg = BalanceManager.get_params().default_spawner_cfg
	_ensure_timer()


func register_spawner(spawner: SpawnerTile) -> void:
	if spawner == null or _spawners.has(spawner):
		return

	_spawners.append(spawner)


func unregister_spawner(spawner: SpawnerTile) -> void:
	_spawners.erase(spawner)


func clear_spawners() -> void:
	_spawners.clear()


func start() -> void:
	_ensure_timer()
	if TutorialEvents.should_run_first_level_tutorial():
		_start_first_level_tutorial_spawn()
		return

	_timer.wait_time = _get_tick()
	_timer.start()


func stop() -> void:
	if _timer != null:
		_timer.stop()


func _ensure_timer() -> void:
	if _timer != null:
		return

	_timer = get_node_or_null("SpawnTimer") as Timer
	if _timer == null:
		_timer = Timer.new()
		_timer.name = "SpawnTimer"
		add_child(_timer)

	_timer.one_shot = false
	_timer.autostart = false
	_timer.wait_time = _get_tick()
	if not _timer.timeout.is_connected(_spawn_from_random_spawner):
		_timer.timeout.connect(_spawn_from_random_spawner)


func _spawn_from_random_spawner() -> void:
	_prune_spawners()
	if _spawners.is_empty():
		return

	var spawner := _spawners[_rng.randi_range(0, _spawners.size() - 1)]
	if cfg != null and not cfg.enemy_scenes.is_empty():
		spawner.enemy_scene = cfg.enemy_scenes[_rng.randi_range(0, cfg.enemy_scenes.size() - 1)]
	spawner.OnTrigger(self)


func _start_first_level_tutorial_spawn() -> void:
	_timer.stop()
	_prune_spawners()
	if _spawners.is_empty():
		return

	var spawner := _spawners[0]
	_ensure_tutorial_spawner_target(spawner)
	spawner.enemy_scene = TUTORIAL_CRYTTER_SCENE
	spawner.OnTrigger(self)
	var enemy := spawner.last_spawned_enemy
	if enemy != null:
		enemy.mark_as_first_tutorial_crytter()
		TutorialEvents.emit_first_crytter_spawned(enemy, spawner.node_id)

	if not TutorialEvents.first_crytter_despawned.is_connected(_on_tutorial_first_crytter_despawned):
		TutorialEvents.first_crytter_despawned.connect(_on_tutorial_first_crytter_despawned)


func _ensure_tutorial_spawner_target(spawner: SpawnerTile) -> void:
	if spawner == null or not spawner.cpu_vertices.is_empty():
		return

	var target_node_id := _find_farthest_reachable_node_id(spawner.graph, spawner.node_id)
	if target_node_id == -1:
		return

	var cpu := CpuVertex.new()
	cpu.node_id = target_node_id
	spawner.cpu_vertices = [cpu]


func _find_farthest_reachable_node_id(graph: Graph, start_node_id: int) -> int:
	if graph == null or graph.get_node_by_id(start_node_id) == null:
		return -1

	var queue: Array[int] = [start_node_id]
	var visited := {start_node_id: 0}
	var farthest_node_id := start_node_id

	while not queue.is_empty():
		var node_id: int = queue.pop_front()
		var distance: int = visited[node_id]
		if distance > int(visited[farthest_node_id]):
			farthest_node_id = node_id

		var vertex := graph.get_node_by_id(node_id)
		if vertex == null:
			continue

		for neighbour_id in vertex.neighbour_ids:
			if visited.has(neighbour_id):
				continue

			visited[neighbour_id] = distance + 1
			queue.append(neighbour_id)

	return farthest_node_id

func _on_tutorial_first_crytter_despawned(_enemy: Enemy) -> void:
	if _timer == null:
		return

	_timer.wait_time = _get_tick()
	_timer.start()


func _prune_spawners() -> void:
	for i in range(_spawners.size() - 1, -1, -1):
		if not is_instance_valid(_spawners[i]):
			_spawners.remove_at(i)


func _get_tick() -> float:
	if cfg == null:
		return 1.0

	return maxf(cfg.tick, 0.01)
