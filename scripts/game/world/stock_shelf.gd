extends StaticBody3D
class_name StockShelf

signal shelf_stock_changed(shelf_id: StringName, data: Dictionary)

var shelf_id: StringName = &"shelf"
var shelf_label: String = "Shelf"
var shelf_label_key: StringName = &""
var shelf_type: StringName = &"general_shelf"
var accepted_categories: PackedStringArray = PackedStringArray()
var capacity_units: int = 12
var current_product_id: StringName = StringName()
var current_quantity: int = 0
var _catalog: ProductCatalog = null

var _slot_nodes: Array[MeshInstance3D] = []
var _slot_positions: Array[Vector3] = []
var _visual_ready: bool = false

@onready var mesh_root: Node3D = $MeshRoot
@onready var product_root: Node3D = $ProductRoot
@onready var label: Label3D = $Label3D


func _ready() -> void:
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	_build_visuals()
	_refresh_visual_state(null)


func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed)


func configure_from_data(data: Dictionary) -> void:
	shelf_id = StringName(String(data.get("shelf_id", "shelf")))
	shelf_label = String(data.get("shelf_label", "Shelf"))
	shelf_label_key = StringName(String(data.get("shelf_label_key", "")))
	shelf_type = StringName(String(data.get("shelf_type", "general_shelf")))
	capacity_units = int(data.get("capacity_units", 12))

	var category_array: Array = data.get("accepted_categories", [])
	accepted_categories = PackedStringArray()
	if category_array is Array:
		for raw_category in category_array:
			accepted_categories.append(String(raw_category))

	current_product_id = StringName(String(data.get("current_product_id", "")))
	current_quantity = int(data.get("current_quantity", 0))
	_refresh_visual_state(null)


func serialize_state() -> Dictionary:
	var categories: Array[String] = []
	for category in accepted_categories:
		categories.append(category)

	return {
		"shelf_id": String(shelf_id),
		"shelf_label": shelf_label,
		"shelf_type": String(shelf_type),
		"accepted_categories": categories,
		"capacity_units": capacity_units,
		"current_product_id": String(current_product_id),
		"current_quantity": current_quantity
	}


func get_interaction_prompt(inventory: InventoryContainer, catalog: ProductCatalog) -> String:
	var restock_context := _build_restock_context(inventory, catalog)
	var selected_product := restock_context.get("selected_product") as ProductDefinition
	var localized_shelf_label := get_display_name()
	if selected_product == null:
		if current_quantity > 0:
			return LocalizationManager.text(&"prompt.shelf.stocked_units", {"shelf": localized_shelf_label, "quantity": current_quantity})
		return LocalizationManager.text(&"prompt.shelf.empty", {"shelf": localized_shelf_label})

	if not bool(restock_context.get("can_restock", false)):
		return LocalizationManager.text(&"prompt.shelf.fully_stocked", {"shelf": localized_shelf_label})

	return LocalizationManager.text(
		&"prompt.shelf.tap_stock",
		{
			"product": selected_product.display_name,
			"current": current_quantity,
			"maximum": int(restock_context.get("max_quantity", current_quantity))
		}
	)


func get_display_name() -> String:
	if shelf_label_key != StringName():
		return LocalizationManager.text(shelf_label_key)
	return shelf_label


func set_catalog(catalog: ProductCatalog) -> void:
	_catalog = catalog
	_refresh_visual_state(null)


func restock_from_inventory(inventory: InventoryContainer, catalog: ProductCatalog) -> Dictionary:
	var selected_product: ProductDefinition = _choose_restock_product(inventory, catalog)
	if selected_product == null:
		return {"added_quantity": 0, "product_id": ""}

	var max_quantity := _get_max_quantity_for_product(selected_product)
	var remaining_capacity := maxi(0, max_quantity - current_quantity)
	if remaining_capacity <= 0:
		return {"added_quantity": 0, "product_id": String(selected_product.product_id)}

	var available_quantity := inventory.get_quantity(selected_product.product_id)
	var added_quantity := mini(available_quantity, remaining_capacity)
	if added_quantity <= 0:
		return {"added_quantity": 0, "product_id": String(selected_product.product_id)}

	if current_product_id == StringName():
		current_product_id = selected_product.product_id

	inventory.remove_product(selected_product.product_id, added_quantity)
	current_quantity += added_quantity
	_refresh_visual_state(selected_product)
	shelf_stock_changed.emit(shelf_id, serialize_state())

	return {
		"added_quantity": added_quantity,
		"product_id": String(selected_product.product_id)
	}


func needs_stock(catalog: ProductCatalog) -> bool:
	var product := catalog.get_product(current_product_id)
	if product == null:
		return true
	return current_quantity < _get_max_quantity_for_product(product)


func can_restock_from_inventory(inventory: InventoryContainer, catalog: ProductCatalog) -> bool:
	var restock_context := _build_restock_context(inventory, catalog)
	return bool(restock_context.get("can_restock", false))


func _choose_restock_product(inventory: InventoryContainer, catalog: ProductCatalog) -> ProductDefinition:
	if current_product_id != StringName():
		var current_product := catalog.get_product(current_product_id)
		if current_product != null and inventory.get_quantity(current_product_id) > 0:
			return current_product

	var best_product: ProductDefinition = null
	var best_quantity := 0

	for entry in inventory.serialize():
		var product_id := StringName(String(entry.get("product_id", "")))
		var quantity := int(entry.get("quantity", 0))
		var product := catalog.get_product(product_id)
		if product == null or quantity <= 0 or not _is_product_compatible(product):
			continue
		if quantity > best_quantity:
			best_quantity = quantity
			best_product = product

	return best_product


func _build_restock_context(inventory: InventoryContainer, catalog: ProductCatalog) -> Dictionary:
	if inventory == null or catalog == null:
		return {
			"selected_product": null,
			"max_quantity": current_quantity,
			"can_restock": false
		}

	var selected_product := _choose_restock_product(inventory, catalog)
	if selected_product == null:
		return {
			"selected_product": null,
			"max_quantity": current_quantity,
			"can_restock": false
		}

	var max_quantity := _get_max_quantity_for_product(selected_product)
	return {
		"selected_product": selected_product,
		"max_quantity": max_quantity,
		"can_restock": current_quantity < max_quantity
	}


func _is_product_compatible(product: ProductDefinition) -> bool:
	if not product.can_fit_shelf_type(shelf_type):
		return false
	if accepted_categories.is_empty():
		return true
	return accepted_categories.has(String(product.category))


func _get_max_quantity_for_product(product: ProductDefinition) -> int:
	var units := maxi(1, product.volume_units)
	return maxi(1, capacity_units / units)


func _build_visuals() -> void:
	if _visual_ready:
		return

	_visual_ready = true
	_build_frame()
	_build_product_slots()


func _build_frame() -> void:
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.52, 0.37, 0.23)
	frame_material.roughness = 0.88

	var side_left := _make_mesh_box(Vector3(-0.62, 1.35, 0.0), Vector3(0.10, 2.7, 1.2), frame_material)
	mesh_root.add_child(side_left)
	var side_right := _make_mesh_box(Vector3(0.62, 1.35, 0.0), Vector3(0.10, 2.7, 1.2), frame_material)
	mesh_root.add_child(side_right)
	var back_panel := _make_mesh_box(Vector3(0.0, 1.35, -0.56), Vector3(1.28, 2.7, 0.06), frame_material)
	mesh_root.add_child(back_panel)

	for board_y in [0.22, 1.0, 1.78, 2.56]:
		var board := _make_mesh_box(Vector3(0.0, board_y, 0.0), Vector3(1.32, 0.08, 1.18), frame_material)
		mesh_root.add_child(board)


func _build_product_slots() -> void:
	_slot_nodes.clear()
	_slot_positions.clear()

	var product_material := StandardMaterial3D.new()
	product_material.albedo_color = Color(0.7, 0.7, 0.7)
	product_material.roughness = 0.7

	for row in 3:
		for column in 4:
			var slot_mesh := MeshInstance3D.new()
			slot_mesh.visible = false
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3(0.18, 0.18, 0.18)
			slot_mesh.mesh = box_mesh
			slot_mesh.material_override = product_material.duplicate() as Material

			var slot_position := Vector3(-0.36 + float(column) * 0.24, 0.38 + float(row) * 0.78, -0.06)
			slot_mesh.position = slot_position
			product_root.add_child(slot_mesh)
			_slot_nodes.append(slot_mesh)
			_slot_positions.append(slot_position)


func _refresh_visual_state(product: ProductDefinition) -> void:
	if not _visual_ready:
		return

	var resolved_product: ProductDefinition = product
	if resolved_product == null and _catalog != null and current_product_id != StringName():
		resolved_product = _catalog.get_product(current_product_id)

	var max_visible := mini(current_quantity, _slot_nodes.size())
	for index in _slot_nodes.size():
		var slot_node := _slot_nodes[index]
		slot_node.visible = index < max_visible
		if resolved_product != null:
			slot_node.scale = resolved_product.display_scale
			var slot_material := slot_node.material_override as StandardMaterial3D
			if slot_material != null:
				slot_material.albedo_color = resolved_product.display_color
		slot_node.position = _slot_positions[index]

	if label != null:
		if resolved_product == null and current_quantity <= 0:
			label.text = "%s\n%s" % [get_display_name(), LocalizationManager.text(&"label.shelf.empty")]
		elif resolved_product != null:
			label.text = "%s\n%s x%d" % [get_display_name(), resolved_product.display_name, current_quantity]
		else:
			label.text = "%s\n%s" % [
				get_display_name(),
				LocalizationManager.text(&"label.shelf.stocked", {"quantity": current_quantity})
			]


func _on_locale_changed(_locale_code: StringName, _is_rtl: bool) -> void:
	_refresh_visual_state(null)


func _make_mesh_box(position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = position_value
	var box_mesh := BoxMesh.new()
	box_mesh.size = size_value
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	return mesh_instance
