extends Resource
class_name ProductDefinition

@export var product_id: StringName
@export var barcode: String
@export var category: StringName
@export var display_name: String
@export_multiline var description: String
@export var buy_price: float = 0.0
@export var sell_price: float = 0.0
@export var profit: float = 0.0
@export var volume_units: int = 1
@export var weight_kg: float = 0.0
@export var expiration_days: int = 0
@export var model_scene_path: String = ""
@export var texture_path: String = ""
@export var icon_path: String = ""
@export var stack_size: int = 1
@export var shelf_compatibility: PackedStringArray = PackedStringArray()
@export var storage_compatibility: PackedStringArray = PackedStringArray()
@export var pickup_sound_path: String = ""
@export var shelf_sound_path: String = ""
@export var popularity: float = 0.0
@export var unlock_level: int = 1
@export var display_color: Color = Color.WHITE
@export var display_scale: Vector3 = Vector3.ONE


func can_fit_shelf_type(shelf_type: StringName) -> bool:
	if shelf_compatibility.is_empty():
		return true
	return shelf_compatibility.has(String(shelf_type))


func can_fit_storage_type(storage_type: StringName) -> bool:
	if storage_compatibility.is_empty():
		return true
	return storage_compatibility.has(String(storage_type))


func to_inventory_entry(quantity: int) -> Dictionary:
	return {
		"product_id": String(product_id),
		"quantity": quantity
	}
