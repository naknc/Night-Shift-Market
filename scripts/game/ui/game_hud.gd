extends Control
class_name GameHud

signal move_vector_changed(value: Vector2)
signal look_input_emitted(delta: Vector2)
signal interact_pressed()
signal grab_pressed()

const JOYSTICK_RADIUS: float = 76.0

var _move_pointer_id: int = -1
var _look_pointer_id: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_value: Vector2 = Vector2.ZERO
var _look_last_position: Vector2 = Vector2.ZERO

var _objective_title: Label
var _objective_detail: Label
var _prompt_label: Label
var _notification_label: Label
var _inventory_label: Label
var _status_label: Label
var _joystick_base: PanelContainer
var _joystick_knob: PanelContainer
var _interact_button: Button
var _grab_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	_refresh_joystick_visual()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func set_objective(title_text: String, detail_text: String) -> void:
	_objective_title.text = title_text
	_objective_detail.text = detail_text


func set_prompt(text_value: String) -> void:
	_prompt_label.text = text_value
	_prompt_label.visible = not text_value.is_empty()


func set_status(day_number: int, phase_text: String, carried_label: String) -> void:
	var carry_text := "Hands Free"
	if not carried_label.is_empty():
		carry_text = "Carrying: %s" % carried_label
	_status_label.text = "Day %d  |  %s  |  %s" % [day_number, phase_text, carry_text]


func set_inventory_lines(lines: PackedStringArray) -> void:
	if lines.is_empty():
		_inventory_label.text = "Inventory\nNo stock unpacked yet."
		return
	_inventory_label.text = "Inventory\n%s" % "\n".join(lines)


func show_notification(text_value: String) -> void:
	_notification_label.text = text_value
	_notification_label.visible = true
	var tween := create_tween()
	_notification_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	tween.tween_interval(2.0)
	tween.tween_property(_notification_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.4)
	tween.finished.connect(func() -> void:
		_notification_label.visible = false
	)


func _build_interface() -> void:
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 22)
	root_margin.add_theme_constant_override("margin_right", 22)
	root_margin.add_theme_constant_override("margin_top", 18)
	root_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(root_margin)

	var overlay := Control.new()
	overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_child(overlay)

	var top_left_panel := PanelContainer.new()
	top_left_panel.position = Vector2(0.0, 0.0)
	top_left_panel.custom_minimum_size = Vector2(430.0, 0.0)
	top_left_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.09, 0.07, 0.84)))
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
	_objective_detail.custom_minimum_size = Vector2(390.0, 0.0)
	_objective_detail.add_theme_font_size_override("font_size", 18)
	_objective_detail.add_theme_color_override("font_color", Color(0.95, 0.90, 0.84))
	top_left_column.add_child(_objective_detail)

	var top_right_panel := PanelContainer.new()
	top_right_panel.anchor_left = 1.0
	top_right_panel.anchor_right = 1.0
	top_right_panel.offset_left = -340.0
	top_right_panel.offset_right = 0.0
	top_right_panel.custom_minimum_size = Vector2(340.0, 0.0)
	top_right_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.13, 0.09, 0.06, 0.84)))
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

	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.5
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 0.5
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = -290.0
	bottom_panel.offset_top = -110.0
	bottom_panel.offset_right = 290.0
	bottom_panel.offset_bottom = -18.0
	bottom_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.08, 0.06, 0.78)))
	overlay.add_child(bottom_panel)

	var bottom_margin := MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 18)
	bottom_margin.add_theme_constant_override("margin_right", 18)
	bottom_margin.add_theme_constant_override("margin_top", 14)
	bottom_margin.add_theme_constant_override("margin_bottom", 14)
	bottom_panel.add_child(bottom_margin)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	_prompt_label.visible = false
	bottom_margin.add_child(_prompt_label)

	_notification_label = Label.new()
	_notification_label.anchor_left = 0.5
	_notification_label.anchor_top = 0.72
	_notification_label.anchor_right = 0.5
	_notification_label.anchor_bottom = 0.72
	_notification_label.offset_left = -260.0
	_notification_label.offset_top = 0.0
	_notification_label.offset_right = 260.0
	_notification_label.offset_bottom = 48.0
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.add_theme_font_size_override("font_size", 18)
	_notification_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	_notification_label.visible = false
	overlay.add_child(_notification_label)

	_joystick_base = PanelContainer.new()
	_joystick_base.position = Vector2(34.0, size.y - 210.0)
	_joystick_base.custom_minimum_size = Vector2(152.0, 152.0)
	_joystick_base.add_theme_stylebox_override("panel", _make_circle_style(Color(0.16, 0.12, 0.09, 0.52), 76))
	overlay.add_child(_joystick_base)

	_joystick_knob = PanelContainer.new()
	_joystick_knob.custom_minimum_size = Vector2(68.0, 68.0)
	_joystick_knob.add_theme_stylebox_override("panel", _make_circle_style(Color(0.94, 0.80, 0.58, 0.88), 34))
	_joystick_base.add_child(_joystick_knob)

	var button_column := VBoxContainer.new()
	button_column.anchor_left = 1.0
	button_column.anchor_top = 1.0
	button_column.anchor_right = 1.0
	button_column.anchor_bottom = 1.0
	button_column.offset_left = -176.0
	button_column.offset_top = -204.0
	button_column.offset_right = -12.0
	button_column.offset_bottom = -18.0
	button_column.alignment = BoxContainer.ALIGNMENT_END
	button_column.add_theme_constant_override("separation", 12)
	overlay.add_child(button_column)

	_interact_button = _make_action_button("Interact")
	_interact_button.pressed.connect(func() -> void:
		interact_pressed.emit()
	)
	button_column.add_child(_interact_button)

	_grab_button = _make_action_button("Carry / Drop")
	_grab_button.pressed.connect(func() -> void:
		grab_pressed.emit()
	)
	button_column.add_child(_grab_button)

	set_status(1, "Morning Delivery", "")
	set_inventory_lines(PackedStringArray())
	set_objective("Morning Delivery", "Wait for today’s truck to arrive.")


func _handle_touch(event: InputEventScreenTouch) -> void:
	var position_value := event.position

	if event.pressed:
		if _move_pointer_id == -1 and position_value.x <= size.x * 0.42 and not _is_over_action_buttons(position_value):
			_move_pointer_id = event.index
			_move_origin = position_value
			_update_move_value(position_value)
			return
		if _look_pointer_id == -1 and position_value.x > size.x * 0.42 and not _is_over_action_buttons(position_value):
			_look_pointer_id = event.index
			_look_last_position = position_value
			return
	else:
		if event.index == _move_pointer_id:
			_move_pointer_id = -1
			_move_value = Vector2.ZERO
			move_vector_changed.emit(Vector2.ZERO)
			_refresh_joystick_visual()
		if event.index == _look_pointer_id:
			_look_pointer_id = -1


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _move_pointer_id:
		_update_move_value(event.position)
		return

	if event.index == _look_pointer_id:
		var relative := event.position - _look_last_position
		_look_last_position = event.position
		look_input_emitted.emit(relative * 0.75)


func _update_move_value(pointer_position: Vector2) -> void:
	var offset := pointer_position - _move_origin
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS
	_move_value = offset / JOYSTICK_RADIUS
	move_vector_changed.emit(Vector2(_move_value.x, -_move_value.y))
	_refresh_joystick_visual()


func _refresh_joystick_visual() -> void:
	if _joystick_base == null or _joystick_knob == null:
		return

	var viewport_size := get_viewport_rect().size
	_joystick_base.position = Vector2(34.0, viewport_size.y - 210.0)
	var base_center := (_joystick_base.custom_minimum_size - _joystick_knob.custom_minimum_size) * 0.5
	_joystick_knob.position = base_center + _move_value * JOYSTICK_RADIUS


func _is_over_action_buttons(point: Vector2) -> bool:
	if _interact_button != null and _interact_button.get_global_rect().has_point(point):
		return true
	if _grab_button != null and _grab_button.get_global_rect().has_point(point):
		return true
	return false


func _make_action_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 62.0)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.22, 0.12, 0.06))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.98, 0.83, 0.58)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(1.0, 0.88, 0.66)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.88, 0.70, 0.43)))
	return button


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
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _make_circle_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style
