extends Camera2D

const ZOOM_STEP := 1.15
const ZOOM_MIN := Vector2(0.25, 0.25)
const ZOOM_MAX := Vector2(4.0, 4.0)

var _panning := false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var factor := ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
			var old_zoom := zoom
			var new_zoom: Vector2 = (old_zoom * factor).clamp(ZOOM_MIN, ZOOM_MAX)
			var mouse_screen := get_viewport().get_mouse_position()
			var viewport_center := get_viewport_rect().size / 2.0
			var offset := mouse_screen - viewport_center
			position += offset / old_zoom - offset / new_zoom
			zoom = new_zoom
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _panning:
		var motion := event as InputEventMouseMotion
		position -= motion.relative
		get_viewport().set_input_as_handled()
