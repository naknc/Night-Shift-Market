extends CharacterBody3D
class_name PlayerController

signal prompt_changed(text: String)
signal notification_requested(text: String)
signal carried_box_changed(label: String)
signal player_state_changed()
signal pause_requested()

@export var walk_speed: float = 4.0
@export var run_speed: float = 6.1
@export var acceleration: float = 10.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
@export var interact_distance: float = 3.2

var _game_root: Node = null
var _move_input: Vector2 = Vector2.ZERO
var _look_input: Vector2 = Vector2.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0
var _carried_box: Node = null

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/Camera3D/InteractionRayCast3D
@onready var carry_anchor: Node3D = $Head/Camera3D/CarryAnchor


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	raycast.target_position = Vector3(0.0, 0.0, -interact_distance)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_interaction_prompt()


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func configure_game_root(root: Node) -> void:
	_game_root = root


func set_move_input(value: Vector2) -> void:
	_move_input = value
	if _move_input.length() > 1.0:
		_move_input = _move_input.normalized()


func add_look_input(delta: Vector2) -> void:
	_look_input += delta


func apply_saved_view(position_value: Vector3, yaw: float, pitch: float) -> void:
	global_position = position_value
	_yaw = yaw
	_pitch = pitch
	rotation.y = _yaw
	head.rotation.x = _pitch


func serialize_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": _yaw,
		"pitch": _pitch
	}


func get_carried_box() -> Node:
	return _carried_box


func get_camera_forward() -> Vector3:
	return -camera.global_basis.z.normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look_input((event as InputEventMouseMotion).relative)

	if event.is_action_pressed(InputManager.ACTION_INTERACT):
		_try_interact()
	elif event.is_action_pressed(InputManager.ACTION_GRAB):
		_try_grab_or_drop()
	elif event.is_action_pressed(InputManager.ACTION_PAUSE):
		pause_requested.emit()


func _physics_process(delta: float) -> void:
	_update_look_rotation()

	var keyboard_move := InputManager.get_move_vector()
	var desired_input := _move_input if _move_input.length() > 0.05 else keyboard_move
	var speed := run_speed if InputManager.is_run_pressed() else walk_speed

	var forward := -global_basis.z
	var right := global_basis.x
	var desired_direction := (right * desired_input.x + forward * desired_input.y)
	desired_direction.y = 0.0
	desired_direction = desired_direction.normalized()

	var target_velocity := desired_direction * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.01

	move_and_slide()
	_update_interaction_prompt()


func _update_look_rotation() -> void:
	if _look_input == Vector2.ZERO:
		return

	var invert_multiplier := -1.0 if InputManager.is_invert_y_enabled() else 1.0
	var sensitivity := InputManager.get_look_sensitivity()
	var look_scale := 0.010 * sensitivity

	_yaw -= _look_input.x * look_scale
	_pitch -= _look_input.y * look_scale * invert_multiplier
	_pitch = clampf(_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))

	rotation.y = _yaw
	head.rotation.x = _pitch
	_look_input = Vector2.ZERO
	player_state_changed.emit()


func _try_interact() -> void:
	var collider := _get_interactable()
	if collider == null:
		notification_requested.emit(LocalizationManager.text(&"notification.nothing_to_interact"))
		return

	if collider != null and collider.has_method("unpack"):
		if _game_root != null and _game_root.has_method("try_unpack_box"):
			_game_root.call("try_unpack_box", collider)
		return

	if collider != null and collider.has_method("restock_from_inventory"):
		if _carried_box != null:
			notification_requested.emit(LocalizationManager.text(&"notification.drop_box_before_stock"))
			return
		if _game_root != null and _game_root.has_method("try_restock_shelf"):
			_game_root.call("try_restock_shelf", collider)
		return

	notification_requested.emit(LocalizationManager.text(&"notification.object_not_ready"))


func _try_grab_or_drop() -> void:
	if _carried_box != null:
		_drop_carried_box()
		return

	var collider := _get_interactable()
	if collider != null and collider.has_method("can_be_grabbed") and bool(collider.call("can_be_grabbed")):
		_carried_box = collider as Node
		_carried_box.call("grab_to", carry_anchor)
		carried_box_changed.emit(String(_carried_box.call("get_display_name")))
		player_state_changed.emit()
		return

	notification_requested.emit(LocalizationManager.text(&"notification.only_boxes_carried"))


func _drop_carried_box() -> void:
	if _carried_box == null:
		return

	var forward := get_camera_forward()
	var drop_position := global_position + forward * 1.4
	drop_position.y = 0.35
	var drop_basis := Basis.IDENTITY

	if _game_root != null and _game_root.has_method("get_interactable_root"):
		_carried_box.call("drop_to", _game_root.call("get_interactable_root"), drop_position, drop_basis)
	else:
		_carried_box.call("drop_to", get_parent() as Node3D, drop_position, drop_basis)

	notification_requested.emit(
		LocalizationManager.text(
			&"notification.box_dropped",
			{"box": String(_carried_box.call("get_display_name"))}
		)
	)
	_carried_box = null
	carried_box_changed.emit("")
	player_state_changed.emit()


func _get_interactable() -> Object:
	raycast.force_raycast_update()
	if not raycast.is_colliding():
		return null
	return raycast.get_collider()


func _update_interaction_prompt() -> void:
	var collider := _get_interactable()
	if collider != null and collider.has_method("unpack"):
		prompt_changed.emit(String(collider.call("get_interaction_prompt")))
		return
	if collider != null and collider.has_method("restock_from_inventory"):
		if _game_root != null:
			var inventory: Variant = _game_root.get("player_inventory")
			var catalog: Variant = _game_root.get("product_catalog")
			prompt_changed.emit(String(collider.call("get_interaction_prompt", inventory, catalog)))
			return
	prompt_changed.emit("")
