extends Node3D
class_name GameRoot

const PLAYER_SCENE: PackedScene = preload("res://scenes/prefabs/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/prefabs/ui/game_hud.tscn")
const SAVE_COORDINATOR_SCRIPT: Script = preload("res://scripts/game/coordinators/game_save_coordinator.gd")
const WORLD_BUILDER_SCRIPT: Script = preload("res://scripts/game/builders/market_world_builder.gd")

@onready var world_root: Node3D = $WorldRoot
@onready var interactable_root: Node3D = $InteractableRoot
@onready var ui_layer: CanvasLayer = $UiLayer
@onready var systems_root: Node = $Systems

var product_catalog: ProductCatalog
var player_inventory: InventoryContainer
var delivery_manager: DeliveryManager
var morning_shift_manager: MorningShiftManager
var storage_zone: StorageZone
var shelves: Array[StockShelf] = []
var player: PlayerController
var hud: GameHud

var _pending_save_data: Dictionary = {}
var _is_runtime_ready: bool = false
var _current_day: int = 1
var _current_phase_text: String = ""
var _carried_label: String = ""
var _save_coordinator: Node = null
var _world_builder: RefCounted = WORLD_BUILDER_SCRIPT.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	_build_runtime()
	_is_runtime_ready = true
	if _save_coordinator != null:
		_save_coordinator.is_runtime_ready = true

	if _pending_save_data.is_empty():
		_apply_save_data(SaveManager.get_save_data())
	else:
		_apply_save_data(_pending_save_data)


func _exit_tree() -> void:
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed)
	if _save_coordinator != null:
		_save_coordinator.flush_pending_save()


func configure_from_save(save_data: Dictionary) -> void:
	_pending_save_data = save_data.duplicate(true)
	if _is_runtime_ready:
		_apply_save_data(_pending_save_data)


func get_interactable_root() -> Node3D:
	return interactable_root


func try_unpack_box(box: DeliveryBox) -> void:
	if box == null:
		return
	if not box.is_inside_storage():
		_show_notification(LocalizationManager.text(&"notification.move_box_to_storage"))
		return

	var unpacked := delivery_manager.process_box_unpack(box)
	if unpacked.is_empty():
		_show_notification(LocalizationManager.text(&"notification.box_already_unpacked"))
		return

	player_inventory.add_entries(unpacked)
	_show_notification(
		LocalizationManager.text(
			&"notification.box_unpacked_to_inventory",
			{"box": box.get_display_name()}
		)
	)
	_refresh_inventory_hud()
	_request_save()


func try_restock_shelf(shelf: StockShelf) -> void:
	if shelf == null:
		return

	var result := shelf.restock_from_inventory(player_inventory, product_catalog)
	var added_quantity := int(result.get("added_quantity", 0))
	if added_quantity <= 0:
		_show_notification(
			LocalizationManager.text(
				&"notification.shelf_cannot_stock",
				{"shelf": shelf.get_display_name()}
			)
		)
		return

	var product := product_catalog.get_product(StringName(String(result.get("product_id", ""))))
	var product_name := product.display_name if product != null else "product"
	_show_notification(
		LocalizationManager.text(
			&"notification.shelf_stocked",
			{
				"shelf": shelf.get_display_name(),
				"quantity": added_quantity,
				"product": product_name
			}
		)
	)
	_refresh_inventory_hud()
	_request_save()


func _build_runtime() -> void:
	_build_world_shell()
	_build_systems()
	_build_player_and_hud()
	_build_coordinators()
	_connect_runtime_signals()


func _build_world_shell() -> void:
	var world_context: Dictionary = _world_builder.build(world_root, interactable_root)
	storage_zone = world_context.get("storage_zone", null) as StorageZone
	shelves.clear()
	var raw_shelves: Array = world_context.get("shelves", [])
	for shelf in raw_shelves:
		if shelf is StockShelf:
			shelves.append(shelf)


func _build_systems() -> void:
	product_catalog = load("res://scripts/game/systems/product_catalog.gd").new()
	product_catalog.name = "ProductCatalog"
	systems_root.add_child(product_catalog)

	player_inventory = load("res://scripts/game/systems/inventory_container.gd").new()
	player_inventory.name = "PlayerInventory"
	player_inventory.container_id = &"player_inventory"
	player_inventory.max_distinct_stacks = 16
	systems_root.add_child(player_inventory)

	delivery_manager = load("res://scripts/game/systems/delivery_manager.gd").new()
	delivery_manager.name = "DeliveryManager"
	world_root.add_child(delivery_manager)

	morning_shift_manager = load("res://scripts/game/systems/morning_shift_manager.gd").new()
	morning_shift_manager.name = "MorningShiftManager"
	systems_root.add_child(morning_shift_manager)


func _build_player_and_hud() -> void:
	player = PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	player.configure_game_root(self)
	world_root.add_child(player)

	hud = HUD_SCENE.instantiate() as GameHud
	hud.name = "GameHud"
	ui_layer.add_child(hud)


func _build_coordinators() -> void:
	if _save_coordinator != null:
		return
	_save_coordinator = SAVE_COORDINATOR_SCRIPT.new()
	_save_coordinator.name = "GameSaveCoordinator"
	add_child(_save_coordinator)
	_save_coordinator.configure(player, player_inventory, shelves, delivery_manager, morning_shift_manager)
	_save_coordinator.current_day = _current_day


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

	for shelf in shelves:
		shelf.set_catalog(product_catalog)

	morning_shift_manager.setup(delivery_manager, player_inventory, product_catalog, shelves)
	morning_shift_manager.connect("objective_changed", func(title: String, detail: String) -> void:
		hud.set_objective(title, detail)
	)
	morning_shift_manager.connect("phase_changed", func(phase: StringName) -> void:
		_current_phase_text = _phase_to_text(phase)
		_refresh_status_hud()
		_request_save()
	)

	delivery_manager.connect("box_manifest_changed", Callable(self, "_request_save"))
	delivery_manager.connect("all_boxes_unpacked", func() -> void:
		_show_notification(LocalizationManager.text(&"notification.all_boxes_unpacked"))
	)


func _apply_save_data(save_data: Dictionary) -> void:
	if _save_coordinator != null:
		_save_coordinator.is_applying_save_data = true

	var inventories := save_data.get("inventories", {}) as Dictionary
	player_inventory.load_from_data(inventories.get("player", []) as Array)

	var shelf_state_by_id := {}
	var saved_shelves: Array = save_data.get("shelves", [])
	if saved_shelves is Array:
		for raw_shelf in saved_shelves:
			if typeof(raw_shelf) != TYPE_DICTIONARY:
				continue
			var shelf_dict := raw_shelf as Dictionary
			shelf_state_by_id[String(shelf_dict.get("shelf_id", ""))] = shelf_dict

	for shelf in shelves:
		var shelf_id := String(shelf.shelf_id)
		if shelf_state_by_id.has(shelf_id):
			shelf.configure_from_data(shelf_state_by_id[shelf_id] as Dictionary)

	var delivery_state := save_data.get("delivery", {}) as Dictionary
	delivery_manager.initialize_delivery(delivery_state, storage_zone, interactable_root)

	var player_state := save_data.get("player", {}) as Dictionary
	var position_data: Array = player_state.get("position", [0.0, 0.0, 5.2])
	var player_position := Vector3(0.0, 0.0, 5.2)
	if position_data is Array and position_data.size() >= 3:
		player_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	player.apply_saved_view(player_position, float(player_state.get("yaw", PI)), float(player_state.get("pitch", 0.0)))

	var progress := save_data.get("progress", {}) as Dictionary
	_current_day = int(progress.get("current_day", 1))
	if _save_coordinator != null:
		_save_coordinator.current_day = _current_day

	morning_shift_manager.load_state(save_data.get("morning_shift", {}) as Dictionary)
	_current_phase_text = _phase_to_text(morning_shift_manager.get_phase())
	_refresh_inventory_hud()
	_refresh_status_hud()

	if _save_coordinator != null:
		_save_coordinator.is_applying_save_data = false


func _request_save(immediate: bool = false) -> void:
	if _save_coordinator == null:
		return
	_save_coordinator.current_day = _current_day
	_save_coordinator.request_save(immediate)


func _refresh_inventory_hud() -> void:
	var lines := PackedStringArray()
	for entry in player_inventory.get_sorted_entries(product_catalog):
		var product := product_catalog.get_product(StringName(String(entry.get("product_id", ""))))
		if product == null:
			continue
		lines.append("%s x%d" % [product.display_name, int(entry.get("quantity", 0))])
	hud.set_inventory_lines(lines)


func _refresh_status_hud() -> void:
	hud.set_status(_current_day, _current_phase_text, _carried_label)


func _show_notification(text_value: String) -> void:
	if hud != null:
		hud.show_notification(text_value)


func _on_carried_box_changed(label: String) -> void:
	_carried_label = label
	_refresh_status_hud()


func _on_pause_requested() -> void:
	_request_save(true)
	GameManager.open_pause_menu()


func _phase_to_text(phase: StringName) -> String:
	match phase:
		&"truck_arrival":
			return LocalizationManager.text(&"phase.truck_arrival")
		&"move_boxes_to_storage":
			return LocalizationManager.text(&"phase.move_boxes_to_storage")
		&"unpack_boxes":
			return LocalizationManager.text(&"phase.unpack_boxes")
		&"restock_shelves":
			return LocalizationManager.text(&"phase.restock_shelves")
		_:
			return LocalizationManager.text(&"phase.morning_complete")


func _on_locale_changed(_locale_code: StringName, _is_rtl: bool) -> void:
	_current_phase_text = _phase_to_text(morning_shift_manager.get_phase())
	if morning_shift_manager != null:
		morning_shift_manager.refresh_objective()
	_refresh_inventory_hud()
	_refresh_status_hud()
