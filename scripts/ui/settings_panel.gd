extends Control
class_name SettingsPanel

signal closed()

var _volume_slider: HSlider
var _sensitivity_slider: HSlider
var _invert_y_toggle: CheckButton
var _fps_toggle: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_load_current_values()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.ACTION_PAUSE):
		closed.emit()
		queue_free()


func _build_interface() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.18, 0.12, 0.08, 0.98)))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "These preferences persist immediately and are shared across every session."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.95, 0.84, 0.72))
	column.add_child(subtitle)

	column.add_child(_build_slider_row("Master Volume", -30.0, 6.0, 0.5, "_volume_slider"))
	column.add_child(_build_slider_row("Look Sensitivity", 0.05, 1.0, 0.01, "_sensitivity_slider"))
	column.add_child(_build_toggle_row("Invert Vertical Look", "_invert_y_toggle"))
	column.add_child(_build_toggle_row("Show FPS Overlay", "_fps_toggle"))

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 12)
	column.add_child(button_row)

	var reset_button := _build_button("Restore Defaults", Color(0.55, 0.33, 0.16), Color(1.0, 0.95, 0.88))
	reset_button.pressed.connect(_on_restore_defaults_pressed)
	button_row.add_child(reset_button)

	var close_button := _build_button("Close", Color(0.86, 0.72, 0.56), Color(0.18, 0.10, 0.05))
	close_button.pressed.connect(_on_close_pressed)
	button_row.add_child(close_button)

	_volume_slider.value_changed.connect(_on_master_volume_changed)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_invert_y_toggle.toggled.connect(_on_invert_y_toggled)
	_fps_toggle.toggled.connect(_on_fps_toggled)


func _load_current_values() -> void:
	_volume_slider.value = AudioManager.get_master_volume_db()
	_sensitivity_slider.value = InputManager.get_look_sensitivity()
	_invert_y_toggle.button_pressed = InputManager.is_invert_y_enabled()
	_fps_toggle.button_pressed = PerformanceManager.is_show_fps_enabled()


func _build_slider_row(title_text: String, min_value: float, max_value: float, step: float, property_name: String) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.84))
	wrapper.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(slider)

	set(property_name, slider)
	return wrapper


func _build_toggle_row(title_text: String, property_name: String) -> Control:
	var toggle := CheckButton.new()
	toggle.text = title_text
	toggle.add_theme_font_size_override("font_size", 18)
	toggle.add_theme_color_override("font_color", Color(1.0, 0.93, 0.84))
	set(property_name, toggle)
	return toggle


func _build_button(text_value: String, background_color: Color, font_color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 50.0)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_stylebox_override("normal", _build_button_style(background_color))
	button.add_theme_stylebox_override("hover", _build_button_style(background_color.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _build_button_style(background_color.darkened(0.08)))
	button.add_theme_stylebox_override("focus", _build_button_style(background_color.lightened(0.12)))
	return button


func _build_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.border_color = Color(1.0, 0.96, 0.90, 0.08)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	return style


func _build_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _on_master_volume_changed(value: float) -> void:
	AudioManager.set_master_volume_db(value)


func _on_sensitivity_changed(value: float) -> void:
	InputManager.set_look_sensitivity(value)


func _on_invert_y_toggled(enabled: bool) -> void:
	InputManager.set_invert_y(enabled)


func _on_fps_toggled(enabled: bool) -> void:
	PerformanceManager.set_show_fps(enabled)


func _on_restore_defaults_pressed() -> void:
	SaveManager.reset_settings_to_default()
	AudioManager.initialize_from_settings()
	InputManager.apply_saved_settings()
	PerformanceManager.apply_startup_profile()
	_load_current_values()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
