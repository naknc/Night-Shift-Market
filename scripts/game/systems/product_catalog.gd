extends Node
class_name ProductCatalog

var _products: Dictionary = {}


func _ready() -> void:
	if _products.is_empty():
		_register_default_products()


func get_product(product_id: StringName) -> ProductDefinition:
	return _products.get(String(product_id), null) as ProductDefinition


func get_all_products() -> Array[ProductDefinition]:
	var result: Array[ProductDefinition] = []
	for definition in _products.values():
		result.append(definition as ProductDefinition)
	return result


func get_product_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in _products.keys():
		ids.append(String(key))
	return ids


func get_products_for_category(category: StringName) -> Array[ProductDefinition]:
	var result: Array[ProductDefinition] = []
	for definition in get_all_products():
		if definition.category == category:
			result.append(definition)
	return result


func get_best_match_for_shelf(shelf_type: StringName, available_quantities: Dictionary) -> ProductDefinition:
	var best_product: ProductDefinition = null
	var best_quantity: int = 0

	for key in available_quantities.keys():
		var quantity := int(available_quantities[key])
		if quantity <= 0:
			continue

		var product := get_product(StringName(str(key)))
		if product == null or not product.can_fit_shelf_type(shelf_type):
			continue

		if quantity > best_quantity:
			best_quantity = quantity
			best_product = product

	return best_product


func _register_default_products() -> void:
	_add_product(
		_make_product(
			&"sparkling_water",
			"8690001100011",
			&"drink",
			"Sparkling Water 1L",
			"Cold sparkling water with a crisp finish for the beverage cooler.",
			0.42,
			1.25,
			0.83,
			1,
			1.0,
			120,
			24,
			PackedStringArray(["drink_shelf", "cold_shelf"]),
			PackedStringArray(["storage_rack", "cold_storage"]),
			0.62,
			1,
			Color(0.35, 0.78, 0.95),
			Vector3(0.26, 0.46, 0.26)
		)
	)
	_add_product(
		_make_product(
			&"orange_soda",
			"8690001100028",
			&"drink",
			"Orange Soda 330ml",
			"Bright citrus soda sold chilled near the checkout impulse shelves.",
			0.31,
			1.10,
			0.79,
			1,
			0.35,
			180,
			24,
			PackedStringArray(["drink_shelf", "cold_shelf"]),
			PackedStringArray(["storage_rack", "cold_storage"]),
			0.75,
			1,
			Color(0.96, 0.54, 0.19),
			Vector3(0.22, 0.34, 0.22)
		)
	)
	_add_product(
		_make_product(
			&"sea_salt_chips",
			"8690002200145",
			&"snack",
			"Sea Salt Chips",
			"Light crunchy potato chips with a matte kraft-paper pack.",
			0.55,
			1.95,
			1.40,
			1,
			0.18,
			240,
			16,
			PackedStringArray(["snack_shelf"]),
			PackedStringArray(["storage_rack"]),
			0.81,
			1,
			Color(0.94, 0.82, 0.48),
			Vector3(0.34, 0.42, 0.14)
		)
	)
	_add_product(
		_make_product(
			&"granola_bar",
			"8690002200183",
			&"snack",
			"Hazelnut Granola Bar",
			"Single-serve snack bar popular with students and quick shoppers.",
			0.20,
			0.85,
			0.65,
			1,
			0.08,
			365,
			32,
			PackedStringArray(["snack_shelf"]),
			PackedStringArray(["storage_rack"]),
			0.58,
			1,
			Color(0.72, 0.44, 0.20),
			Vector3(0.28, 0.10, 0.12)
		)
	)
	_add_product(
		_make_product(
			&"green_apple",
			"PLU4017",
			&"fruit",
			"Green Apple",
			"Fresh tart apples stocked loose in the produce shelf.",
			0.18,
			0.60,
			0.42,
			1,
			0.15,
			18,
			40,
			PackedStringArray(["fruit_shelf"]),
			PackedStringArray(["storage_rack", "produce_crate"]),
			0.67,
			1,
			Color(0.48, 0.78, 0.28),
			Vector3(0.18, 0.18, 0.18)
		)
	)
	_add_product(
		_make_product(
			&"clementine_pack",
			"8690003300060",
			&"fruit",
			"Clementine Net Pack",
			"Sweet clementines packed in a compact carry net for family shoppers.",
			0.74,
			2.30,
			1.56,
			2,
			0.65,
			14,
			12,
			PackedStringArray(["fruit_shelf"]),
			PackedStringArray(["storage_rack", "produce_crate"]),
			0.71,
			2,
			Color(0.93, 0.49, 0.18),
			Vector3(0.30, 0.26, 0.30)
		)
	)


func _add_product(product: ProductDefinition) -> void:
	_products[String(product.product_id)] = product


func _make_product(
	product_id: StringName,
	barcode: String,
	category: StringName,
	display_name: String,
	description: String,
	buy_price: float,
	sell_price: float,
	profit: float,
	volume_units: int,
	weight_kg: float,
	expiration_days: int,
	stack_size: int,
	shelf_compatibility: PackedStringArray,
	storage_compatibility: PackedStringArray,
	popularity: float,
	unlock_level: int,
	display_color: Color,
	display_scale: Vector3
) -> ProductDefinition:
	var product := ProductDefinition.new()
	product.product_id = product_id
	product.barcode = barcode
	product.category = category
	product.display_name = display_name
	product.description = description
	product.buy_price = buy_price
	product.sell_price = sell_price
	product.profit = profit
	product.volume_units = volume_units
	product.weight_kg = weight_kg
	product.expiration_days = expiration_days
	product.stack_size = stack_size
	product.shelf_compatibility = shelf_compatibility
	product.storage_compatibility = storage_compatibility
	product.popularity = popularity
	product.unlock_level = unlock_level
	product.display_color = display_color
	product.display_scale = display_scale
	return product
