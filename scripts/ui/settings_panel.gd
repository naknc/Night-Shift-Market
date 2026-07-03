extends Control
class_name SettingsPanel

signal closed()

var _volume_slider: HSlider
var _sensitivity_slider: HSlider
var _invert_y_toggle: CheckButton
var _fps_toggle: CheckButton
var _language_option: OptionButton
var _title_label: Label
var _subtitle_label: Label
var _language_label: Label
var _master_volume_label: Label
var _sensitivity_label: Label
var _reset_button: Button
var _close_button: Button
var _is_loading_language: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_load_current_values()
	_apply_localized_text()


func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.ACTION_PAUSE):
		closed.emit()
		queue_free()


func _build_interface() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	LocalizationManager.locale_changed.connect(_on_locale_changed)

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

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86))
	column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.72))
	column.add_child(_subtitle_label)

	column.add_child(_build_language_row())
	column.add_child(_build_slider_row("_master_volume_label", "_volume_slider", -30.0, 6.0, 0.5))
	column.add_child(_build_slider_row("_sensitivity_label", "_sensitivity_slider", 0.05, 1.0, 0.01))
	column.add_child(_build_toggle_row("_invert_y_toggle"))
	column.add_child(_build_toggle_row("_fps_toggle"))

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 12)
	column.add_child(button_row)

	_reset_button = _build_button("", Color(0.55, 0.33, 0.16), Color(1.0, 0.95, 0.88))
	_reset_button.pressed.connect(_on_restore_defaults_pressed)
	_attach_button_feedback(_reset_button)
	button_row.add_child(_reset_button)

	_close_button = _build_button("", Color(0.86, 0.72, 0.56), Color(0.18, 0.10, 0.05))
	_close_button.pressed.connect(_on_close_pressed)
	_attach_button_feedback(_close_button)
	button_row.add_child(_close_button)

	_volume_slider.value_changed.connect(_on_master_volume_changed)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_invert_y_toggle.toggled.connect(_on_invert_y_toggled)
	_fps_toggle.toggled.connect(_on_fps_toggled)
	_language_option.item_selected.connect(_on_language_selected)


func _load_current_values() -> void:
	_volume_slider.value = AudioManager.get_master_volume_db()
	_sensitivity_slider.value = InputManager.get_look_sensitivity()
	_invert_y_toggle.button_pressed = InputManager.is_invert_y_enabled()
	_fps_toggle.button_pressed = PerformanceManager.is_show_fps_enabled()
	_refresh_language_options()


func _build_language_row() -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)

	_language_label = Label.new()
	_language_label.add_theme_font_size_override("font_size", 18)
	_language_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.84))
	wrapper.add_child(_language_label)

	_language_option = OptionButton.new()
	_language_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(_language_option)
	return wrapper


func _build_slider_row(label_property_name: String, slider_property_name: String, min_value: float, max_value: float, step: float) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.84))
	wrapper.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(slider)

	set(label_property_name, label)
	set(slider_property_name, slider)
	return wrapper


func _build_toggle_row(property_name: String) -> Control:
	var toggle := CheckButton.new()
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


func _attach_button_feedback(button: BaseButton) -> void:
	button.pivot_offset = button.size * 0.5
	button.resized.connect(func() -> void:
		button.pivot_offset = button.size * 0.5
	)
	button.button_down.connect(func() -> void:
		_animate_button_state(button, true)
	)
	button.button_up.connect(func() -> void:
		_animate_button_state(button, false)
	)
	button.pressed.connect(func() -> void:
		_animate_button_state(button, false)
	)
	button.mouse_exited.connect(func() -> void:
		_animate_button_state(button, false)
	)


func _animate_button_state(button: Control, is_pressed: bool) -> void:
	if button == null:
		return
	if not button.has_meta("rest_position"):
		button.set_meta("rest_position", button.position)
	var target_scale := Vector2.ONE
	var target_position := button.get_meta("rest_position") as Vector2
	if is_pressed:
		target_scale = Vector2(0.975, 0.975)
		target_position = (button.get_meta("rest_position") as Vector2) + Vector2(0.0, 4.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.08)
	tween.parallel().tween_property(button, "position", target_position, 0.08)


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
	LocalizationManager.apply_saved_locale()
	AudioManager.initialize_from_settings()
	InputManager.apply_saved_settings()
	PerformanceManager.apply_startup_profile()
	_load_current_values()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _on_locale_changed(_locale_code: StringName, _is_rtl: bool) -> void:
	_apply_localized_text()
	_refresh_language_options()


func _apply_localized_text() -> void:
	LocalizationManager.apply_control_locale(self)
	_title_label.text = LocalizationManager.text(&"settings.title")
	_subtitle_label.text = LocalizationManager.text(&"settings.subtitle")
	_language_label.text = LocalizationManager.text(&"settings.language")
	_master_volume_label.text = LocalizationManager.text(&"settings.master_volume")
	_sensitivity_label.text = LocalizationManager.text(&"settings.look_sensitivity")
	_invert_y_toggle.text = LocalizationManager.text(&"settings.invert_vertical_look")
	_fps_toggle.text = LocalizationManager.text(&"settings.show_fps_overlay")
	_reset_button.text = LocalizationManager.text(&"settings.restore_defaults")
	_close_button.text = LocalizationManager.text(&"settings.close")


func _refresh_language_options() -> void:
	if _language_option == null:
		return

	_is_loading_language = true
	_language_option.clear()

	var system_locale := LocalizationManager.get_system_locale()
	var system_label := LocalizationManager.text(
		&"settings.system_default",
		{"language": LocalizationManager.get_locale_display_name(system_locale)}
	)
	_language_option.add_item(system_label)
	_language_option.set_item_metadata(0, String(LocalizationManager.DEFAULT_LANGUAGE_PREFERENCE))

	var selected_index := 0
	var current_preference := LocalizationManager.get_language_preference()
	var locales := LocalizationManager.get_supported_locales()
	for entry_index in locales.size():
		var entry: Dictionary = locales[entry_index]
		var locale_code := StringName(String(entry.get("code", "")))
		var display_name := String(entry.get("native_name", entry.get("display_name", String(locale_code))))
		var option_index := entry_index + 1
		_language_option.add_item(display_name)
		_language_option.set_item_metadata(option_index, String(locale_code))
		if current_preference == locale_code:
			selected_index = option_index

	_language_option.select(selected_index)
	_is_loading_language = false


func _on_language_selected(index: int) -> void:
	if _is_loading_language:
		return
	var metadata: Variant = _language_option.get_item_metadata(index)
	LocalizationManager.set_language_preference(StringName(String(metadata)))
