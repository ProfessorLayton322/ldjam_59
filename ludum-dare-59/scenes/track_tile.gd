@tool
class_name WireTile
extends BaseTile

@export var north: bool = false:
	set(value):
		north = value
		_update_track()

@export var south: bool = false:
	set(value):
		south = value
		_update_track()

@export var east: bool = false:
	set(value):
		east = value
		_update_track()

@export var west: bool = false:
	set(value):
		west = value
		_update_track()

const TRACKS := "res://assets/textures/tracks/"


func _ready() -> void:
	_update_track()


func OnTrigger(source: Node = null) -> void:
	super.OnTrigger(source)


func OnEnter(source: Node = null) -> void:
	super.OnEnter(source)


func _update_track() -> void:
	var track_node: Sprite2D = $Track if has_node("Track") else null
	if not track_node:
		return

	var key := int(north) * 8 + int(south) * 4 + int(east) * 2 + int(west)

	var tex := ""
	var rot := 0.0

	match key:
		0b1100:
			tex = TRACKS + "track_straight_v.svg"
		0b0011:
			tex = TRACKS + "track_straight_h.svg"
		0b1000, 0b0100:
			tex = TRACKS + "track_straight_v.svg"
		0b0010, 0b0001:
			tex = TRACKS + "track_straight_h.svg"
		0b0110:
			tex = TRACKS + "track_corner_ne.svg"
			rot = 90.0
		0b0101:
			tex = TRACKS + "track_corner_ne.svg"
			rot = 180.0
		0b1001:
			tex = TRACKS + "track_corner_ne.svg"
			rot = 270.0
		0b1010:
			tex = TRACKS + "track_corner_ne.svg"
			rot = 0.0
		0b1011:
			tex = TRACKS + "track_t_junction.svg"
			rot = 180.0
		0b1110:
			tex = TRACKS + "track_t_junction.svg"
			rot = -90
		0b0111:
			tex = TRACKS + "track_t_junction.svg"
		0b1101:
			tex = TRACKS + "track_t_junction.svg"
			rot = 90.0
		0b1111:
			tex = TRACKS + "track_cross.svg"

	if tex.is_empty():
		track_node.texture = null
	else:
		track_node.texture = load(tex)
	track_node.rotation_degrees = rot
