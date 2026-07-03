extends Control
class_name GameHud

signal move_vector_changed(value: Vector2)
signal look_input_emitted(delta: Vector2)
signal interact_pressed()
signal grab_pressed()

var _current_day: int = 1
var _current_time_of_day: float = 18.0
var _current_phase_text: String = ""
var _current_carried_label: String = ""
var _cached_inventory_lines: PackedStringArray = PackedStringArray()

var _objective_title: Label
var _objective_detail: Label
var _prompt_label: Label
var _notification_label: Label
var _inventory_label: Label
var _status_label: Label
var _controls_label: Label
var _primary_button: Button
var _route_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	_build_interface()
	_apply_localized_text()


func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed)


func set_objective(title_text: String, detail_text: String) -> void:
	_objective_title.text = title_text
	_objective_detail.text = detail_text


func set_prompt(text_value: String) -> void:
	_prompt_label.text = text_value
	_prompt_label.visible = not text_value.is_empty()


func set_status(day_number: int, time_of_day: float, phase_text: String, carried_label: String) -> void:
	_current_day = day_number
	_current_time_of_day = time_of_day
	_current_phase_text = phase_text
	_current_carried_label = carried_label
	var carry_text := LocalizationManager.text(&"hud.hands_free")
	if not carried_label.is_empty():
		carry_text = carried_label
	_status_label.text = LocalizationManager.text(
		&"hud.status_format",
		{
			"day": day_number,
			"time": _format_time_of_day(time_of_day),
			"phase": phase_text,
			"carry": carry_text
		}
	)


func set_inventory_lines(lines: PackedStringArray) -> void:
	_cached_inventory_lines = lines
	if lines.is_empty():
		_inventory_label.text = "%s\n%s" % [
			LocalizationManager.text(&"hud.inventory"),
			LocalizationManager.text(&"hud.inventory_empty")
		]
		return
	_inventory_label.text = "%s\n%s" % [LocalizationManager.text(&"hud.inventory"), "\n".join(lines)]


func show_notification(text_value: String) -> void:
	_notification_label.text = text_value
	_notification_label.visible = true
	_notification_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(_notification_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.25)
	tween.finished.connect(func() -> void:
		_notification_label.visible = false
	)


func _build_interface() -> void:
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 24)
	root_margin.add_theme_constant_override("margin_right", 24)
	root_margin.add_theme_constant_override("margin_top", 20)
	root_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(root_margin)

	var overlay := Control.new()
	overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_child(overlay)

	var top_left_panel := PanelContainer.new()
	top_left_panel.custom_minimum_size = Vector2(460.0, 0.0)
	top_left_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.09, 0.07, 0.86)))
	overlay.add_child(top_left_panel)

	var top_left_margin := MarginContainer.new()
	top_left_margin.add_theme_constant_override("margin_left", 16)
	top_left_margin.add_theme_constant_override("margin_right", 16)
	top_left_margin.add_theme_constant_override("margin_top", 14)
	top_left_margin.add_theme_constant_override("margin_bottom", 14)
	top_left_panel.add_child(top_left_margin)

	var top_left_column := VBoxContainer.new()
	top_left_column.add_theme_constant_override("separation", 8)
	top_left_margin.add_child(top_left_column)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.83))
	top_left_column.add_child(_status_label)

	_objective_title = Label.new()
	_objective_title.add_theme_font_size_override("font_size", 28)
	_objective_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.68))
	top_left_column.add_child(_objective_title)

	_objective_detail = Label.new()
	_objective_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_detail.custom_minimum_size = Vector2(410.0, 0.0)
	_objective_detail.add_theme_font_size_override("font_size", 18)
	_objective_detail.add_theme_color_override("font_color", Color(0.95, 0.90, 0.84))
	top_left_column.add_child(_objective_detail)

	var top_right_panel := PanelContainer.new()
	top_right_panel.anchor_left = 1.0
	top_right_panel.anchor_right = 1.0
	top_right_panel.offset_left = -350.0
	top_right_panel.offset_right = 0.0
	top_right_panel.custom_minimum_size = Vector2(350.0, 0.0)
	top_right_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.13, 0.09, 0.06, 0.86)))
	overlay.add_child(top_right_panel)

	var top_right_margin := MarginContainer.new()
	top_right_margin.add_theme_constant_override("margin_left", 16)
	top_right_margin.add_theme_constant_override("margin_right", 16)
	top_right_margin.add_theme_constant_override("margin_top", 14)
	top_right_margin.add_theme_constant_override("margin_bottom", 14)
	top_right_panel.add_child(top_right_margin)

	_inventory_label = Label.new()
	_inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_label.add_theme_font_size_override("font_size", 16)
	_inventory_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))
	top_right_margin.add_child(_inventory_label)

	var bottom_center_panel := PanelContainer.new()
	bottom_center_panel.anchor_left = 0.5
	bottom_center_panel.anchor_top = 1.0
	bottom_center_panel.anchor_right = 0.5
	bottom_center_panel.anchor_bottom = 1.0
	bottom_center_panel.offset_left = -310.0
	bottom_center_panel.offset_top = -124.0
	bottom_center_panel.offset_right = 310.0
	bottom_center_panel.offset_bottom = -18.0
	bottom_center_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.08, 0.06, 0.82)))
	overlay.add_child(bottom_center_panel)

	var bottom_margin := MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 18)
	bottom_margin.add_theme_constant_override("margin_right", 18)
	bottom_margin.add_theme_constant_override("margin_top", 14)
	bottom_margin.add_theme_constant_override("margin_bottom", 14)
	bottom_center_panel.add_child(bottom_margin)

	var bottom_column := VBoxContainer.new()
	bottom_column.add_theme_constant_override("separation", 8)
	bottom_margin.add_child(bottom_column)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	_prompt_label.visible = false
	bottom_column.add_child(_prompt_label)

	_controls_label = Label.new()
	_controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_label.add_theme_font_size_override("font_size", 16)
	_controls_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.76))
	bottom_column.add_child(_controls_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	bottom_column.add_child(button_row)

	_primary_button = _make_action_button("")
	_primary_button.pressed.connect(func() -> void:
		interact_pressed.emit()
	)
	_attach_button_feedback(_primary_button)
	button_row.add_child(_primary_button)

	_route_button = _make_action_button("")
	_route_button.pressed.connect(func() -> void:
		grab_pressed.emit()
	)
	_attach_button_feedback(_route_button)
	button_row.add_child(_route_button)

	_notification_label = Label.new()
	_notification_label.anchor_left = 0.5
	_notification_label.anchor_top = 0.77
	_notification_label.anchor_right = 0.5
	_notification_label.anchor_bottom = 0.77
	_notification_label.offset_left = -280.0
	_notification_label.offset_top = 0.0
	_notification_label.offset_right = 280.0
	_notification_label.offset_bottom = 48.0
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.add_theme_font_size_override("font_size", 18)
	_notification_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	_notification_label.visible = false
	overlay.add_child(_notification_label)

	set_status(1, 18.0, LocalizationManager.text(&"phase.truck_arrival"), "")
	set_inventory_lines(PackedStringArray())
	set_objective(
		LocalizationManager.text(&"objective.truck_arrival.title"),
		LocalizationManager.text(&"objective.truck_arrival.detail")
	)


func _make_action_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(200.0, 56.0)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color(0.20, 0.11, 0.05))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.98, 0.83, 0.58)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(1.0, 0.88, 0.66)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.88, 0.70, 0.43)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(1.0, 0.90, 0.69)))
	return button


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
		target_scale = Vector2(0.97, 0.97)
		target_position += Vector2(0.0, 4.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.08)
	tween.parallel().tween_property(button, "position", target_position, 0.08)


func _on_locale_changed(_locale_code: StringName, _is_rtl: bool) -> void:
	_apply_localized_text()


func _apply_localized_text() -> void:
	LocalizationManager.apply_control_locale(self)
	if _primary_button != null:
		_primary_button.text = LocalizationManager.text(&"hud.primary_action")
	if _route_button != null:
		_route_button.text = LocalizationManager.text(&"hud.send_to_storage")
	if _controls_label != null:
		_controls_label.text = LocalizationManager.text(&"hud.controls_hint")
	set_inventory_lines(_cached_inventory_lines)
	set_status(_current_day, _current_time_of_day, _current_phase_text, _current_carried_label)


func _format_time_of_day(time_of_day: float) -> String:
	var normalized := wrapf(time_of_day, 0.0, 24.0)
	var hour := int(floor(normalized))
	var minute := int(floor((normalized - float(hour)) * 60.0))
	return "%02d:%02d" % [hour, minute]


func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	return style


func _make_button_style(color: Color) -> StyleBoxFlat:
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
