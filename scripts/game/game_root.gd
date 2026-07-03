extends Node3D
class_name GameRoot

const PLAYER_SCENE: PackedScene = preload("res://scenes/prefabs/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/prefabs/ui/game_hud.tscn")
const SHELF_SCENE: PackedScene = preload("res://scenes/prefabs/world/stock_shelf.tscn")

@onready var world_root: Node3D = $WorldRoot
@onready var interactable_root: Node3D = $InteractableRoot
@onready var ui_layer: CanvasLayer = $UiLayer
@onready var systems_root: Node = $Systems

var product_catalog: Node
var player_inventory: Node
var delivery_manager: Node
var morning_shift_manager: Node
var storage_zone: Node3D
var shelves: Array = []
var player: Node
var hud: Control

var _pending_save_data: Dictionary = {}
var _is_runtime_ready: bool = false
var _current_day: int = 1
var _current_phase_text: String = "Morning Delivery"
var _carried_label: String = ""


func _ready() -> void:
	_build_runtime()
	_is_runtime_ready = true

	if _pending_save_data.is_empty():
		_apply_save_data(SaveManager.get_save_data())
	else:
		_apply_save_data(_pending_save_data)


func configure_from_save(save_data: Dictionary) -> void:
	_pending_save_data = save_data.duplicate(true)
	if _is_runtime_ready:
		_apply_save_data(_pending_save_data)


func get_interactable_root() -> Node3D:
	return interactable_root


func try_unpack_box(box: Node) -> void:
	if box == null:
		return
	if not bool(box.call("is_inside_storage")):
		_show_notification("Move the box into storage before unpacking it.")
		return

	var unpacked: Array = delivery_manager.call("process_box_unpack", box)
	if unpacked.is_empty():
		_show_notification("This box has already been unpacked.")
		return

	player_inventory.call("add_entries", unpacked)
	_show_notification("%s unpacked into stock inventory." % String(box.get("display_name")))
	_refresh_inventory_hud()
	_request_save()


func try_restock_shelf(shelf: Node) -> void:
	if shelf == null:
		return

	var result: Dictionary = shelf.call("restock_from_inventory", player_inventory, product_catalog)
	var added_quantity := int(result.get("added_quantity", 0))
	if added_quantity <= 0:
		_show_notification("%s cannot be stocked from the current inventory." % String(shelf.get("shelf_label")))
		return

	var product: Variant = product_catalog.call("get_product", StringName(String(result.get("product_id", ""))))
	var product_name := String(product.get("display_name")) if product != null else "product"
	_show_notification("Stocked %s with %d %s." % [String(shelf.get("shelf_label")), added_quantity, product_name])
	_refresh_inventory_hud()
	_request_save()


func _build_runtime() -> void:
	_build_world_shell()
	_build_systems()
	_build_player_and_hud()
	_connect_runtime_signals()


func _build_world_shell() -> void:
	if world_root.get_child_count() > 0:
		return

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

	storage_zone = load("res://scripts/game/world/storage_zone.gd").new()
	storage_zone.name = "StorageZone"
	storage_zone.set("zone_name", "Backroom Storage")
	storage_zone.set("half_extents", Vector3(2.7, 1.5, 2.5))
	storage_zone.position = Vector3(-5.7, 0.0, 5.8)
	world_root.add_child(storage_zone)

	_build_shelves()
	_build_lighting()


func _build_systems() -> void:
	product_catalog = load("res://scripts/game/systems/product_catalog.gd").new()
	product_catalog.name = "ProductCatalog"
	systems_root.add_child(product_catalog)

	player_inventory = load("res://scripts/game/systems/inventory_container.gd").new()
	player_inventory.name = "PlayerInventory"
	player_inventory.set("container_id", &"player_inventory")
	player_inventory.set("max_distinct_stacks", 16)
	systems_root.add_child(player_inventory)

	delivery_manager = load("res://scripts/game/systems/delivery_manager.gd").new()
	delivery_manager.name = "DeliveryManager"
	world_root.add_child(delivery_manager)

	morning_shift_manager = load("res://scripts/game/systems/morning_shift_manager.gd").new()
	morning_shift_manager.name = "MorningShiftManager"
	systems_root.add_child(morning_shift_manager)


func _build_player_and_hud() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.call("configure_game_root", self)
	world_root.add_child(player)

	hud = HUD_SCENE.instantiate()
	hud.name = "GameHud"
	ui_layer.add_child(hud)


func _build_shelves() -> void:
	if not shelves.is_empty():
		return

	var shelf_configs := [
		{
			"shelf_id": "drink_front",
			"shelf_label": "Drink Cooler",
			"shelf_type": "drink_shelf",
			"accepted_categories": ["drink"],
			"capacity_units": 14,
			"position": Vector3(-2.4, 0.0, 0.6)
		},
		{
			"shelf_id": "snack_mid",
			"shelf_label": "Snack Wall",
			"shelf_type": "snack_shelf",
			"accepted_categories": ["snack"],
			"capacity_units": 16,
			"position": Vector3(0.0, 0.0, -0.6)
		},
		{
			"shelf_id": "fruit_corner",
			"shelf_label": "Produce Stand",
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


func _build_lighting() -> void:
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


func _connect_runtime_signals() -> void:
	player.connect("prompt_changed", Callable(hud, "set_prompt"))
	player.connect("notification_requested", Callable(self, "_show_notification"))
	player.connect("carried_box_changed", Callable(self, "_on_carried_box_changed"))
	player.connect("player_state_changed", Callable(self, "_request_save"))
	player.connect("pause_requested", Callable(self, "_on_pause_requested"))

	hud.connect("move_vector_changed", Callable(player, "set_move_input"))
	hud.connect("look_input_emitted", Callable(player, "add_look_input"))
	hud.connect("interact_pressed", Callable(player, "_try_interact"))
	hud.connect("grab_pressed", Callable(player, "_try_grab_or_drop"))

	player_inventory.connect("inventory_changed", func(_container_id: StringName, _entries: Array[Dictionary]) -> void:
		_refresh_inventory_hud()
		_request_save()
	)

	for shelf in shelves:
		shelf.connect("shelf_stock_changed", func(_shelf_id: StringName, _data: Dictionary) -> void:
			_request_save()
		)

	morning_shift_manager.call("setup", delivery_manager, player_inventory, shelves)
	morning_shift_manager.connect("objective_changed", func(title: String, detail: String) -> void:
		hud.call("set_objective", title, detail)
	)
	morning_shift_manager.connect("phase_changed", func(phase: StringName) -> void:
		_current_phase_text = _phase_to_text(phase)
		_refresh_status_hud()
		_request_save()
	)

	delivery_manager.connect("box_manifest_changed", Callable(self, "_request_save"))
	delivery_manager.connect("all_boxes_unpacked", func() -> void:
		_show_notification("All delivery boxes unpacked. Finish stocking the shelves.")
	)


func _apply_save_data(save_data: Dictionary) -> void:
	var inventories := save_data.get("inventories", {}) as Dictionary
	player_inventory.call("load_from_data", inventories.get("player", []) as Array)

	var shelf_state_by_id := {}
	var saved_shelves: Array = save_data.get("shelves", [])
	if saved_shelves is Array:
		for raw_shelf in saved_shelves:
			if typeof(raw_shelf) != TYPE_DICTIONARY:
				continue
			var shelf_dict := raw_shelf as Dictionary
			shelf_state_by_id[String(shelf_dict.get("shelf_id", ""))] = shelf_dict

	for shelf in shelves:
		var shelf_id := String(shelf.get("shelf_id"))
		if shelf_state_by_id.has(shelf_id):
			shelf.call("configure_from_data", shelf_state_by_id[shelf_id] as Dictionary)

	var delivery_state := save_data.get("delivery", {}) as Dictionary
	delivery_manager.call("initialize_delivery", delivery_state, storage_zone, interactable_root)

	var player_state := save_data.get("player", {}) as Dictionary
	var position_data: Array = player_state.get("position", [0.0, 0.0, 5.2])
	var player_position := Vector3(0.0, 0.0, 5.2)
	if position_data is Array and position_data.size() >= 3:
		player_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	player.call(
		"apply_saved_view",
		player_position,
		float(player_state.get("yaw", PI)),
		float(player_state.get("pitch", 0.0))
	)

	var progress := save_data.get("progress", {}) as Dictionary
	_current_day = int(progress.get("current_day", 1))

	morning_shift_manager.call("load_state", save_data.get("morning_shift", {}) as Dictionary)
	_current_phase_text = _phase_to_text(morning_shift_manager.call("get_phase"))
	_refresh_inventory_hud()
	_refresh_status_hud()


func _request_save() -> void:
	var save_data := SaveManager.get_save_data()
	var progress := save_data.get("progress", {}) as Dictionary
	progress["current_day"] = _current_day
	progress["has_started"] = true
	save_data["progress"] = progress

	save_data["player"] = player.call("serialize_state")
	save_data["inventories"] = {
		"player": player_inventory.call("serialize")
	}

	var serialized_shelves: Array[Dictionary] = []
	for shelf in shelves:
		serialized_shelves.append(shelf.call("serialize_state"))
	save_data["shelves"] = serialized_shelves
	save_data["delivery"] = delivery_manager.call("serialize_state")
	save_data["morning_shift"] = morning_shift_manager.call("serialize_state")
	save_data["world"] = {"scene_id": "morning_delivery"}

	SaveManager.write_game_data(save_data)


func _refresh_inventory_hud() -> void:
	var lines := PackedStringArray()
	for entry in player_inventory.call("get_sorted_entries", product_catalog):
		var product: Variant = product_catalog.call("get_product", StringName(String(entry.get("product_id", ""))))
		if product == null:
			continue
		lines.append("%s x%d" % [String(product.get("display_name")), int(entry.get("quantity", 0))])
	hud.call("set_inventory_lines", lines)


func _refresh_status_hud() -> void:
	hud.call("set_status", _current_day, _current_phase_text, _carried_label)


func _show_notification(text_value: String) -> void:
	if hud != null:
		hud.call("show_notification", text_value)


func _on_carried_box_changed(label: String) -> void:
	_carried_label = label
	_refresh_status_hud()


func _on_pause_requested() -> void:
	_request_save()
	GameManager.return_to_main_menu()


func _phase_to_text(phase: StringName) -> String:
	match phase:
		&"truck_arrival":
			return "Truck Arrival"
		&"move_boxes_to_storage":
			return "Unload Boxes"
		&"unpack_boxes":
			return "Unpack Stock"
		&"restock_shelves":
			return "Restock Shelves"
		_:
			return "Store Ready"


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
