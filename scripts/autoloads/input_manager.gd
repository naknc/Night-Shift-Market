extends Node

signal look_sensitivity_changed(value: float)
signal invert_y_changed(enabled: bool)

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_FORWARD: StringName = &"move_forward"
const ACTION_MOVE_BACK: StringName = &"move_back"
const ACTION_RUN: StringName = &"run"
const ACTION_INTERACT: StringName = &"interact"
const ACTION_GRAB: StringName = &"grab"
const ACTION_PAUSE: StringName = &"pause"

var _initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func initialize() -> void:
	if _initialized:
		return

	_ensure_default_actions()
	apply_saved_settings()
	_initialized = true


func apply_saved_settings() -> void:
	look_sensitivity_changed.emit(get_look_sensitivity())
	invert_y_changed.emit(is_invert_y_enabled())


func get_move_vector() -> Vector2:
	if not _initialized:
		initialize()
	return Input.get_vector(ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_BACK, ACTION_MOVE_FORWARD)


func is_run_pressed() -> bool:
	if not _initialized:
		initialize()
	return Input.is_action_pressed(ACTION_RUN)


func is_interact_pressed() -> bool:
	if not _initialized:
		initialize()
	return Input.is_action_just_pressed(ACTION_INTERACT)


func is_grab_pressed() -> bool:
	if not _initialized:
		initialize()
	return Input.is_action_pressed(ACTION_GRAB)


func is_pause_pressed() -> bool:
	if not _initialized:
		initialize()
	return Input.is_action_just_pressed(ACTION_PAUSE)


func get_look_sensitivity() -> float:
	return float(SaveManager.get_setting(&"input", &"look_sensitivity", 0.18))


func set_look_sensitivity(value: float) -> void:
	var clamped_value := clampf(value, 0.05, 1.0)
	SaveManager.set_setting(&"input", &"look_sensitivity", clamped_value)
	look_sensitivity_changed.emit(clamped_value)


func is_invert_y_enabled() -> bool:
	return bool(SaveManager.get_setting(&"input", &"invert_y", false))


func set_invert_y(enabled: bool) -> void:
	SaveManager.set_setting(&"input", &"invert_y", enabled)
	invert_y_changed.emit(enabled)


func _ensure_default_actions() -> void:
	_ensure_action(ACTION_MOVE_LEFT, 0.5)
	_ensure_action(ACTION_MOVE_RIGHT, 0.5)
	_ensure_action(ACTION_MOVE_FORWARD, 0.5)
	_ensure_action(ACTION_MOVE_BACK, 0.5)
	_ensure_action(ACTION_RUN, 0.5)
	_ensure_action(ACTION_INTERACT, 0.5)
	_ensure_action(ACTION_GRAB, 0.5)
	_ensure_action(ACTION_PAUSE, 0.5)

	_ensure_key_binding(ACTION_MOVE_LEFT, KEY_A)
	_ensure_key_binding(ACTION_MOVE_LEFT, KEY_LEFT)
	_ensure_key_binding(ACTION_MOVE_RIGHT, KEY_D)
	_ensure_key_binding(ACTION_MOVE_RIGHT, KEY_RIGHT)
	_ensure_key_binding(ACTION_MOVE_FORWARD, KEY_W)
	_ensure_key_binding(ACTION_MOVE_FORWARD, KEY_UP)
	_ensure_key_binding(ACTION_MOVE_BACK, KEY_S)
	_ensure_key_binding(ACTION_MOVE_BACK, KEY_DOWN)
	_ensure_key_binding(ACTION_RUN, KEY_SHIFT)
	_ensure_key_binding(ACTION_INTERACT, KEY_E)
	_ensure_key_binding(ACTION_GRAB, KEY_F)
	_ensure_key_binding(ACTION_PAUSE, KEY_ESCAPE)

	_ensure_mouse_button_binding(ACTION_INTERACT, MOUSE_BUTTON_LEFT)
	_ensure_mouse_button_binding(ACTION_GRAB, MOUSE_BUTTON_RIGHT)


func _ensure_action(action: StringName, deadzone: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)


func _ensure_key_binding(action: StringName, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode

	if _has_matching_event(action, event):
		return

	InputMap.action_add_event(action, event)


func _ensure_mouse_button_binding(action: StringName, mouse_button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = mouse_button

	if _has_matching_event(action, event):
		return

	InputMap.action_add_event(action, event)


func _has_matching_event(action: StringName, candidate: InputEvent) -> bool:
	for existing_event in InputMap.action_get_events(action):
		if existing_event.as_text() == candidate.as_text():
			return true
	return false
