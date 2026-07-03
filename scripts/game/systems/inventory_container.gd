extends Node
class_name InventoryContainer

signal inventory_changed(container_id: StringName, entries: Array[Dictionary])

@export var container_id: StringName = &"inventory"
@export var max_distinct_stacks: int = 24

var _stacks: Dictionary = {}


func clear() -> void:
	_stacks.clear()
	_emit_inventory_changed()


func get_total_quantity() -> int:
	var total := 0
	for value in _stacks.values():
		total += int(value)
	return total


func get_quantity(product_id: StringName) -> int:
	return int(_stacks.get(String(product_id), 0))


func get_all_quantities() -> Dictionary:
	return _stacks.duplicate(true)


func has_product(product_id: StringName, quantity: int = 1) -> bool:
	return get_quantity(product_id) >= quantity


func get_sorted_entries(catalog: Node) -> Array[Dictionary]:
	var entries := serialize()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var product_a: Variant = catalog.call("get_product", StringName(String(a.get("product_id", ""))))
		var product_b: Variant = catalog.call("get_product", StringName(String(b.get("product_id", ""))))
		if product_a == null or product_b == null:
			return String(a.get("product_id", "")) < String(b.get("product_id", ""))
		return String(product_a.get("display_name")) < String(product_b.get("display_name"))
	)
	return entries


func can_add_product(product_id: StringName, quantity: int) -> bool:
	if quantity <= 0:
		return false
	if _stacks.has(String(product_id)):
		return true
	return _stacks.size() < max_distinct_stacks


func add_product(product_id: StringName, quantity: int) -> int:
	if quantity <= 0 or not can_add_product(product_id, quantity):
		return 0

	var key := String(product_id)
	_stacks[key] = get_quantity(product_id) + quantity
	_emit_inventory_changed()
	return quantity


func add_entries(entries: Array[Dictionary]) -> int:
	var added_total := 0
	for entry in entries:
		var product_id := StringName(String(entry.get("product_id", "")))
		var quantity := int(entry.get("quantity", 0))
		added_total += add_product(product_id, quantity)
	return added_total


func remove_product(product_id: StringName, quantity: int) -> int:
	if quantity <= 0:
		return 0

	var current_quantity := get_quantity(product_id)
	if current_quantity <= 0:
		return 0

	var removed := mini(current_quantity, quantity)
	var remaining := current_quantity - removed
	var key := String(product_id)

	if remaining <= 0:
		_stacks.erase(key)
	else:
		_stacks[key] = remaining

	_emit_inventory_changed()
	return removed


func split_stack(product_id: StringName, quantity: int) -> Dictionary:
	var removed := remove_product(product_id, quantity)
	if removed <= 0:
		return {}
	return {
		"product_id": String(product_id),
		"quantity": removed
	}


func merge_entry(entry: Dictionary) -> int:
	var product_id := StringName(String(entry.get("product_id", "")))
	var quantity := int(entry.get("quantity", 0))
	return add_product(product_id, quantity)


func find_entries(query: String, category: StringName, catalog: Node) -> Array[Dictionary]:
	var lowered_query := query.strip_edges().to_lower()
	var result: Array[Dictionary] = []

	for entry in get_sorted_entries(catalog):
		var product: Variant = catalog.call("get_product", StringName(String(entry.get("product_id", ""))))
		if product == null:
			continue

		if category != StringName() and product.get("category") != category:
			continue

		if lowered_query.is_empty():
			result.append(entry)
			continue

		var haystack := "%s %s %s" % [String(product.get("display_name")), String(product.get("description")), String(product.get("barcode"))]
		if haystack.to_lower().contains(lowered_query):
			result.append(entry)

	return result


func serialize() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _stacks.keys():
		var quantity := int(_stacks[key])
		if quantity <= 0:
			continue
		result.append({
			"product_id": String(key),
			"quantity": quantity
		})
	return result


func load_from_data(entries: Array) -> void:
	_stacks.clear()
	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry := raw_entry as Dictionary
		var product_id := String(entry.get("product_id", ""))
		var quantity := int(entry.get("quantity", 0))
		if product_id.is_empty() or quantity <= 0:
			continue
		_stacks[product_id] = quantity
	_emit_inventory_changed()


func _emit_inventory_changed() -> void:
	inventory_changed.emit(container_id, serialize())
