extends RefCounted
class_name GameplayContentLoader

const SHELF_LAYOUTS_PATH: String = "res://data/gameplay/shelf_layouts.json"
const DELIVERY_MANIFESTS_PATH: String = "res://data/gameplay/delivery_manifests.json"


func load_shelf_layouts() -> Array[Dictionary]:
	var parsed: Variant = _load_json_file(SHELF_LAYOUTS_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameplayContentLoader expected a dictionary at %s." % SHELF_LAYOUTS_PATH)
		return []

	var raw_layouts: Variant = (parsed as Dictionary).get("layouts", [])
	var layouts: Array[Dictionary] = []
	if raw_layouts is Array:
		for raw_layout in raw_layouts:
			if typeof(raw_layout) != TYPE_DICTIONARY:
				continue
			var layout := _normalize_shelf_layout(raw_layout as Dictionary)
			if not layout.is_empty():
				layouts.append(layout)
	return layouts


func load_delivery_manifest(delivery_id: StringName = &"morning_delivery") -> Array[Dictionary]:
	var parsed: Variant = _load_json_file(DELIVERY_MANIFESTS_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameplayContentLoader expected a dictionary at %s." % DELIVERY_MANIFESTS_PATH)
		return []

	var raw_deliveries: Variant = (parsed as Dictionary).get("deliveries", [])
	if raw_deliveries is Array:
		for raw_delivery in raw_deliveries:
			if typeof(raw_delivery) != TYPE_DICTIONARY:
				continue
			var delivery := raw_delivery as Dictionary
			if StringName(String(delivery.get("delivery_id", ""))) != delivery_id:
				continue

			var raw_boxes: Variant = delivery.get("boxes", [])
			var boxes: Array[Dictionary] = []
			if raw_boxes is Array:
				for raw_box in raw_boxes:
					if typeof(raw_box) != TYPE_DICTIONARY:
						continue
					var normalized_box := _normalize_delivery_box(raw_box as Dictionary)
					if not normalized_box.is_empty():
						boxes.append(normalized_box)
			return boxes

	push_warning("GameplayContentLoader could not find delivery manifest '%s'." % String(delivery_id))
	return []


func _normalize_shelf_layout(raw_layout: Dictionary) -> Dictionary:
	var shelf_id := String(raw_layout.get("shelf_id", ""))
	var shelf_label := String(raw_layout.get("shelf_label", ""))
	var shelf_type := String(raw_layout.get("shelf_type", ""))
	if shelf_id.is_empty() or shelf_label.is_empty() or shelf_type.is_empty():
		return {}

	var accepted_categories := []
	var raw_categories: Variant = raw_layout.get("accepted_categories", [])
	if raw_categories is Array:
		for raw_category in raw_categories:
			accepted_categories.append(String(raw_category))

	var raw_position: Variant = raw_layout.get("position", [])
	if not (raw_position is Array and raw_position.size() >= 3):
		return {}

	return {
		"shelf_id": shelf_id,
		"shelf_label": shelf_label,
		"shelf_label_key": String(raw_layout.get("shelf_label_key", "")),
		"shelf_type": shelf_type,
		"accepted_categories": accepted_categories,
		"capacity_units": maxi(1, int(raw_layout.get("capacity_units", 1))),
		"position": Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
	}


func _normalize_delivery_box(raw_box: Dictionary) -> Dictionary:
	var box_id := String(raw_box.get("box_id", ""))
	var display_name := String(raw_box.get("display_name", ""))
	if box_id.is_empty() or display_name.is_empty():
		return {}

	var offset: Array[float] = [0.0, 0.45, 0.0]
	var raw_offset: Variant = raw_box.get("offset", [])
	if raw_offset is Array and raw_offset.size() >= 3:
		offset = [float(raw_offset[0]), float(raw_offset[1]), float(raw_offset[2])]

	var raw_contents: Variant = raw_box.get("contents", [])
	var contents: Array[Dictionary] = []
	if raw_contents is Array:
		for raw_entry in raw_contents:
			if typeof(raw_entry) != TYPE_DICTIONARY:
				continue
			var entry := raw_entry as Dictionary
			var product_id := String(entry.get("product_id", ""))
			var quantity := int(entry.get("quantity", 0))
			if product_id.is_empty() or quantity <= 0:
				continue
			contents.append({
				"product_id": product_id,
				"quantity": quantity
			})

	if contents.is_empty():
		return {}

	return {
		"box_id": box_id,
		"display_name": display_name,
		"display_name_key": String(raw_box.get("display_name_key", "")),
		"offset": offset,
		"contents": contents
	}


func _load_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameplayContentLoader could not find %s." % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameplayContentLoader could not open %s." % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed
