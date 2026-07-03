extends StaticBody3D
class_name DeliveryBox

signal box_opened(box_id: StringName, contents: Array[Dictionary])
signal box_state_changed()

var box_id: StringName = &""
var display_name: String = "Delivery Box"
var display_name_key: StringName = &""
var contents: Array[Dictionary] = []
var storage_zone: StorageZone = null
var home_parent: Node3D = null
var is_opened: bool = false
var is_carried: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D


func _ready() -> void:
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	_update_visuals()


func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed)


func configure_from_data(data: Dictionary, zone: StorageZone, world_parent: Node3D) -> void:
	box_id = StringName(String(data.get("box_id", "box")))
	display_name = String(data.get("display_name", "Delivery Box"))
	display_name_key = StringName(String(data.get("display_name_key", "")))
	contents = _read_contents_array(data.get("contents", []))
	storage_zone = zone
	home_parent = world_parent
	is_opened = bool(data.get("is_opened", false))
	is_carried = false

	var position_data: Variant = data.get("position", [0.0, 0.6, 0.0])
	if position_data is Array and position_data.size() >= 3:
		global_position = Vector3(
			float(position_data[0]),
			float(position_data[1]),
			float(position_data[2])
		)

	_update_visuals()


func serialize_state() -> Dictionary:
	return {
		"box_id": String(box_id),
		"display_name": display_name,
		"contents": _duplicate_contents(contents),
		"position": [global_position.x, global_position.y, global_position.z],
		"is_opened": is_opened
	}


func get_interaction_prompt() -> String:
	if is_opened:
		return ""
	var box_name := get_display_name()
	if is_carried:
		if is_inside_storage():
			return LocalizationManager.text(&"prompt.box.tap_unpack", {"box": box_name})
		return LocalizationManager.text(&"prompt.box.move_to_storage", {"box": box_name})
	if is_inside_storage():
		return LocalizationManager.text(&"prompt.box.tap_or_hold", {"box": box_name})
	return LocalizationManager.text(&"prompt.box.hold_carry", {"box": box_name})


func get_display_name() -> String:
	if display_name_key != StringName():
		return LocalizationManager.text(display_name_key)
	return display_name


func can_be_grabbed() -> bool:
	return not is_opened


func is_inside_storage() -> bool:
	return storage_zone != null and storage_zone.contains_world_position(global_position)


func grab_to(anchor: Node3D) -> void:
	if anchor == null or is_opened:
		return

	is_carried = true
	reparent(anchor, true)
	position = Vector3(0.35, -0.35, -1.3)
	rotation = Vector3.ZERO
	if collision_shape != null:
		collision_shape.disabled = true
	box_state_changed.emit()


func drop_to(world_parent: Node3D, world_position: Vector3, basis: Basis) -> void:
	if world_parent == null:
		return

	is_carried = false
	reparent(world_parent, true)
	global_position = world_position
	global_basis = basis
	if collision_shape != null:
		collision_shape.disabled = false
	box_state_changed.emit()


func unpack() -> Array[Dictionary]:
	if is_opened:
		return []
	if not is_inside_storage():
		return []

	is_opened = true
	is_carried = false
	var unpacked: Array[Dictionary] = _duplicate_contents(contents)
	contents.clear()
	_update_visuals()
	box_state_changed.emit()
	box_opened.emit(box_id, unpacked)
	return unpacked


func _update_visuals() -> void:
	if label == null or mesh_instance == null:
		return

	if is_opened:
		mesh_instance.visible = false
		label.text = LocalizationManager.text(&"label.box.unpacked", {"box": get_display_name()})
		label.modulate = Color(0.68, 0.82, 0.69)
		return

	mesh_instance.visible = true
	label.text = LocalizationManager.text(
		&"label.box.item_stacks",
		{
			"box": get_display_name(),
			"count": contents.size()
		}
	)
	label.modulate = Color(1.0, 0.95, 0.85)


func _on_locale_changed(_locale_code: StringName, _is_rtl: bool) -> void:
	_update_visuals()


func _read_contents_array(raw_contents: Variant) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	if raw_contents is Array:
		for entry_variant in raw_contents:
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var entry := entry_variant as Dictionary
			parsed.append({
				"product_id": String(entry.get("product_id", "")),
				"quantity": int(entry.get("quantity", 0))
			})
	return parsed


func _duplicate_contents(source: Array[Dictionary]) -> Array[Dictionary]:
	var duplicated: Array[Dictionary] = []
	for entry in source:
		duplicated.append(entry.duplicate(true))
	return duplicated
