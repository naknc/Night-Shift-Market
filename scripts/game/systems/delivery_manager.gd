extends Node3D
class_name DeliveryManager

signal delivery_state_changed(state: StringName)
signal box_manifest_changed()
signal all_boxes_unpacked()

const BOX_SCENE: PackedScene = preload("res://scenes/prefabs/world/delivery_box.tscn")
const CONTENT_LOADER_SCRIPT: Script = preload("res://scripts/game/data/gameplay_content_loader.gd")

var storage_zone: Node3D = null
var world_parent: Node3D = null

var _truck_root: Node3D
var _cargo_anchor: Node3D
var _active_boxes: Array[Node] = []
var _state: StringName = &"idle"
var _truck_tween: Tween = null
var _content_loader: RefCounted = CONTENT_LOADER_SCRIPT.new()


func _ready() -> void:
	_build_truck()


func initialize_delivery(data: Dictionary, zone: Node3D, target_parent: Node3D) -> void:
	storage_zone = zone
	world_parent = target_parent
	_clear_boxes()
	_build_truck()
	_stop_truck_tween()

	var saved_state := StringName(String(data.get("state", "arriving")))
	var saved_truck_position := _read_truck_position(data, _get_truck_entry_position())
	var box_entries: Array = data.get("boxes", [])

	if not box_entries.is_empty():
		for raw_box in box_entries:
			if typeof(raw_box) != TYPE_DICTIONARY:
				continue
			var box := BOX_SCENE.instantiate() as Node
			if box == null:
				continue
			world_parent.add_child(box)
			box.call("configure_from_data", raw_box as Dictionary, storage_zone, world_parent)
			_watch_box(box)
			if not bool(box.get("is_opened")):
				_active_boxes.append(box)
		_set_state(saved_state if saved_state != &"idle" else &"unloading")
		_set_truck_position(saved_truck_position)
		_emit_box_manifest_changed()
		return

	_set_state(saved_state)
	match _state:
		&"completed", &"departed":
			if _state == &"departed":
				_set_truck_position(saved_truck_position if data.has("truck_position") else _get_truck_exit_position())
			else:
				_resume_truck_departure(saved_truck_position)
		&"unloading":
			_set_truck_position(saved_truck_position if data.has("truck_position") else _get_truck_park_position())
			_spawn_default_boxes()
		_:
			_resume_truck_arrival(saved_truck_position)


func serialize_state() -> Dictionary:
	var boxes: Array[Dictionary] = []
	for box in _active_boxes:
		boxes.append(box.call("serialize_state"))

	return {
		"state": String(_state),
		"truck_position": [_truck_root.position.x, _truck_root.position.y, _truck_root.position.z],
		"boxes": boxes
	}


func get_state() -> StringName:
	return _state


func get_active_boxes() -> Array:
	var result: Array = []
	for box in _active_boxes:
		if is_instance_valid(box):
			result.append(box)
	return result


func are_all_boxes_in_storage() -> bool:
	for box in get_active_boxes():
		if not bool(box.call("is_inside_storage")):
			return false
	return not get_active_boxes().is_empty()


func process_box_unpack(box: Node) -> Array[Dictionary]:
	if box == null:
		return []
	var unpacked: Array = box.call("unpack")
	if unpacked.is_empty():
		return []
	_remove_box(box)
	return unpacked


func _start_truck_arrival() -> void:
	_resume_truck_arrival(_get_truck_entry_position())


func _resume_truck_arrival(start_position: Vector3) -> void:
	_set_truck_position(start_position)
	if _truck_root.position.is_equal_approx(_get_truck_park_position()):
		_set_state(&"unloading")
		_spawn_default_boxes()
		return

	var duration := _get_transition_duration(start_position, _get_truck_park_position(), 2.2)
	_truck_tween = create_tween()
	_truck_tween.tween_property(_truck_root, "position", _get_truck_park_position(), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_truck_tween.finished.connect(func() -> void:
		_truck_tween = null
		_set_state(&"unloading")
		_spawn_default_boxes()
	)


func _spawn_default_boxes() -> void:
	if world_parent == null or storage_zone == null:
		return
	if not _active_boxes.is_empty():
		return

	var manifests: Array[Dictionary] = _content_loader.load_delivery_manifest()

	for index in manifests.size():
		var box := BOX_SCENE.instantiate() as Node
		if box == null:
			continue
		world_parent.add_child(box)
		var box_data: Dictionary = (manifests[index] as Dictionary).duplicate(true)
		var offset := _read_offset_vector(box_data.get("offset", [0.0, 0.45, 0.0]))
		var anchor_position := _cargo_anchor.global_position + offset
		box_data.erase("offset")
		box_data["position"] = [anchor_position.x, anchor_position.y, anchor_position.z]
		box.call("configure_from_data", box_data, storage_zone, world_parent)
		_watch_box(box)
		_active_boxes.append(box)

	_emit_box_manifest_changed()


func _watch_box(box: Node) -> void:
	box.connect("box_opened", Callable(self, "_on_box_opened"))
	box.connect("box_state_changed", Callable(self, "_emit_box_manifest_changed"))


func _remove_box(box: Node) -> void:
	_active_boxes.erase(box)
	_emit_box_manifest_changed()
	if is_instance_valid(box):
		box.queue_free()

	if _active_boxes.is_empty():
		all_boxes_unpacked.emit()
		_begin_truck_departure()


func _begin_truck_departure() -> void:
	_set_state(&"completed")
	_resume_truck_departure(_truck_root.position)


func _resume_truck_departure(start_position: Vector3) -> void:
	_set_truck_position(start_position)
	if _truck_root.position.is_equal_approx(_get_truck_exit_position()):
		_set_state(&"departed")
		return

	var duration := _get_transition_duration(start_position, _get_truck_exit_position(), 2.4)
	_truck_tween = create_tween()
	_truck_tween.tween_property(_truck_root, "position", _get_truck_exit_position(), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_truck_tween.finished.connect(func() -> void:
		_truck_tween = null
		_set_state(&"departed")
	)


func _on_box_opened(_box_id: StringName, _contents: Array[Dictionary]) -> void:
	_emit_box_manifest_changed()


func _emit_box_manifest_changed() -> void:
	box_manifest_changed.emit()


func _clear_boxes() -> void:
	for box in _active_boxes:
		if is_instance_valid(box):
			box.queue_free()
	_active_boxes.clear()


func _stop_truck_tween() -> void:
	if _truck_tween != null:
		_truck_tween.kill()
		_truck_tween = null


func _build_truck() -> void:
	if _truck_root != null:
		return

	_truck_root = Node3D.new()
	_truck_root.name = "DeliveryTruck"
	add_child(_truck_root)

	var cab_material := StandardMaterial3D.new()
	cab_material.albedo_color = Color(0.95, 0.67, 0.24)
	cab_material.roughness = 0.66

	var cargo_material := StandardMaterial3D.new()
	cargo_material.albedo_color = Color(0.89, 0.91, 0.95)
	cargo_material.roughness = 0.82

	var cab := _make_box_mesh(Vector3(-1.2, 0.85, 0.0), Vector3(1.4, 1.4, 1.8), cab_material)
	_truck_root.add_child(cab)
	var cargo := _make_box_mesh(Vector3(0.9, 1.1, 0.0), Vector3(3.2, 1.9, 1.95), cargo_material)
	_truck_root.add_child(cargo)
	var bed := _make_box_mesh(Vector3(1.4, 0.25, 0.0), Vector3(3.8, 0.2, 2.1), cab_material)
	_truck_root.add_child(bed)

	for wheel_offset in [
		Vector3(-1.5, 0.28, -0.95),
		Vector3(-1.5, 0.28, 0.95),
		Vector3(1.3, 0.28, -0.95),
		Vector3(1.3, 0.28, 0.95)
	]:
		var wheel := MeshInstance3D.new()
		wheel.position = wheel_offset
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.34
		cylinder.bottom_radius = 0.34
		cylinder.height = 0.34
		wheel.mesh = cylinder
		wheel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		var wheel_material := StandardMaterial3D.new()
		wheel_material.albedo_color = Color(0.11, 0.11, 0.12)
		wheel.material_override = wheel_material
		_truck_root.add_child(wheel)

	_cargo_anchor = Node3D.new()
	_cargo_anchor.name = "CargoAnchor"
	_cargo_anchor.position = Vector3(1.1, 0.6, 0.0)
	_truck_root.add_child(_cargo_anchor)
	_set_truck_position(_get_truck_entry_position())


func _set_state(state: StringName) -> void:
	_state = state
	delivery_state_changed.emit(state)


func _get_truck_entry_position() -> Vector3:
	return Vector3(24.0, 0.0, -8.0)


func _get_truck_park_position() -> Vector3:
	return Vector3(11.2, 0.0, -8.0)


func _get_truck_exit_position() -> Vector3:
	return Vector3(-28.0, 0.0, -8.0)


func _set_truck_position(position_value: Vector3) -> void:
	if _truck_root != null:
		_truck_root.position = position_value


func _read_truck_position(data: Dictionary, fallback: Vector3) -> Vector3:
	var position_data: Variant = data.get("truck_position", [fallback.x, fallback.y, fallback.z])
	if position_data is Array and position_data.size() >= 3:
		return Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	return fallback


func _get_transition_duration(start_position: Vector3, target_position: Vector3, full_duration: float) -> float:
	var full_distance := _get_truck_entry_position().distance_to(_get_truck_park_position())
	if target_position == _get_truck_exit_position():
		full_distance = _get_truck_park_position().distance_to(_get_truck_exit_position())
	var remaining_distance := start_position.distance_to(target_position)
	if full_distance <= 0.001:
		return 0.01
	return maxf(0.01, full_duration * (remaining_distance / full_distance))


func _read_offset_vector(raw_offset: Variant) -> Vector3:
	if raw_offset is Array and raw_offset.size() >= 3:
		return Vector3(float(raw_offset[0]), float(raw_offset[1]), float(raw_offset[2]))
	return Vector3(0.0, 0.45, 0.0)


func _make_box_mesh(position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = position_value
	var box_mesh := BoxMesh.new()
	box_mesh.size = size_value
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	return mesh_instance
