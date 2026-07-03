extends RefCounted
class_name MarketWorldBuilder

const SHELF_SCENE: PackedScene = preload("res://scenes/prefabs/world/stock_shelf.tscn")


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

	world_root.add_child(_build_box(Vector3(0.0, -0.05, 0.0), Vector3(28.0, 0.1, 22.0), floor_material, "Floor"))
	world_root.add_child(_build_box(Vector3(0.0, 3.1, -10.8), Vector3(18.0, 6.2, 0.25), wall_material, "BackWall"))
	world_root.add_child(_build_box(Vector3(-9.0, 3.1, 0.0), Vector3(0.25, 6.2, 22.0), wall_material, "LeftWall"))
	world_root.add_child(_build_box(Vector3(9.0, 3.1, 0.0), Vector3(0.25, 6.2, 22.0), wall_material, "RightWall"))
	world_root.add_child(_build_box(Vector3(-2.8, 3.1, 10.8), Vector3(6.0, 6.2, 0.25), wall_material, "FrontWallLeft"))
	world_root.add_child(_build_box(Vector3(5.4, 3.1, 10.8), Vector3(7.2, 6.2, 0.25), wall_material, "FrontWallRight"))
	world_root.add_child(_build_box(Vector3(-5.8, 1.5, 5.6), Vector3(2.0, 3.0, 4.0), accent_material, "StorageDivider"))
	world_root.add_child(_build_box(Vector3(0.0, 3.4, 0.0), Vector3(18.0, 0.18, 22.0), wall_material, "Ceiling"))
	world_root.add_child(_build_box(Vector3(0.0, 0.7, 6.5), Vector3(4.0, 1.4, 1.2), accent_material, "CheckoutCounter"))

	var lane_marker := MeshInstance3D.new()
	lane_marker.name = "LoadingLane"
	var lane_mesh := PlaneMesh.new()
	lane_mesh.size = Vector2(8.0, 6.0)
	lane_marker.mesh = lane_mesh
	lane_marker.position = Vector3(12.0, 0.02, -8.0)
	lane_marker.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var lane_material := StandardMaterial3D.new()
	lane_material.albedo_color = Color(0.17, 0.17, 0.19)
	lane_material.roughness = 0.98
	lane_marker.material_override = lane_material
	world_root.add_child(lane_marker)

	var storage_zone := load("res://scripts/game/world/storage_zone.gd").new() as Node3D
	storage_zone.name = "StorageZone"
	storage_zone.set("zone_name", "Backroom Storage")
	storage_zone.set("half_extents", Vector3(2.7, 1.5, 2.5))
	storage_zone.position = Vector3(-5.7, 0.0, 5.8)
	world_root.add_child(storage_zone)

	var shelves := _build_shelves(interactable_root)
	_build_lighting(world_root)

	return {
		"storage_zone": storage_zone,
		"shelves": shelves
	}


func _build_shelves(interactable_root: Node3D) -> Array:
	var shelves: Array = []
	var shelf_configs := [
		{
			"shelf_id": "drink_front",
			"shelf_label": "Drink Cooler",
			"shelf_label_key": "name.shelf.drink_front",
			"shelf_type": "drink_shelf",
			"accepted_categories": ["drink"],
			"capacity_units": 14,
			"position": Vector3(-2.4, 0.0, 0.6)
		},
		{
			"shelf_id": "snack_mid",
			"shelf_label": "Snack Wall",
			"shelf_label_key": "name.shelf.snack_mid",
			"shelf_type": "snack_shelf",
			"accepted_categories": ["snack"],
			"capacity_units": 16,
			"position": Vector3(0.0, 0.0, -0.6)
		},
		{
			"shelf_id": "fruit_corner",
			"shelf_label": "Produce Stand",
			"shelf_label_key": "name.shelf.fruit_corner",
			"shelf_type": "fruit_shelf",
			"accepted_categories": ["fruit"],
			"capacity_units": 14,
			"position": Vector3(2.5, 0.0, 0.8)
		}
	]

	for config in shelf_configs:
		var shelf := SHELF_SCENE.instantiate()
		if shelf == null:
			continue
		var shelf_position: Vector3 = config.get("position", Vector3.ZERO)
		shelf.position = shelf_position
		shelf.call("configure_from_data", config)
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


func _collect_existing_shelves(interactable_root: Node3D) -> Array:
	var shelves: Array = []
	for child in interactable_root.get_children():
		if child is StockShelf:
			shelves.append(child)
	return shelves


func _build_box(position_value: Vector3, size_value: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	box.name = node_name
	box.position = position_value
	var box_mesh := BoxMesh.new()
	box_mesh.size = size_value
	box.mesh = box_mesh
	box.material_override = material
	return box


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
