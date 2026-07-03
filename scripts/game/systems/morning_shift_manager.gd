extends Node
class_name MorningShiftManager

signal objective_changed(title: String, detail: String)
signal phase_changed(phase: StringName)

var delivery_manager: Node = null
var player_inventory: Node = null
var shelves: Array = []
var _phase: StringName = &"truck_arrival"


func setup(delivery: Node, inventory: Node, shelf_list: Array) -> void:
	delivery_manager = delivery
	player_inventory = inventory
	shelves = shelf_list

	if delivery_manager != null:
		delivery_manager.delivery_state_changed.connect(_refresh_phase)
		delivery_manager.box_manifest_changed.connect(_refresh_phase)
		delivery_manager.all_boxes_unpacked.connect(_refresh_phase)
	if player_inventory != null:
		player_inventory.inventory_changed.connect(func(_container_id: StringName, _entries: Array[Dictionary]) -> void:
			_refresh_phase()
		)
	for shelf in shelves:
		shelf.shelf_stock_changed.connect(func(_shelf_id: StringName, _data: Dictionary) -> void:
			_refresh_phase()
		)

	_refresh_phase()


func get_phase() -> StringName:
	return _phase


func serialize_state() -> Dictionary:
	return {
		"phase": String(_phase)
	}


func load_state(data: Dictionary) -> void:
	if data.has("phase"):
		_phase = StringName(String(data.get("phase", "truck_arrival")))
	_emit_objective()


func _refresh_phase(_arg_a: Variant = null, _arg_b: Variant = null) -> void:
	var next_phase := _calculate_phase()
	if next_phase != _phase:
		_phase = next_phase
		phase_changed.emit(_phase)
	_emit_objective()


func _calculate_phase() -> StringName:
	if delivery_manager == null or player_inventory == null:
		return &"truck_arrival"

	var catalog := _find_catalog()
	if catalog == null:
		return _phase

	var active_boxes := delivery_manager.get_active_boxes()
	if delivery_manager.get_state() == &"arriving":
		return &"truck_arrival"

	if not active_boxes.is_empty():
		if not delivery_manager.are_all_boxes_in_storage():
			return &"move_boxes_to_storage"
		return &"unpack_boxes"

	for shelf in shelves:
		if shelf.needs_stock(catalog) and shelf.get_interaction_prompt(player_inventory, catalog) != "%s fully stocked" % shelf.shelf_label:
			var prompt := shelf.get_interaction_prompt(player_inventory, catalog)
			if prompt.contains("Tap to stock"):
				return &"restock_shelves"

	return &"morning_complete"


func _emit_objective() -> void:
	match _phase:
		&"truck_arrival":
			objective_changed.emit("Morning Delivery", "Wait for the delivery truck to finish parking at the loading lane.")
		&"move_boxes_to_storage":
			objective_changed.emit("Unload Boxes", "Carry every delivery box from the truck into the backroom storage zone.")
		&"unpack_boxes":
			objective_changed.emit("Unpack Deliveries", "Open each box while it is inside storage to transfer products into player stock inventory.")
		&"restock_shelves":
			objective_changed.emit("Restock Shelves", "Walk to an empty shelf and tap interact to move matching products from inventory onto the shelf.")
		_:
			objective_changed.emit("Store Ready", "Morning prep is complete. Shelves are stocked and the delivery truck has cleared the lane.")


func _find_catalog() -> Node:
	var root_node := get_tree().current_scene
	if root_node == null:
		return null
	var catalog_node := root_node.find_child("ProductCatalog", true, false)
	return catalog_node
