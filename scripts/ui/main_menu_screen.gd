extends Control
class_name MainMenuScreen

signal new_game_requested()
signal continue_game_requested()
signal settings_requested()
signal exit_requested()

var _continue_button: Button
var _save_hint_label: Label
var _eyebrow_label: Label
var _title_label: Label
var _description_label: Label
var _info_label: Label
var _start_button: Button
var _settings_button: Button
var _exit_button: Button


func _ready() -> void:
	_build_interface()
	_apply_localized_text()
	refresh_state(SaveManager.has_save_data())


func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed)


func refresh_state(has_save: bool) -> void:
	if _continue_button != null:
		_continue_button.disabled = not has_save
	if _save_hint_label != null:
		_save_hint_label.visible = not has_save


func _build_interface() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	LocalizationManager.locale_changed.connect(_on_locale_changed)

	var background := ColorRect.new()
	background.color = Color(0.12, 0.08, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var safe_area := MarginContainer.new()
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 72)
	safe_area.add_theme_constant_override("margin_right", 72)
	safe_area.add_theme_constant_override("margin_top", 48)
	safe_area.add_theme_constant_override("margin_bottom", 48)
	add_child(safe_area)

	var root_box := HBoxContainer.new()
	root_box.add_theme_constant_override("separation", 32)
	safe_area.add_child(root_box)

	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.20, 0.13, 0.08, 0.92)))
	root_box.add_child(left_panel)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 40)
	left_margin.add_theme_constant_override("margin_right", 40)
	left_margin.add_theme_constant_override("margin_top", 40)
	left_margin.add_theme_constant_override("margin_bottom", 40)
	left_panel.add_child(left_margin)

	var left_content := VBoxContainer.new()
	left_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_content.add_theme_constant_override("separation", 18)
	left_margin.add_child(left_content)

	_eyebrow_label = Label.new()
	_eyebrow_label.add_theme_font_size_override("font_size", 18)
	_eyebrow_label.add_theme_color_override("font_color", Color(0.98, 0.77, 0.49))
	left_content.add_child(_eyebrow_label)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86))
	left_content.add_child(_title_label)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 22)
	_description_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.77))
	left_content.add_child(_description_label)

	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.32, 0.22, 0.14, 0.95)))
	left_content.add_child(info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 20)
	info_margin.add_theme_constant_override("margin_right", 20)
	info_margin.add_theme_constant_override("margin_top", 18)
	info_margin.add_theme_constant_override("margin_bottom", 18)
	info_panel.add_child(info_margin)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 18)
	_info_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.81))
	info_margin.add_child(_info_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_content.add_child(spacer)

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(360.0, 0.0)
	right_panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.95, 0.87, 0.76, 0.97)))
	root_box.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 28)
	right_margin.add_theme_constant_override("margin_right", 28)
	right_margin.add_theme_constant_override("margin_top", 28)
	right_margin.add_theme_constant_override("margin_bottom", 28)
	right_panel.add_child(right_margin)

	var button_column := VBoxContainer.new()
	button_column.alignment = BoxContainer.ALIGNMENT_CENTER
	button_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button_column.add_theme_constant_override("separation", 14)
	right_margin.add_child(button_column)

	_start_button = _build_action_button("", Color(0.36, 0.20, 0.10), Color(1.0, 0.95, 0.88))
	_start_button.pressed.connect(func() -> void:
		new_game_requested.emit()
	)
	_attach_button_feedback(_start_button)
	button_column.add_child(_start_button)

	_continue_button = _build_action_button("", Color(0.47, 0.28, 0.13), Color(1.0, 0.95, 0.88))
	_continue_button.pressed.connect(func() -> void:
		continue_game_requested.emit()
	)
	_attach_button_feedback(_continue_button)
	button_column.add_child(_continue_button)

	_settings_button = _build_action_button("", Color(0.63, 0.41, 0.23), Color(0.20, 0.11, 0.05))
	_settings_button.pressed.connect(func() -> void:
		settings_requested.emit()
	)
	_attach_button_feedback(_settings_button)
	button_column.add_child(_settings_button)

	_exit_button = _build_action_button("", Color(0.83, 0.67, 0.53), Color(0.20, 0.11, 0.05))
	_exit_button.pressed.connect(func() -> void:
		exit_requested.emit()
	)
	_attach_button_feedback(_exit_button)
	button_column.add_child(_exit_button)

	_save_hint_label = Label.new()
	_save_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_hint_label.add_theme_font_size_override("font_size", 16)
	_save_hint_label.add_theme_color_override("font_color", Color(0.39, 0.24, 0.13))
	button_column.add_child(_save_hint_label)

	_start_button.grab_focus()


func _build_action_button(text_value: String, background_color: Color, font_color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 58.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_stylebox_override("normal", _build_button_style(background_color))
	button.add_theme_stylebox_override("hover", _build_button_style(background_color.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _build_button_style(background_color.darkened(0.08)))
	button.add_theme_stylebox_override("focus", _build_button_style(background_color.lightened(0.12)))
	button.add_theme_stylebox_override("disabled", _build_button_style(Color(background_color.r, background_color.g, background_color.b, 0.45)))
	return button


func _build_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_right = 24
	style.corner_radius_bottom_left = 24
	style.border_color = Color(1.0, 0.92, 0.84, 0.08)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	return style


func _build_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
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


func _on_locale_changed(_locale_code: StringName, _is_rtl: bool) -> void:
	_apply_localized_text()


func _apply_localized_text() -> void:
	LocalizationManager.apply_control_locale(self)
	_eyebrow_label.text = LocalizationManager.text(&"menu.eyebrow")
	_title_label.text = LocalizationManager.text(&"menu.title")
	_description_label.text = LocalizationManager.text(&"menu.description")
	_info_label.text = LocalizationManager.text(&"menu.info")
	_start_button.text = LocalizationManager.text(&"menu.new_shift")
	_continue_button.text = LocalizationManager.text(&"menu.continue")
	_settings_button.text = LocalizationManager.text(&"menu.settings")
	_exit_button.text = LocalizationManager.text(&"menu.exit")
	_save_hint_label.text = LocalizationManager.text(&"menu.continue_hint")
