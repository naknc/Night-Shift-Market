extends Node3D
class_name StorageZone

@export var zone_name: String = "Backroom Storage"
@export var half_extents: Vector3 = Vector3(2.8, 1.6, 2.8)

var _mesh_instance: MeshInstance3D
var _title_label: Label3D
var _hint_label: Label3D


func _ready() -> void:
	_build_visuals()
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	_apply_localized_text()


func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed)


func contains_world_position(world_position: Vector3) -> bool:
	var local_position := to_local(world_position)
	return absf(local_position.x) <= half_extents.x \
		and absf(local_position.y) <= half_extents.y \
		and absf(local_position.z) <= half_extents.z


func get_status_text() -> String:
	return "%s ready" % zone_name


func get_drop_position(slot_index: int) -> Vector3:
	var slots: Array[Vector3] = [
		Vector3(-1.4, 0.35, -1.1),
		Vector3(0.0, 0.35, -1.1),
		Vector3(1.4, 0.35, -1.1),
		Vector3(-1.4, 0.35, 0.6),
		Vector3(0.0, 0.35, 0.6),
		Vector3(1.4, 0.35, 0.6)
	]
	var clamped_index := clampi(slot_index, 0, slots.size() - 1)
	return to_global(slots[clamped_index])


func _build_visuals() -> void:
	if _mesh_instance != null:
		return

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "StorageHighlight"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(half_extents.x * 2.0, 0.05, half_extents.z * 2.0)
	_mesh_instance.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.31, 0.64, 0.48, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_instance.material_override = material
	add_child(_mesh_instance)

	_title_label = Label3D.new()
	_title_label.name = "StorageLabel"
	_title_label.position = Vector3(0.0, 2.0, 0.0)
	_title_label.font_size = 30
	_title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_title_label.modulate = Color(0.94, 1.0, 0.95)
	add_child(_title_label)

	_hint_label = Label3D.new()
	_hint_label.name = "StorageHintLabel"
	_hint_label.position = Vector3(0.0, 1.55, 0.0)
	_hint_label.font_size = 22
	_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint_label.modulate = Color(0.86, 0.98, 0.90)
	add_child(_hint_label)

	var beacon_material := StandardMaterial3D.new()
	beacon_material.albedo_color = Color(0.40, 0.88, 0.62, 0.22)
	beacon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for offset in [
		Vector3(-half_extents.x, 1.2, -half_extents.z),
		Vector3(half_extents.x, 1.2, -half_extents.z),
		Vector3(-half_extents.x, 1.2, half_extents.z),
		Vector3(half_extents.x, 1.2, half_extents.z)
	]:
		var beacon := MeshInstance3D.new()
		beacon.position = offset
		var beacon_mesh := CylinderMesh.new()
		beacon_mesh.top_radius = 0.06
		beacon_mesh.bottom_radius = 0.06
		beacon_mesh.height = 2.4
		beacon.mesh = beacon_mesh
		beacon.material_override = beacon_material
		add_child(beacon)


func _apply_localized_text() -> void:
	if _title_label != null:
		_title_label.text = LocalizationManager.text(&"storage.zone_title")
	if _hint_label != null:
		_hint_label.text = LocalizationManager.text(&"storage.drop_hint")


func _on_locale_changed(_locale_code: StringName, _is_rtl: bool) -> void:
	_apply_localized_text()
