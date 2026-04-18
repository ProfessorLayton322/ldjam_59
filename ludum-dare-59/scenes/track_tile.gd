@tool
extends Node2D

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

func _update_track() -> void:
	var track_node: Sprite2D = $Track if has_node("Track") else null
	if not track_node:
		return

	var key := int(north) * 8 + int(south) * 4 + int(east) * 2 + int(west)

	var tex := ""
	var rot := 0.0

	match key:
		0b1100:  # N+S
			tex = TRACKS + "track_straight_v.svg"
		0b0011:  # E+W
			tex = TRACKS + "track_straight_h.svg"
		0b1000, 0b0100:  # N or S dead-end
			tex = TRACKS + "track_straight_v.svg"
		0b0010, 0b0001:  # E or W dead-end
			tex = TRACKS + "track_straight_h.svg"
		0b0110:  # S+E — default orientation
			tex = TRACKS + "track_corner_ne.svg"
		0b0101:  # S+W — rotate 90° CW
			tex = TRACKS + "track_corner_ne.svg"
			rot = 90.0
		0b1001:  # N+W — rotate 180°
			tex = TRACKS + "track_corner_ne.svg"
			rot = 180.0
		0b1010:  # N+E — rotate 270° CW
			tex = TRACKS + "track_corner_ne.svg"
			rot = 270.0
		# T-junctions: default asset assumed to connect N+E+W (missing S)
		0b1011:  # N+E+W
			tex = TRACKS + "track_t_junction.svg"
			rot = 180.0
		0b1110:  # N+S+E
			tex = TRACKS + "track_t_junction.svg"
			rot = -90
		0b0111:  # S+E+W
			tex = TRACKS + "track_t_junction.svg"
		0b1101:  # N+S+W
			tex = TRACKS + "track_t_junction.svg"
			rot = 90.0
		0b1111:  # all four
			tex = TRACKS + "track_cross.svg"

	if tex.is_empty():
		track_node.texture = null
	else:
		track_node.texture = load(tex)
	track_node.rotation_degrees = rot
