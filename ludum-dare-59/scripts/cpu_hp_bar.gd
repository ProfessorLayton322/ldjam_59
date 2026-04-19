extends Node2D

const BAR_SIZE := Vector2(250, 18)
const COLOR_BG := Color(0.1, 0.05, 0.05)
const COLOR_FILL := Color(0.55, 0.05, 0.05)

var _current: int = 1
var _maximum: int = 1


func set_hp(current: int, maximum: int) -> void:
	_current = current
	_maximum = maximum
	queue_redraw()


func _draw() -> void:
	var damage_ratio := 1.0 - float(_current) / float(_maximum) if _maximum > 0 else 1.0
	var origin := Vector2(-BAR_SIZE.x / 2.0, 0.0)

	draw_rect(Rect2(origin, BAR_SIZE), COLOR_BG)

	if damage_ratio > 0.0:
		draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * damage_ratio, BAR_SIZE.y)), COLOR_FILL)

	draw_rect(Rect2(origin, BAR_SIZE), Color.WHITE, false)
