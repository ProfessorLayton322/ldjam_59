class_name SpawnEnemyManager
extends Node

const DebugTrace := preload("res://scripts/debug_trace.gd")

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
		DebugTrace.event("spawn_manager", "register_spawner:skipped", {
			"spawner": DebugTrace.node_state(spawner),
			"already_registered": spawner != null and _spawners.has(spawner),
		})
		return

	_spawners.append(spawner)
	DebugTrace.event("spawn_manager", "register_spawner:done", {"spawner": DebugTrace.node_state(spawner), "count": _spawners.size()})


func unregister_spawner(spawner: SpawnerTile) -> void:
	_spawners.erase(spawner)
	DebugTrace.event("spawn_manager", "unregister_spawner", {"spawner": DebugTrace.node_state(spawner), "count": _spawners.size()})


func clear_spawners() -> void:
	_spawners.clear()
	DebugTrace.event("spawn_manager", "clear_spawners", {})


func start() -> void:
	_ensure_timer()
	DebugTrace.event("spawn_manager", "start", {
		"tutorial": TutorialEvents.should_run_first_level_tutorial(),
		"spawner_count": _spawners.size(),
		"tick": _get_tick(),
	})
	if TutorialEvents.should_run_first_level_tutorial():
		_start_first_level_tutorial_spawn()
		return

	_timer.wait_time = _get_tick()
	_timer.start()


func stop() -> void:
	if _timer != null:
		_timer.stop()
	DebugTrace.event("spawn_manager", "stop", {"has_timer": _timer != null})


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
		DebugTrace.event("spawn_manager", "spawn_random:no_spawners", {})
		return

	var spawner := _spawners[_rng.randi_range(0, _spawners.size() - 1)]
	if cfg != null and not cfg.enemy_scenes.is_empty():
		spawner.enemy_scene = cfg.enemy_scenes[_rng.randi_range(0, cfg.enemy_scenes.size() - 1)]
	DebugTrace.event("spawn_manager", "spawn_random:selected", {
		"spawner": DebugTrace.node_state(spawner),
		"enemy_scene": spawner.enemy_scene.resource_path if spawner.enemy_scene != null else "",
	})
	spawner.OnTrigger(self)


func _start_first_level_tutorial_spawn() -> void:
	_timer.stop()
	_prune_spawners()
	if _spawners.is_empty():
		DebugTrace.event("spawn_manager", "tutorial_spawn:no_spawners", {})
		return

	var spawner := _spawners[0]
	DebugTrace.event("spawn_manager", "tutorial_spawn:selected", {"spawner": DebugTrace.node_state(spawner)})
	_ensure_tutorial_spawner_target(spawner)
	spawner.enemy_scene = TUTORIAL_CRYTTER_SCENE
	spawner.OnTrigger(self)
	var enemy := spawner.last_spawned_enemy
	if enemy != null:
		enemy.mark_as_first_tutorial_crytter()
		TutorialEvents.emit_first_crytter_spawned(enemy, spawner.node_id)
		DebugTrace.event("spawn_manager", "tutorial_spawn:emitted_first_crytter", {
			"spawner": DebugTrace.node_state(spawner),
			"enemy": DebugTrace.enemy_state(enemy),
			"spawner_node_id": spawner.node_id,
		})
	else:
		DebugTrace.event("spawn_manager", "tutorial_spawn:no_enemy_after_trigger", {"spawner": DebugTrace.node_state(spawner)})

	if not TutorialEvents.first_crytter_despawned.is_connected(_on_tutorial_first_crytter_despawned):
		TutorialEvents.first_crytter_despawned.connect(_on_tutorial_first_crytter_despawned)


func _ensure_tutorial_spawner_target(spawner: SpawnerTile) -> void:
	if spawner == null or not spawner.cpu_vertices.is_empty():
		DebugTrace.event("spawn_manager", "ensure_tutorial_spawner_target:skipped", {
			"spawner": DebugTrace.node_state(spawner),
			"cpu_vertices_count": spawner.cpu_vertices.size() if spawner != null else 0,
		})
		return

	var target_node_id := _find_farthest_reachable_node_id(spawner.graph, spawner.node_id)
	if target_node_id == -1:
		DebugTrace.event("spawn_manager", "ensure_tutorial_spawner_target:no_target", {"spawner": DebugTrace.node_state(spawner)})
		return

	var cpu := CpuVertex.new()
	cpu.node_id = target_node_id
	spawner.cpu_vertices = [cpu]
	DebugTrace.event("spawn_manager", "ensure_tutorial_spawner_target:done", {
		"spawner": DebugTrace.node_state(spawner),
		"target_node_id": target_node_id,
	})


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
	DebugTrace.event("spawn_manager", "tutorial_first_crytter_despawned", {"enemy": DebugTrace.enemy_state(_enemy)})
	if _timer == null:
		return

	_timer.wait_time = _get_tick()
	_timer.start()
	DebugTrace.event("spawn_manager", "tutorial_first_crytter_despawned:timer_started", {"tick": _get_tick()})


func _prune_spawners() -> void:
	for i in range(_spawners.size() - 1, -1, -1):
		if not is_instance_valid(_spawners[i]):
			DebugTrace.event("spawn_manager", "prune_spawner", {"index": i})
			_spawners.remove_at(i)


func _get_tick() -> float:
	if cfg == null:
		return 1.0

	return maxf(cfg.tick, 0.01)
