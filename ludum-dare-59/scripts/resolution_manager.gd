extends Node

enum Resolution { FULL_HD, FOUR_K }

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "display"
const KEY := "resolution"

var current: int = Resolution.FULL_HD

signal resolution_changed(res: int)


func _ready() -> void:
	_load_config()
	_apply(current)


func set_resolution(res: int) -> void:
	if current == res:
		return
	current = res
	_apply(res)
	_save_config()
	resolution_changed.emit(res)


func _apply(res: int) -> void:
	var size: Vector2i
	match res:
		Resolution.FOUR_K:
			size = Vector2i(3840, 2160)
		_:
			size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(size)
	var win := get_window()
	win.content_scale_size = Vector2i(1920, 1080)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY, current)
	cfg.save(CONFIG_PATH)


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	current = cfg.get_value(SECTION, KEY, Resolution.FULL_HD)
