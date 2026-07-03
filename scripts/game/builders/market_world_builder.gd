extends RefCounted
class_name MarketWorldBuilder

const SHELF_SCENE: PackedScene = preload("res://scenes/prefabs/world/stock_shelf.tscn")
const CONTENT_LOADER_SCRIPT: Script = preload("res://scripts/game/data/gameplay_content_loader.gd")

var _content_loader: RefCounted = CONTENT_LOADER_SCRIPT.new()


func build(world_root: Node3D, interactable_root: Node3D) -> Dictionary:
	if world_root == null or interactable_root == null:
		return {
			"storage_zone": null,
			"shelves": []
		}

	if world_root.get_child_count() > 0:
		return {
			"storage_zone": world_root.get_node_or_null("StorageZone"),
			"shelves": _collect_existing_shelves(interactable_root)
		}

	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	environment.environment = _create_environment()
	world_root.add_child(environment)

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.35, 0.29, 0.24)
	floor_material.roughness = 0.96

	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.88, 0.80, 0.68)
	wall_material.roughness = 0.92

	var accent_material := StandardMaterial3D.new()
	accent_material.albedo_color = Color(0.55, 0.37, 0.22)
	accent_material.roughness = 0.84

	world_root.add_child(_build_static_box(Vector3(0.0, -0.3, 0.0), Vector3(28.0, 0.6, 22.0), floor_material, "Floor"))
	world_root.add_child(_build_static_box(Vector3(0.0, 3.1, -10.8), Vector3(18.0, 6.2, 0.25), wall_material, "BackWall"))
	world_root.add_child(_build_static_box(Vector3(-9.0, 3.1, 0.0), Vector3(0.25, 6.2, 22.0), wall_material, "LeftWall"))
	world_root.add_child(_build_static_box(Vector3(9.0, 3.1, 0.0), Vector3(0.25, 6.2, 22.0), wall_material, "RightWall"))
	world_root.add_child(_build_static_box(Vector3(-3.4, 3.1, 10.8), Vector3(5.2, 6.2, 0.25), wall_material, "FrontWallLeft"))
	world_root.add_child(_build_static_box(Vector3(5.9, 3.1, 10.8), Vector3(6.2, 6.2, 0.25), wall_material, "FrontWallRight"))
	world_root.add_child(_build_static_box(Vector3(-5.8, 1.5, 5.6), Vector3(2.0, 3.0, 4.0), accent_material, "StorageDivider"))
	world_root.add_child(_build_static_box(Vector3(0.0, 3.4, 0.0), Vector3(18.0, 0.18, 22.0), wall_material, "Ceiling"))
	world_root.add_child(_build_static_box(Vector3(0.0, 0.7, 6.5), Vector3(4.0, 1.4, 1.2), accent_material, "CheckoutCounter"))
	world_root.add_child(_build_static_box(Vector3(0.0, -0.2, 21.0), Vector3(18.0, 0.4, 22.0), floor_material, "ExteriorApron"))

	var lane_marker := MeshInstance3D.new()
	lane_marker.name = "LoadingLane"
	var lane_mesh := PlaneMesh.new()
	lane_mesh.size = Vector2(8.5, 8.0)
	lane_marker.mesh = lane_mesh
	lane_marker.position = Vector3(1.0, 0.02, 15.4)
	lane_marker.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var lane_material := StandardMaterial3D.new()
	lane_material.albedo_color = Color(0.17, 0.17, 0.19)
	lane_material.roughness = 0.98
	lane_marker.material_override = lane_material
	world_root.add_child(lane_marker)

	var lane_border_material := StandardMaterial3D.new()
	lane_border_material.albedo_color = Color(0.92, 0.74, 0.38)
	lane_border_material.roughness = 0.82
	world_root.add_child(_build_static_box(Vector3(-3.45, 0.2, 15.4), Vector3(0.18, 0.4, 8.0), lane_border_material, "LoadingLaneLeftBorder"))
	world_root.add_child(_build_static_box(Vector3(5.45, 0.2, 15.4), Vector3(0.18, 0.4, 8.0), lane_border_material, "LoadingLaneRightBorder"))

	var storage_zone := StorageZone.new()
	storage_zone.name = "StorageZone"
	storage_zone.zone_name = "Backroom Storage"
	storage_zone.half_extents = Vector3(2.7, 1.5, 2.5)
	storage_zone.position = Vector3(-5.7, 0.0, 5.8)
	world_root.add_child(storage_zone)

	var shelves := _build_shelves(interactable_root)
	_build_lighting(world_root)

	return {
		"storage_zone": storage_zone,
		"shelves": shelves
	}


func _build_shelves(interactable_root: Node3D) -> Array[StockShelf]:
	var shelves: Array[StockShelf] = []
	var shelf_configs: Array[Dictionary] = _content_loader.load_shelf_layouts()

	for config in shelf_configs:
		var shelf := SHELF_SCENE.instantiate() as StockShelf
		if shelf == null:
			continue
		var shelf_position: Vector3 = config.get("position", Vector3.ZERO)
		shelf.position = shelf_position
		shelf.configure_from_data(config)
		interactable_root.add_child(shelf)
		shelves.append(shelf)

	return shelves


func _build_lighting(world_root: Node3D) -> void:
	var sun_pivot := Node3D.new()
	sun_pivot.name = "SunPivot"
	sun_pivot.rotation_degrees = Vector3(-48.0, 12.0, 0.0)
	world_root.add_child(sun_pivot)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.84, 0.62)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 36.0
	sun_pivot.add_child(sun)

	for light_position in [
		Vector3(-3.6, 3.0, -2.4),
		Vector3(0.0, 3.0, -2.4),
		Vector3(3.6, 3.0, -2.4),
		Vector3(-3.6, 3.0, 3.0),
		Vector3(0.0, 3.0, 3.0),
		Vector3(3.6, 3.0, 3.0)
	]:
		var omni := OmniLight3D.new()
		omni.position = light_position
		omni.light_color = Color(1.0, 0.69, 0.42)
		omni.light_energy = 1.55
		omni.omni_range = 11.0
		world_root.add_child(omni)


func _collect_existing_shelves(interactable_root: Node3D) -> Array[StockShelf]:
	var shelves: Array[StockShelf] = []
	for child in interactable_root.get_children():
		if child is StockShelf:
			shelves.append(child)
	return shelves


func _build_static_box(position_value: Vector3, size_value: Vector3, material: Material, node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value

	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size_value
	box.mesh = box_mesh
	box.material_override = material
	body.add_child(box)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collider.shape = shape
	body.add_child(collider)

	return body


func _create_environment() -> Environment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.05

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.06, 0.08, 0.16)
	sky_material.sky_horizon_color = Color(0.98, 0.55, 0.28)
	sky_material.ground_bottom_color = Color(0.09, 0.05, 0.04)
	sky_material.ground_horizon_color = Color(0.28, 0.15, 0.10)

	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	return environment
