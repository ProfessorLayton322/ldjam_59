class_name SpawnEnemyManager
extends Node

signal level_completed

const DebugTrace := preload("res://scripts/debug_trace.gd")

const TUTORIAL_CRYTTER_SCENE := preload("res://scenes/enemies/crytter.tscn")

@export var cfg: SpawnerCfg

var _spawners: Array[SpawnerTile] = []
var _timer: Timer
var _rng := RandomNumberGenerator.new()
var _active_enemy_ids := {}
var _defeated_enemy_ids := {}
var _spawned_enemy_count := 0
var _spawning_complete := false
var _level_completed_emitted := false


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
	_reset_completion_tracking()
	EnemiesSpawnConfig.prepare_for_current_level()
	_ensure_timer()
	DebugTrace.event("spawn_manager", "start", {
		"tutorial": TutorialEvents.should_run_first_level_tutorial(),
		"spawner_count": _spawners.size(),
		"tick": _get_tick(),
	})
	if TutorialEvents.should_run_first_level_tutorial():
		_start_first_level_tutorial_spawn()
		return

	_start_regular_spawn_timer("level_start")


func stop() -> void:
	if _timer != null:
		_timer.stop()
	DebugTrace.event("spawn_manager", "stop", {"has_timer": _timer != null})


func spawn_next_enemy_type(enemy_type: int) -> bool:
	_ensure_timer()
	if _timer != null:
		_timer.stop()
	_prune_spawners()
	if _spawners.is_empty():
		DebugTrace.event("spawn_manager", "forced_spawn:no_spawners", {"enemy_type": enemy_type})
		return false
	if not EnemiesSpawnConfig.ensure_next_enemy_type(enemy_type):
		DebugTrace.event("spawn_manager", "forced_spawn:no_enemy_type", {"enemy_type": enemy_type})
		return false
	var next_enemy_type := EnemiesSpawnConfig.take_next_enemy_type()
	if next_enemy_type == -1:
		DebugTrace.event("spawn_manager", "forced_spawn:no_enemies_left", {"enemy_type": enemy_type})
		return false
	var available_spawners := _spawners.duplicate()
	_spawn_enemy_type(next_enemy_type, available_spawners)
	DebugTrace.event("spawn_manager", "forced_spawn:done", {"enemy_type": next_enemy_type})
	return true


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
	if not _timer.timeout.is_connected(_spawn_next_batch):
		_timer.timeout.connect(_spawn_next_batch)


func _spawn_next_batch() -> void:
	_prune_spawners()
	if _spawners.is_empty():
		DebugTrace.event("spawn_manager", "spawn_batch:no_spawners", {})
		return

	var enemy_types := EnemiesSpawnConfig.take_next_enemy_types()
	if enemy_types.is_empty():
		_mark_spawning_complete("empty_batch")
		DebugTrace.event("spawn_manager", "spawn_batch:no_enemies_left", {})
		return

	var available_spawners := _spawners.duplicate()
	for enemy_type in enemy_types:
		if available_spawners.is_empty():
			available_spawners = _spawners.duplicate()
		_spawn_enemy_type(enemy_type, available_spawners)

	if not EnemiesSpawnConfig.has_enemies_left():
		_mark_spawning_complete("all_configured_enemies_spawned")


func _spawn_enemy_type(enemy_type: int, available_spawners: Array) -> void:
	var spawner_index := _rng.randi_range(0, available_spawners.size() - 1)
	var spawner := available_spawners[spawner_index] as SpawnerTile
	available_spawners.remove_at(spawner_index)
	if spawner == null:
		return

	spawner.enemy_scene = EnemiesSpawnConfig.get_enemy_scene(enemy_type)
	DebugTrace.event("spawn_manager", "spawn_batch:selected", {
		"spawner": DebugTrace.node_state(spawner),
		"enemy_type": enemy_type,
		"enemy_scene": spawner.enemy_scene.resource_path if spawner.enemy_scene != null else "",
	})
	spawner.OnTrigger(self)
	_track_spawned_enemy(spawner.last_spawned_enemy)


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
	_track_spawned_enemy(spawner.last_spawned_enemy)
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

	if not TutorialEvents.first_level_tutorial_finished.is_connected(_on_first_level_tutorial_finished):
		TutorialEvents.first_level_tutorial_finished.connect(_on_first_level_tutorial_finished)


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


func _on_first_level_tutorial_finished() -> void:
	DebugTrace.event("spawn_manager", "first_level_tutorial_finished", {})
	_start_regular_spawn_timer("first_level_tutorial_finished")


func _start_regular_spawn_timer(reason: String) -> void:
	if _timer == null:
		return

	EnemiesSpawnConfig.ensure_prepared_for_current_level()
	if not EnemiesSpawnConfig.has_enemies_left():
		_mark_spawning_complete("all_configured_enemies_spawned")
		DebugTrace.event("spawn_manager", "regular_timer_not_started:no_enemies", {"reason": reason})
		return

	_timer.wait_time = _get_tick()
	_timer.start()
	DebugTrace.event("spawn_manager", "regular_timer_started", {"tick": _get_tick(), "reason": reason})


func _reset_completion_tracking() -> void:
	_active_enemy_ids.clear()
	_defeated_enemy_ids.clear()
	_spawned_enemy_count = 0
	_spawning_complete = false
	_level_completed_emitted = false


func _track_spawned_enemy(enemy: Enemy) -> void:
	if enemy == null:
		return

	var enemy_id := enemy.get_instance_id()
	if _active_enemy_ids.has(enemy_id):
		return

	_active_enemy_ids[enemy_id] = true
	_spawned_enemy_count += 1
	if not enemy.defeated.is_connected(_on_enemy_defeated):
		enemy.defeated.connect(_on_enemy_defeated)
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy_id), CONNECT_ONE_SHOT)
	DebugTrace.event("spawn_manager", "track_enemy", {
		"enemy": DebugTrace.enemy_state(enemy),
		"active_count": _active_enemy_ids.size(),
		"spawned_count": _spawned_enemy_count,
	})


func _on_enemy_defeated(enemy: Enemy) -> void:
	if enemy == null:
		return

	var enemy_id := enemy.get_instance_id()
	_defeated_enemy_ids[enemy_id] = true
	DebugTrace.event("spawn_manager", "enemy_defeated", {
		"enemy": DebugTrace.enemy_state(enemy),
		"defeated_count": _defeated_enemy_ids.size(),
		"spawned_count": _spawned_enemy_count,
	})


func _on_enemy_tree_exited(enemy_id: int) -> void:
	_active_enemy_ids.erase(enemy_id)
	DebugTrace.event("spawn_manager", "enemy_exited", {
		"enemy_id": enemy_id,
		"active_count": _active_enemy_ids.size(),
		"defeated_count": _defeated_enemy_ids.size(),
		"spawned_count": _spawned_enemy_count,
	})
	_check_level_completed()


func _mark_spawning_complete(reason: String) -> void:
	if _timer != null:
		_timer.stop()
	_spawning_complete = true
	DebugTrace.event("spawn_manager", "spawning_complete", {
		"reason": reason,
		"active_count": _active_enemy_ids.size(),
		"defeated_count": _defeated_enemy_ids.size(),
		"spawned_count": _spawned_enemy_count,
	})
	_check_level_completed()


func _check_level_completed() -> void:
	if _level_completed_emitted:
		return
	if not _spawning_complete:
		return
	if not _active_enemy_ids.is_empty():
		return

	_level_completed_emitted = true
	DebugTrace.event("spawn_manager", "level_completed", {
		"spawned_count": _spawned_enemy_count,
		"defeated_count": _defeated_enemy_ids.size(),
		"non_defeated_exit_count": _spawned_enemy_count - _defeated_enemy_ids.size(),
	})
	level_completed.emit()


func _prune_spawners() -> void:
	for i in range(_spawners.size() - 1, -1, -1):
		if not is_instance_valid(_spawners[i]):
			DebugTrace.event("spawn_manager", "prune_spawner", {"index": i})
			_spawners.remove_at(i)


func _get_tick() -> float:
	return EnemiesSpawnConfig.get_spawn_interval()
