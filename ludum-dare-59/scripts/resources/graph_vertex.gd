class_name GraphVertex
extends RefCounted

var id: int = -1
var position: Vector2 = Vector2.ZERO
var neighbour_ids: Array[int] = []


func _init(vertex_id: int = -1, tile_center: Vector2 = Vector2.ZERO, neighbours: Array[int] = []) -> void:
	id = vertex_id
	position = tile_center
	neighbour_ids = neighbours.duplicate()
