class_name LevelDefinition
extends Resource

@export var title: String = "Level"
@export var board_scene: PackedScene
@export var tilemap_path: NodePath = ^"TileMap"
@export var tilemap_layer: int = 0
@export var require_mutual_connections: bool = true
@export_range(1.0, 600.0, 1.0, "suffix:s") var duration_seconds: float = 60.0
@export var spawn_cfg: SpawnerCfg
