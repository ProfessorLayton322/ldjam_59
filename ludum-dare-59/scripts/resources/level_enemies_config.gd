class_name LevelEnemiesConfig
extends Resource

@export_range(0, 1000, 1) var crytter_amount: int = 1
@export_range(0, 1000, 1) var stunner_amount: int = 0
@export_range(0, 1000, 1) var brute_amount: int = 0
@export_range(0.01, 600.0, 0.01, "suffix:s") var spawn_interval: float = 1.0
@export_range(1, 100, 1) var spawn_batch: int = 1
