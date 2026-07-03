extends Node
class_name GameSaveCoordinator

const SAVE_DEBOUNCE_SECONDS: float = 1.25

var player: Node = null
var player_inventory: Node = null
var shelves: Array = []
var delivery_manager: Node = null
var morning_shift_manager: Node = null
var current_day: int = 1
var is_runtime_ready: bool = false
var is_applying_save_data: bool = false

var _save_dirty: bool = false
var _save_timer: Timer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.name = "SaveDebounceTimer"
	_save_timer.one_shot = true
	_save_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_save_timer.timeout.connect(flush_pending_save)
	add_child(_save_timer)


func configure(
	player_node: Node,
	player_inventory_node: Node,
	shelf_nodes: Array,
	delivery_manager_node: Node,
	morning_shift_manager_node: Node
) -> void:
	player = player_node
	player_inventory = player_inventory_node
	shelves = shelf_nodes
	delivery_manager = delivery_manager_node
	morning_shift_manager = morning_shift_manager_node


func request_save(immediate: bool = false) -> void:
	if is_applying_save_data:
		return
	_save_dirty = true
	if immediate:
		flush_pending_save()
		return
	if _save_timer == null:
		return
	_save_timer.start(SAVE_DEBOUNCE_SECONDS)


func flush_pending_save() -> void:
	if not _save_dirty or not is_runtime_ready:
		return
	if player == null or player_inventory == null or delivery_manager == null or morning_shift_manager == null:
		return

	_save_dirty = false
	if _save_timer != null and _save_timer.time_left > 0.0:
		_save_timer.stop()
	SaveManager.write_game_data(_build_save_data_snapshot())


func _build_save_data_snapshot() -> Dictionary:
	var save_data := SaveManager.get_save_data()
	var progress := save_data.get("progress", {}) as Dictionary
	progress["current_day"] = current_day
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
	return save_data


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			flush_pending_save()
