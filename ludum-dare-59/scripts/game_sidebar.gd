extends CanvasLayer

signal gate_button_pressed(definition: Resource, button: Button)
signal pause_toggled
signal victory_debug_requested
signal menu_pressed
signal settings_pressed

const CpuHpBarScene := preload("res://scripts/cpu_hp_bar.gd")

var _root: Control
var _gate_buttons: Dictionary = {}
var _pause_button: Button
var _menu_button: Button
var _settings_button: Button
var _debug_victory_button: Button
var _temperature_meter: TextureProgressBar
var _temperature_label: Label
var _temperature_wrapper: Control


func build(gate_definitions: Array, cpu_regions: Array, cpu_hp: int) -> void:
	name = "UI"
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.name = "Root"
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	for i in gate_definitions.size():
		var definition: Resource = gate_definitions[i]
		var button := Button.new()
		button.name = "%sButton" % definition.id.capitalize().replace(" ", "")
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.icon = definition.icon_texture if definition.icon_texture != null else definition.texture
		button.expand_icon = true
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "%s: %d power" % [definition.display_name, definition.power_cost]
		button.custom_minimum_size = Vector2(64.0, 64.0)
		button.anchor_left = 1.0
		button.anchor_right = 1.0
		button.offset_left = -92.0
		button.offset_top = 16.0 + float(i) * 72.0
		button.offset_right = -28.0
		button.offset_bottom = button.offset_top + 64.0
		button.pressed.connect(Callable(self, "_on_gate_button_pressed").bind(definition, button))
		_root.add_child(button)
		_gate_buttons[definition.id] = button
		_add_key_hint(str(i + 1), button.offset_top)
		_add_cost_hint(definition.power_cost, button.offset_top)

	var pause_btn := Button.new()
	pause_btn.name = "PauseButton"
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.text = "II"
	pause_btn.toggle_mode = true
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.tooltip_text = "Pause / resume"
	pause_btn.custom_minimum_size = Vector2(64.0, 64.0)
	pause_btn.anchor_left = 1.0
	pause_btn.anchor_right = 1.0
	pause_btn.offset_left = -92.0
	pause_btn.offset_top = 16.0 + float(gate_definitions.size()) * 72.0
	pause_btn.offset_right = -28.0
	pause_btn.offset_bottom = pause_btn.offset_top + 64.0
	pause_btn.pressed.connect(Callable(self, "_on_pause_toggled"))
	_root.add_child(pause_btn)
	_pause_button = pause_btn
	_add_key_hint("Spc", pause_btn.offset_top)

	_build_temperature_meter(gate_definitions.size())
	_build_debug_victory_button(gate_definitions.size())
	_build_cpu_hp_bars(cpu_regions, cpu_hp)
	_build_top_left_buttons()


func get_gate_button(id: String) -> Button:
	return _gate_buttons.get(id) as Button


func get_pause_button() -> Button:
	return _pause_button


func get_temperature_meter() -> Control:
	return _temperature_wrapper


func get_debug_victory_button() -> Button:
	return _debug_victory_button


func is_point_over_debug_victory_button(global_position: Vector2) -> bool:
	if _debug_victory_button == null or not is_instance_valid(_debug_victory_button):
		return false
	if _debug_victory_button.disabled or not _debug_victory_button.visible:
		return false
	return _debug_victory_button.get_global_rect().has_point(global_position)


func set_pause_button_state(pressed: bool) -> void:
	if _pause_button != null:
		_pause_button.set_pressed_no_signal(pressed)


func set_player_controls_disabled(disabled: bool) -> void:
	if _root == null:
		return
	for node: Node in _root.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button.name == "DebugVictoryButton":
			continue
		button.disabled = disabled


func set_menu_settings_buttons_disabled(disabled: bool) -> void:
	if _menu_button != null:
		_menu_button.disabled = disabled
	if _settings_button != null:
		_settings_button.disabled = disabled


func update_temperature(current: float, maximum: int) -> void:
	if _temperature_meter != null:
		_temperature_meter.max_value = float(maximum)
		_temperature_meter.value = current
	if _temperature_label != null:
		_temperature_label.text = "%.1f/%d" % [current, maximum]


func _on_gate_button_pressed(definition: Resource, button: Button) -> void:
	gate_button_pressed.emit(definition, button)


func _on_pause_toggled() -> void:
	pause_toggled.emit()


func _on_victory_debug_pressed() -> void:
	AudioManager.play_ui_interaction()
	victory_debug_requested.emit()


func _add_key_hint(key_text: String, top_offset: float, btn_left: float = -92.0) -> void:
	var hint := Label.new()
	hint.text = "[%s]" % key_text
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.add_theme_font_size_override("font_size", 11)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = btn_left - 36.0
	hint.offset_right = btn_left
	hint.offset_top = top_offset + 26.0
	hint.offset_bottom = top_offset + 44.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(hint)


func _add_cost_hint(cost: int, btn_top: float) -> void:
	var label := Label.new()
	label.text = "%d°" % cost
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 13)
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -26.0
	label.offset_right = -4.0
	label.offset_top = btn_top + 22.0
	label.offset_bottom = btn_top + 42.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(label)


func _build_cpu_hp_bars(cpu_regions: Array, cpu_hp: int) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	const BAR_W := 250.0
	const BAR_MARGIN := 20.0
	var region_count := cpu_regions.size()
	var total_width := float(region_count) * BAR_W + float(region_count - 1) * BAR_MARGIN
	var start_x := (viewport_size.x - total_width) / 2.0

	for i in region_count:
		var bar := CpuHpBarScene.new()
		bar.position = Vector2(start_x + float(i) * (BAR_W + BAR_MARGIN) + BAR_W / 2.0, 28.0)
		add_child(bar)
		bar.set_hp(cpu_regions[i]["hp"], cpu_hp)
		cpu_regions[i]["bar"] = bar


func _build_temperature_meter(gate_count: int) -> void:
	var bar_top := 16.0 + float(gate_count) * 72.0 + 64.0 + 8.0 + 160.0

	var wrapper := Control.new()
	wrapper.name = "PowerMeterWrapper"
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.anchor_left = 1.0
	wrapper.anchor_right = 1.0
	wrapper.offset_left = -83.0
	wrapper.offset_right = -43.0
	wrapper.offset_top = bar_top
	wrapper.offset_bottom = bar_top + 296.0
	_root.add_child(wrapper)
	_temperature_wrapper = wrapper

	var bar := TextureProgressBar.new()
	bar.name = "PowerMeter"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	bar.offset_top = 0.0
	bar.offset_bottom = 160.0
	bar.texture_under = preload("res://assets/textures/interface/temperature_bar_background.png")
	bar.texture_progress = preload("res://assets/textures/interface/temperature_bar_value.png")
	bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	bar.nine_patch_stretch = true
	bar.pivot_offset = Vector2(20.0, 80.0)
	bar.scale = Vector2(1.5, 3.0)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	wrapper.add_child(bar)
	_temperature_meter = bar

	var bar_visual_bottom_local := bar.pivot_offset.y * (1.0 - bar.scale.y) + 160.0 * bar.scale.y

	var label := Label.new()
	label.name = "PowerLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = bar_visual_bottom_local - 34.0
	label.offset_bottom = bar_visual_bottom_local - 24.0
	label.scale = Vector2(0.75, 0.75)
	wrapper.add_child(label)
	_temperature_label = label


func _build_top_left_buttons() -> void:
	var menu_btn := Button.new()
	menu_btn.name = "MenuButton"
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.text = "Menu"
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.tooltip_text = "Return to main menu (Esc)"
	menu_btn.custom_minimum_size = Vector2(80.0, 36.0)
	menu_btn.anchor_left = 0.0
	menu_btn.anchor_right = 0.0
	menu_btn.offset_left = 16.0
	menu_btn.offset_top = 16.0
	menu_btn.offset_right = 96.0
	menu_btn.offset_bottom = 52.0
	menu_btn.pressed.connect(Callable(self, "_on_menu_pressed"))
	_root.add_child(menu_btn)
	_menu_button = menu_btn

	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_btn.text = "Settings"
	settings_btn.focus_mode = Control.FOCUS_NONE
	settings_btn.tooltip_text = "Open settings"
	settings_btn.custom_minimum_size = Vector2(80.0, 36.0)
	settings_btn.anchor_left = 0.0
	settings_btn.anchor_right = 0.0
	settings_btn.offset_left = 16.0
	settings_btn.offset_top = 60.0
	settings_btn.offset_right = 96.0
	settings_btn.offset_bottom = 96.0
	settings_btn.pressed.connect(Callable(self, "_on_settings_pressed"))
	_root.add_child(settings_btn)
	_settings_button = settings_btn


func _on_menu_pressed() -> void:
	menu_pressed.emit()


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _build_debug_victory_button(gate_count: int) -> void:
	if not OS.is_debug_build():
		return

	var button := Button.new()
	button.name = "DebugVictoryButton"
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.text = "Win"
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Debug: finish this level with victory"
	button.custom_minimum_size = Vector2(64.0, 40.0)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -92.0
	button.offset_top = 16.0 + float(gate_count) * 72.0 + 64.0 + 8.0 + 160.0 + 12.0
	button.offset_right = -28.0
	button.offset_bottom = button.offset_top + 40.0
	button.pressed.connect(Callable(self, "_on_victory_debug_pressed"))
	_root.add_child(button)
	_debug_victory_button = button
