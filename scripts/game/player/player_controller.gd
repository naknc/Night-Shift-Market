extends CharacterBody3D
class_name PlayerController

signal prompt_changed(text: String)
signal notification_requested(text: String)
signal carried_box_changed(label: String)
signal player_state_changed()
signal pause_requested()

@export var pan_speed: float = 11.0
@export var run_pan_speed: float = 17.0
@export var zoom_speed: float = 1.7
@export var min_zoom_distance: float = 11.0
@export var max_zoom_distance: float = 24.0
@export var camera_pitch_degrees: float = 56.0
@export var focus_height: float = 1.0
@export var interact_distance: float = 200.0

var _move_input: Vector2 = Vector2.ZERO
var _yaw: float = deg_to_rad(45.0)
var _pitch: float = deg_to_rad(-56.0)
var _zoom_distance: float = 17.0
var _game_root: GameRoot = null
var _hovered_interactable: Node = null
var _last_pointer_world_position: Vector3 = Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if collision_shape != null:
		collision_shape.disabled = true
	head.visible = false
	_update_camera_transform()
	_update_interaction_prompt()


func configure_game_root(root: GameRoot) -> void:
	_game_root = root


func set_move_input(value: Vector2) -> void:
	_move_input = value.normalized() if value.length() > 1.0 else value


func add_look_input(_delta: Vector2) -> void:
	pass


func apply_saved_view(position_value: Vector3, yaw: float, pitch: float, zoom_distance: float = 17.0) -> void:
	global_position = Vector3(position_value.x, 0.0, position_value.z)
	_yaw = yaw
	_pitch = pitch
	if _pitch > deg_to_rad(-20.0):
		_pitch = deg_to_rad(-camera_pitch_degrees)
	_zoom_distance = clampf(zoom_distance, min_zoom_distance, max_zoom_distance)
	_update_camera_transform()
	_update_interaction_prompt()


func serialize_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": _yaw,
		"pitch": _pitch,
		"zoom_distance": _zoom_distance
	}


func get_carried_box() -> DeliveryBox:
	return null


func get_camera_forward() -> Vector3:
	var focus_point := global_position + Vector3(0.0, focus_height, 0.0)
	return (focus_point - camera.global_position).normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.ACTION_INTERACT):
		_try_interact()
	elif event.is_action_pressed(InputManager.ACTION_GRAB):
		_try_grab_or_drop()
	elif event.is_action_pressed(InputManager.ACTION_PAUSE):
		pause_requested.emit()
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)


func _physics_process(delta: float) -> void:
	var keyboard_move := InputManager.get_move_vector()
	var desired_input := _move_input if _move_input.length() > 0.05 else keyboard_move
	var speed := run_pan_speed if InputManager.is_run_pressed() else pan_speed

	if desired_input.length() > 0.001:
		var world_forward := Vector3.FORWARD.rotated(Vector3.UP, _yaw)
		var world_right := Vector3.RIGHT.rotated(Vector3.UP, _yaw)
		var desired_direction := (world_right * desired_input.x) + (world_forward * desired_input.y)
		desired_direction.y = 0.0
		global_position += desired_direction.normalized() * speed * delta
		global_position.y = 0.0
		_update_camera_transform()
		player_state_changed.emit()

	_update_interaction_prompt()


func _try_interact() -> void:
	var collider := _get_interactable()
	if collider == null:
		notification_requested.emit(LocalizationManager.text(&"notification.nothing_to_interact"))
		return

	if collider is DeliveryBox:
		if _game_root != null and not collider.is_inside_storage():
			_game_root.send_box_to_storage(collider)
			return
		if _game_root != null:
			_game_root.try_unpack_box(collider)
		return

	if collider is StockShelf:
		if _game_root != null:
			_game_root.try_restock_shelf(collider)
		return

	notification_requested.emit(LocalizationManager.text(&"notification.object_not_ready"))


func _try_grab_or_drop() -> void:
	var collider := _get_interactable()
	if collider is DeliveryBox and _game_root != null:
		_game_root.send_box_to_storage(collider)
		return

	notification_requested.emit(LocalizationManager.text(&"notification.click_box_to_route"))


func _get_interactable() -> Node:
	return _hovered_interactable


func _update_interaction_prompt() -> void:
	var collider := _get_interactable()
	if collider is DeliveryBox:
		prompt_changed.emit(collider.get_interaction_prompt())
		return
	if collider is StockShelf:
		if _game_root != null:
			prompt_changed.emit(collider.get_interaction_prompt(_game_root.player_inventory, _game_root.product_catalog))
			return
	prompt_changed.emit("")


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if _is_pointer_over_ui():
		return

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_interact()
		return

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_try_grab_or_drop()
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_adjust_zoom(-zoom_speed)
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_adjust_zoom(zoom_speed)


func _adjust_zoom(delta_value: float) -> void:
	_zoom_distance = clampf(_zoom_distance + delta_value, min_zoom_distance, max_zoom_distance)
	_update_camera_transform()
	player_state_changed.emit()


func _update_camera_transform() -> void:
	if camera == null:
		return

	var focus_point := global_position + Vector3(0.0, focus_height, 0.0)
	var horizontal_distance := _zoom_distance * cos(absf(_pitch))
	var vertical_distance := _zoom_distance * sin(absf(_pitch))
	var offset := Vector3(0.0, vertical_distance, horizontal_distance).rotated(Vector3.UP, _yaw)
	camera.global_position = focus_point + offset
	camera.look_at(focus_point, Vector3.UP)


func _get_mouse_world_hit() -> Dictionary:
	if camera == null:
		return {}

	var pointer_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(pointer_position)
	var ray_direction := camera.project_ray_normal(pointer_position)
	var ray_query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + (ray_direction * interact_distance)
	)
	ray_query.collide_with_bodies = true
	ray_query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(ray_query)


func _is_pointer_over_ui() -> bool:
	var hovered_control := get_viewport().gui_get_hovered_control()
	return hovered_control != null and hovered_control.is_visible_in_tree()


func _process(_delta: float) -> void:
	var hit := _get_mouse_world_hit()
	var collider := hit.get("collider", null) as Node
	if collider is DeliveryBox or collider is StockShelf:
		_hovered_interactable = collider
	else:
		_hovered_interactable = null
	if hit.has("position"):
		_last_pointer_world_position = hit["position"] as Vector3
	_update_interaction_prompt()
