extends Control
class_name PauseMenu

signal resume_requested()
signal settings_requested()
signal main_menu_requested()

var _title_label: Label
var _subtitle_label: Label
var _resume_button: Button
var _settings_button: Button
var _menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_apply_localized_text()
	_resume_button.grab_focus()


func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.ACTION_PAUSE):
		resume_requested.emit()


func _build_interface() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	LocalizationManager.locale_changed.connect(_on_locale_changed)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460.0, 0.0)
	panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.17, 0.11, 0.07, 0.98)))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.87))
	column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 17)
	_subtitle_label.add_theme_color_override("font_color", Color(0.96, 0.85, 0.74))
	column.add_child(_subtitle_label)

	_resume_button = _build_button("", Color(0.38, 0.22, 0.11), Color(1.0, 0.95, 0.88))
	_resume_button.pressed.connect(func() -> void:
		resume_requested.emit()
	)
	_attach_button_feedback(_resume_button)
	column.add_child(_resume_button)

	_settings_button = _build_button("", Color(0.62, 0.40, 0.22), Color(0.20, 0.10, 0.05))
	_settings_button.pressed.connect(func() -> void:
		settings_requested.emit()
	)
	_attach_button_feedback(_settings_button)
	column.add_child(_settings_button)

	_menu_button = _build_button("", Color(0.88, 0.74, 0.59), Color(0.20, 0.10, 0.05))
	_menu_button.pressed.connect(func() -> void:
		main_menu_requested.emit()
	)
	_attach_button_feedback(_menu_button)
	column.add_child(_menu_button)


func _build_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_right = 24
	style.corner_radius_bottom_left = 24
	style.border_color = Color(1.0, 0.95, 0.88, 0.08)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	return style


func _build_button(text_value: String, background_color: Color, font_color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 56.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_stylebox_override("normal", _build_button_style(background_color))
	button.add_theme_stylebox_override("hover", _build_button_style(background_color.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _build_button_style(background_color.darkened(0.08)))
	button.add_theme_stylebox_override("focus", _build_button_style(background_color.lightened(0.12)))
	return button


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
	_title_label.text = LocalizationManager.text(&"pause.title")
	_subtitle_label.text = LocalizationManager.text(&"pause.subtitle")
	_resume_button.text = LocalizationManager.text(&"pause.resume")
	_settings_button.text = LocalizationManager.text(&"pause.settings")
	_menu_button.text = LocalizationManager.text(&"pause.main_menu")
