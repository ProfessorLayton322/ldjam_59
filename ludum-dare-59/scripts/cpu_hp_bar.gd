extends Node2D

const BAR_SIZE := Vector2(128, 10)
const COLOR_BG := Color(0.2, 0.2, 0.2)
const COLOR_FILL := Color(0.2, 0.8, 0.2)
const COLOR_LOW := Color(0.9, 0.2, 0.1)

var _current: int = 1
var _maximum: int = 1


func set_hp(current: int, maximum: int) -> void:
	_current = current
	_maximum = maximum
	queue_redraw()


func _draw() -> void:
	var fill_ratio := float(_current) / float(_maximum) if _maximum > 0 else 0.0
	var origin := Vector2(-BAR_SIZE.x / 2.0, 0.0)

	draw_rect(Rect2(origin, BAR_SIZE), COLOR_BG)

	if fill_ratio > 0.0:
		var fill_color := COLOR_FILL if fill_ratio > 0.3 else COLOR_LOW
		draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * fill_ratio, BAR_SIZE.y)), fill_color)

	draw_rect(Rect2(origin, BAR_SIZE), Color.WHITE, false)
