extends Control

const CONFIG_PATH := "user://settings.cfg"
const VOLUME_SECTION := "volume"
const WebFullscreen := preload("res://scripts/web_fullscreen.gd")

var _focusables: Array[Control] = []
var _focus_idx: int = 0
var _fullscreen_button: Button


func _ready() -> void:
	$VBoxContainer/FullHDButton.pressed.connect(_on_fullhd_pressed)
	$VBoxContainer/FourKButton.pressed.connect(_on_4k_pressed)
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	_update_buttons()
	ResolutionManager.resolution_changed.connect(_on_resolution_changed)

	_load_volumes()
	$VBoxContainer/MasterRow/MasterSlider.value_changed.connect(_on_master_changed)
	$VBoxContainer/MusicRow/MusicSlider.value_changed.connect(_on_music_changed)
	$VBoxContainer/SFXRow/SFXSlider.value_changed.connect(_on_sfx_changed)

	_add_web_fullscreen_button()
	_focusables = [
		$VBoxContainer/FullHDButton,
		$VBoxContainer/FourKButton,
		$VBoxContainer/MasterRow/MasterSlider,
		$VBoxContainer/MusicRow/MusicSlider,
		$VBoxContainer/SFXRow/SFXSlider,
		$VBoxContainer/BackButton,
	]
	if _fullscreen_button != null:
		_focusables.insert(_focusables.size() - 1, _fullscreen_button)
	_focus_idx = 0
	_focusables[0].grab_focus()


func _on_fullhd_pressed() -> void:
	AudioManager.play_ui_interaction()
	ResolutionManager.set_resolution(ResolutionManager.Resolution.FULL_HD)


func _on_4k_pressed() -> void:
	AudioManager.play_ui_interaction()
	ResolutionManager.set_resolution(ResolutionManager.Resolution.FOUR_K)


func _on_back_pressed() -> void:
	AudioManager.play_ui_interaction()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _add_web_fullscreen_button() -> void:
	if not WebFullscreen.is_available():
		return
	_fullscreen_button = Button.new()
	_fullscreen_button.name = "FullscreenButton"
	_fullscreen_button.layout_mode = 2
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	$VBoxContainer.add_child(_fullscreen_button)
	$VBoxContainer.move_child(_fullscreen_button, $VBoxContainer/BackButton.get_index())
	_update_fullscreen_button()


func _on_fullscreen_pressed() -> void:
	AudioManager.play_ui_interaction()
	WebFullscreen.toggle()
	_update_fullscreen_button_deferred()


func _update_fullscreen_button_deferred() -> void:
	_update_fullscreen_button()
	await get_tree().create_timer(0.25).timeout
	_update_fullscreen_button()


func _update_fullscreen_button() -> void:
	if _fullscreen_button == null:
		return
	_fullscreen_button.text = "Exit Fullscreen" if WebFullscreen.is_fullscreen() else "Fullscreen"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_W, KEY_UP:
			_focus_idx = (_focus_idx - 1 + _focusables.size()) % _focusables.size()
			_focusables[_focus_idx].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_S, KEY_DOWN:
			_focus_idx = (_focus_idx + 1) % _focusables.size()
			_focusables[_focus_idx].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_A, KEY_LEFT:
			_adjust_focused_slider(-0.05)
			get_viewport().set_input_as_handled()
		KEY_D, KEY_RIGHT:
			_adjust_focused_slider(0.05)
			get_viewport().set_input_as_handled()


func _adjust_focused_slider(delta: float) -> void:
	var item := _focusables[_focus_idx]
	if item is HSlider:
		(item as HSlider).value = clamp((item as HSlider).value + delta, (item as HSlider).min_value, (item as HSlider).max_value)


func _on_resolution_changed(_res: ResolutionManager.Resolution) -> void:
	_update_buttons()


func _update_buttons() -> void:
	var is_4k := ResolutionManager.current == ResolutionManager.Resolution.FOUR_K
	$VBoxContainer/FullHDButton.disabled = !is_4k
	$VBoxContainer/FourKButton.disabled = is_4k


func _slider_to_db(value: float) -> float:
	if value <= 0.0:
		return -80.0
	return lerp(-60.0, 0.0, value)


func _on_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), _slider_to_db(value))
	_save_volumes()


func _on_music_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _slider_to_db(value))
	_save_volumes()


func _on_sfx_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _slider_to_db(value))
	_save_volumes()


func _save_volumes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(VOLUME_SECTION, "master", $VBoxContainer/MasterRow/MasterSlider.value)
	cfg.set_value(VOLUME_SECTION, "music", $VBoxContainer/MusicRow/MusicSlider.value)
	cfg.set_value(VOLUME_SECTION, "sfx", $VBoxContainer/SFXRow/SFXSlider.value)
	cfg.save(CONFIG_PATH)


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	var master: float = cfg.get_value(VOLUME_SECTION, "master", 1.0)
	var music: float = cfg.get_value(VOLUME_SECTION, "music", 1.0)
	var sfx: float = cfg.get_value(VOLUME_SECTION, "sfx", 1.0)
	$VBoxContainer/MasterRow/MasterSlider.value = master
	$VBoxContainer/MusicRow/MusicSlider.value = music
	$VBoxContainer/SFXRow/SFXSlider.value = sfx
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), _slider_to_db(master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _slider_to_db(music))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _slider_to_db(sfx))
