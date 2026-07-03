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
	var next_phase: StringName = _calculate_phase()
	if next_phase != _phase:
		_phase = next_phase
		phase_changed.emit(_phase)
	_emit_objective()


func _calculate_phase() -> StringName:
	if delivery_manager == null or player_inventory == null:
		return &"truck_arrival"

	var catalog: Node = _find_catalog()
	if catalog == null:
		return _phase

	var active_boxes: Array = delivery_manager.call("get_active_boxes")
	if StringName(delivery_manager.call("get_state")) == &"arriving":
		return &"truck_arrival"

	if not active_boxes.is_empty():
		if not bool(delivery_manager.call("are_all_boxes_in_storage")):
			return &"move_boxes_to_storage"
		return &"unpack_boxes"

	for shelf in shelves:
		if bool(shelf.call("needs_stock", catalog)) and bool(shelf.call("can_restock_from_inventory", player_inventory, catalog)):
			return &"restock_shelves"

	return &"morning_complete"


func _emit_objective() -> void:
	match _phase:
		&"truck_arrival":
			objective_changed.emit(LocalizationManager.text(&"objective.truck_arrival.title"), LocalizationManager.text(&"objective.truck_arrival.detail"))
		&"move_boxes_to_storage":
			objective_changed.emit(LocalizationManager.text(&"objective.move_boxes_to_storage.title"), LocalizationManager.text(&"objective.move_boxes_to_storage.detail"))
		&"unpack_boxes":
			objective_changed.emit(LocalizationManager.text(&"objective.unpack_boxes.title"), LocalizationManager.text(&"objective.unpack_boxes.detail"))
		&"restock_shelves":
			objective_changed.emit(LocalizationManager.text(&"objective.restock_shelves.title"), LocalizationManager.text(&"objective.restock_shelves.detail"))
		_:
			objective_changed.emit(LocalizationManager.text(&"objective.morning_complete.title"), LocalizationManager.text(&"objective.morning_complete.detail"))


func _find_catalog() -> Node:
	var root_node := get_tree().current_scene
	if root_node == null:
		return null
	var catalog_node: Node = root_node.find_child("ProductCatalog", true, false)
	return catalog_node
