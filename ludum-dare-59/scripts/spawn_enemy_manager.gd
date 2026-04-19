class_name SpawnEnemyManager
extends Node

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


func _prune_spawners() -> void:
	for i in range(_spawners.size() - 1, -1, -1):
		if not is_instance_valid(_spawners[i]):
			_spawners.remove_at(i)


func _get_tick() -> float:
	if cfg == null:
		return 1.0

	return maxf(cfg.tick, 0.01)
