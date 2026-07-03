extends Node3D
class_name StorageZone

@export var zone_name: String = "Backroom Storage"
@export var half_extents: Vector3 = Vector3(2.8, 1.6, 2.8)

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_build_visuals()


func contains_world_position(world_position: Vector3) -> bool:
	var local_position := to_local(world_position)
	return absf(local_position.x) <= half_extents.x \
		and absf(local_position.y) <= half_extents.y \
		and absf(local_position.z) <= half_extents.z


func get_status_text() -> String:
	return "%s ready" % zone_name


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

	var sign := Label3D.new()
	sign.name = "StorageLabel"
	sign.text = zone_name
	sign.position = Vector3(0.0, 1.75, 0.0)
	sign.font_size = 28
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(0.94, 1.0, 0.95)
	add_child(sign)
