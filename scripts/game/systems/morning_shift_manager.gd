extends Node
class_name MorningShiftManager

signal objective_changed(title: String, detail: String)
signal phase_changed(phase: StringName)

var delivery_manager: DeliveryManager = null
var player_inventory: InventoryContainer = null
var product_catalog: ProductCatalog = null
var shelves: Array[StockShelf] = []
var _phase: StringName = &"truck_arrival"


func setup(delivery: DeliveryManager, inventory: InventoryContainer, catalog: ProductCatalog, shelf_list: Array[StockShelf]) -> void:
	delivery_manager = delivery
	player_inventory = inventory
	product_catalog = catalog
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
	refresh_objective()


func _refresh_phase(_arg_a: Variant = null, _arg_b: Variant = null) -> void:
	var next_phase: StringName = _calculate_phase()
	if next_phase != _phase:
		_phase = next_phase
		phase_changed.emit(_phase)
	refresh_objective()


func _calculate_phase() -> StringName:
	if delivery_manager == null or player_inventory == null:
		return &"truck_arrival"
	if product_catalog == null:
		return _phase

	var active_boxes := delivery_manager.get_active_boxes()
	if delivery_manager.get_state() == &"arriving":
		return &"truck_arrival"

	if not active_boxes.is_empty():
		if not delivery_manager.are_all_boxes_in_storage():
			return &"move_boxes_to_storage"
		return &"unpack_boxes"

	for shelf in shelves:
		if shelf.needs_stock(product_catalog) and shelf.can_restock_from_inventory(player_inventory, product_catalog):
			return &"restock_shelves"

	return &"morning_complete"


func refresh_objective() -> void:
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
