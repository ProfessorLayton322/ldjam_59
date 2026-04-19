class_name Hud
extends CanvasLayer

signal settings_closed
signal resume_pressed

const WebFullscreen := preload("res://scripts/web_fullscreen.gd")

var _game_over_panel: Panel
var _victory_panel: Panel
var _pause_overlay: ColorRect
var _settings_panel: Panel
var _pause_menu_panel: Panel
var _fullscreen_button: Button

var _settings_focusables: Array[Control] = []
var _pause_focusables: Array[Control] = []
var _game_over_focusables: Array[Control] = []
var _victory_focusables: Array[Control] = []
var _focus_idx: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pause_overlay()
	_build_game_over_panel()
	_build_victory_panel()
	_build_settings_panel()
	_build_pause_menu_panel()


func set_paused(paused: bool) -> void:
	_pause_overlay.visible = paused


func show_pause_menu() -> void:
	_pause_menu_panel.visible = true
	_focus_idx = 0
	if not _pause_focusables.is_empty():
		_pause_focusables[0].grab_focus()


func hide_pause_menu() -> void:
	_pause_menu_panel.visible = false


func is_pause_menu_open() -> bool:
	return _pause_menu_panel != null and _pause_menu_panel.visible


func is_settings_open() -> bool:
	return _settings_panel != null and _settings_panel.visible


func show_settings() -> void:
	_settings_panel.visible = true
	_update_fullscreen_button()
	_focus_idx = 0
	if not _settings_focusables.is_empty():
		_settings_focusables[0].grab_focus()


func hide_settings() -> void:
	_settings_panel.visible = false
	settings_closed.emit()


func show_game_over() -> void:
	_game_over_panel.visible = true
	_focus_idx = 0
	if not _game_over_focusables.is_empty():
		_game_over_focusables[0].grab_focus()


func show_victory() -> void:
	_victory_panel.visible = true
	_focus_idx = 0


func hide_victory() -> void:
	_victory_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var active: Array[Control] = []
	if is_settings_open():
		active = _settings_focusables
	elif is_pause_menu_open():
		active = _pause_focusables
	elif _game_over_panel != null and _game_over_panel.visible:
		active = _game_over_focusables
	elif _victory_panel != null and _victory_panel.visible:
		active = _victory_focusables
	if active.is_empty():
		return
	match event.keycode:
		KEY_W, KEY_UP:
			_focus_idx = (_focus_idx - 1 + active.size()) % active.size()
			active[_focus_idx].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_S, KEY_DOWN:
			_focus_idx = (_focus_idx + 1) % active.size()
			active[_focus_idx].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_A, KEY_LEFT:
			var item := active[_focus_idx]
			if item is HSlider:
				(item as HSlider).value = clamp((item as HSlider).value - 0.05, (item as HSlider).min_value, (item as HSlider).max_value)
				get_viewport().set_input_as_handled()
		KEY_D, KEY_RIGHT:
			var item := active[_focus_idx]
			if item is HSlider:
				(item as HSlider).value = clamp((item as HSlider).value + 0.05, (item as HSlider).min_value, (item as HSlider).max_value)
				get_viewport().set_input_as_handled()


func _build_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.0, 0.2, 0.8, 0.25)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	add_child(_pause_overlay)


func _build_game_over_panel() -> void:
	_game_over_panel = Panel.new()
	_game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.visible = false
	add_child(_game_over_panel)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var retry_btn := Button.new()
	retry_btn.text = "Retry"
	retry_btn.custom_minimum_size = Vector2(160, 40)
	retry_btn.pressed.connect(_on_retry_pressed)
	vbox.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(160, 40)
	menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(menu_btn)

	_game_over_focusables = [retry_btn, menu_btn]


func _build_victory_panel() -> void:
	_victory_panel = Panel.new()
	_victory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_panel.visible = false
	add_child(_victory_panel)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Victory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	_victory_focusables = []


func _build_settings_panel() -> void:
	_settings_panel = Panel.new()
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	_settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings_panel)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var fullhd_btn := Button.new()
	fullhd_btn.text = "Full HD (1920×1080)"
	fullhd_btn.custom_minimum_size = Vector2(220, 40)
	fullhd_btn.pressed.connect(func(): ResolutionManager.set_resolution(ResolutionManager.Resolution.FULL_HD))
	vbox.add_child(fullhd_btn)

	var fourkbtn := Button.new()
	fourkbtn.text = "4K (3840×2160)"
	fourkbtn.custom_minimum_size = Vector2(220, 40)
	fourkbtn.pressed.connect(func(): ResolutionManager.set_resolution(ResolutionManager.Resolution.FOUR_K))
	vbox.add_child(fourkbtn)

	if WebFullscreen.is_available():
		_fullscreen_button = Button.new()
		_fullscreen_button.text = "Fullscreen"
		_fullscreen_button.custom_minimum_size = Vector2(220, 40)
		_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
		vbox.add_child(_fullscreen_button)

	var vol_spacer := Control.new()
	vol_spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(vol_spacer)

	var vol_label := Label.new()
	vol_label.text = "Volume"
	vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(vol_label)

	for bus_data: Array in [["Master", "master"], ["Music", "music"], ["SFX", "sfx"]]:
		var bus_display: String = bus_data[0]
		var bus_key: String = bus_data[1]
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(220, 0)
		vbox.add_child(row)
		var lbl := Label.new()
		lbl.text = bus_display
		lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value = _load_volume(bus_key)
		slider.value_changed.connect(_apply_and_save_volume.bind(bus_display, bus_key))
		row.add_child(slider)
		_settings_focusables.append(slider)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer2)

	var back_btn := Button.new()
	back_btn.text = "Back to Game"
	back_btn.custom_minimum_size = Vector2(220, 40)
	back_btn.pressed.connect(hide_settings)
	vbox.add_child(back_btn)

	var sliders := _settings_focusables.duplicate()
	_settings_focusables.clear()
	_settings_focusables.append(fullhd_btn)
	_settings_focusables.append(fourkbtn)
	if _fullscreen_button != null:
		_settings_focusables.append(_fullscreen_button)
	_settings_focusables.append_array(sliders)
	_settings_focusables.append(back_btn)

	var _update_res_buttons := func() -> void:
		if not is_instance_valid(fullhd_btn) or not is_instance_valid(fourkbtn):
			return
		var is_4k := ResolutionManager.current == ResolutionManager.Resolution.FOUR_K
		fullhd_btn.disabled = not is_4k
		fourkbtn.disabled = is_4k

	_update_res_buttons.call()
	ResolutionManager.resolution_changed.connect(func(_r): _update_res_buttons.call())


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


func _build_pause_menu_panel() -> void:
	_pause_menu_panel = Panel.new()
	_pause_menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu_panel.visible = false
	_pause_menu_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_menu_panel)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(160, 40)
	resume_btn.pressed.connect(_on_pause_menu_resume_pressed)
	vbox.add_child(resume_btn)

	var retry_btn := Button.new()
	retry_btn.text = "Retry"
	retry_btn.custom_minimum_size = Vector2(160, 40)
	retry_btn.pressed.connect(_on_retry_pressed)
	vbox.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Exit to Menu"
	menu_btn.custom_minimum_size = Vector2(160, 40)
	menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(menu_btn)

	_pause_focusables = [resume_btn, retry_btn, menu_btn]


func _on_pause_menu_resume_pressed() -> void:
	resume_pressed.emit()


func _on_retry_pressed() -> void:
	AudioManager.play_ui_interaction()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ld_gameplay.tscn")


func _on_menu_pressed() -> void:
	AudioManager.play_ui_interaction()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _load_volume(key: String) -> float:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return 1.0
	return cfg.get_value("volume", key, 1.0)


func _apply_and_save_volume(value: float, bus_name: String, key: String) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), linear_to_db(value))
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("volume", key, value)
	cfg.save("user://settings.cfg")
