extends RefCounted
class_name SmokeTestRunner

const MAIN_ROOT_SCENE: PackedScene = preload("res://scenes/core/main.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu/main_menu.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/game/game.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause/pause_menu.tscn")
const SETTINGS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/settings/settings_panel.tscn")
const GAME_HUD_SCENE: PackedScene = preload("res://scenes/prefabs/ui/game_hud.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/prefabs/player/player.tscn")
const DELIVERY_BOX_SCENE: PackedScene = preload("res://scenes/prefabs/world/delivery_box.tscn")
const STOCK_SHELF_SCENE: PackedScene = preload("res://scenes/prefabs/world/stock_shelf.tscn")

var _tree: SceneTree = null


func run(tree: SceneTree) -> bool:
	_tree = tree
	print("SMOKE: starting Night Shift Market validation")

	if not _test_input_map():
		return false
	if not _test_performance_profile():
		return false
	if not _test_localization_tables():
		return false
	if not _test_scene_instantiation():
		return false
	if not await _test_runtime_flow():
		return false
	if not _test_save_round_trip_and_recovery():
		return false

	print("SMOKE: all validations passed")
	return true


func _test_input_map() -> bool:
	var required_actions: Array[StringName] = [
		InputManager.ACTION_MOVE_LEFT,
		InputManager.ACTION_MOVE_RIGHT,
		InputManager.ACTION_MOVE_FORWARD,
		InputManager.ACTION_MOVE_BACK,
		InputManager.ACTION_RUN,
		InputManager.ACTION_INTERACT,
		InputManager.ACTION_GRAB,
		InputManager.ACTION_PAUSE
	]

	for action in required_actions:
		if not InputMap.has_action(action):
			return _fail("Missing input action: %s" % String(action))

	print("SMOKE: input map verified")
	return true


func _test_performance_profile() -> bool:
	if Engine.max_fps != PerformanceManager.TARGET_FPS:
		return _fail("PerformanceManager did not apply the expected max FPS.")
	if Engine.physics_ticks_per_second != PerformanceManager.TARGET_FPS:
		return _fail("PerformanceManager did not apply the expected physics tick rate.")

	print("SMOKE: performance profile verified")
	return true


func _test_localization_tables() -> bool:
	var locales := LocalizationManager.get_supported_locales()
	if locales.is_empty():
		return _fail("LocalizationManager reported no supported locales.")

	for entry in locales:
		var locale_code := StringName(String(entry.get("code", "")))
		if locale_code == StringName():
			return _fail("Localization manifest contains an empty locale code.")

		var pause_title := LocalizationManager._lookup_translation(locale_code, &"pause.title")
		var pause_resume := LocalizationManager._lookup_translation(locale_code, &"pause.resume")
		if pause_title.is_empty() or pause_resume.is_empty():
			return _fail("Locale %s is missing pause menu translations." % String(locale_code))

	print("SMOKE: localization coverage verified")
	return true


func _test_scene_instantiation() -> bool:
	var scenes_to_validate: Array[PackedScene] = [
		MAIN_ROOT_SCENE,
		MAIN_MENU_SCENE,
		GAME_SCENE,
		PAUSE_MENU_SCENE,
		SETTINGS_PANEL_SCENE,
		GAME_HUD_SCENE,
		PLAYER_SCENE,
		DELIVERY_BOX_SCENE,
		STOCK_SHELF_SCENE
	]

	for scene in scenes_to_validate:
		if scene == null:
			return _fail("A required PackedScene reference could not be loaded.")
		var instance := scene.instantiate()
		if instance == null:
			return _fail("A required scene failed to instantiate.")
		instance.free()

	print("SMOKE: scene instantiation verified")
	return true


func _test_runtime_flow() -> bool:
	var main_root := MAIN_ROOT_SCENE.instantiate()
	if main_root == null:
		return _fail("Main root failed to instantiate for runtime validation.")

	_tree.root.add_child(main_root)
	await _tree.process_frame
	await _tree.process_frame

	var screen_root := main_root.get_node_or_null("UIRoot/ScreenRoot") as Control
	var overlay_root := main_root.get_node_or_null("UIRoot/OverlayRoot") as Control
	var world_root := main_root.get_node_or_null("WorldRoot") as Node3D
	if screen_root == null or overlay_root == null or world_root == null:
		main_root.queue_free()
		await _tree.process_frame
		return _fail("Main root is missing critical child nodes.")

	if screen_root.get_child_count() != 1:
		main_root.queue_free()
		await _tree.process_frame
		return _fail("Main menu was not shown after main root registration.")

	GameManager.start_new_game()
	await _tree.process_frame
	await _tree.process_frame

	if world_root.get_child_count() != 1:
		main_root.queue_free()
		await _tree.process_frame
		return _fail("Game scene was not attached to the world root.")

	GameManager.open_pause_menu()
	await _tree.process_frame
	if overlay_root.get_node_or_null("PauseMenu") == null:
		main_root.queue_free()
		await _tree.process_frame
		return _fail("Pause menu did not open during runtime validation.")
	if not _tree.paused:
		main_root.queue_free()
		await _tree.process_frame
		return _fail("Tree pause state was not enabled when opening the pause menu.")

	GameManager.close_pause_menu()
	await _tree.process_frame
	if overlay_root.get_node_or_null("PauseMenu") != null:
		main_root.queue_free()
		await _tree.process_frame
		return _fail("Pause menu did not close during runtime validation.")
	if _tree.paused:
		main_root.queue_free()
		await _tree.process_frame
		return _fail("Tree pause state was not cleared after closing the pause menu.")

	main_root.queue_free()
	await _tree.process_frame
	print("SMOKE: runtime flow verified")
	return true


func _test_save_round_trip_and_recovery() -> bool:
	var backups := _capture_save_slots()
	if backups.is_empty():
		return _fail("Could not capture current save slots for smoke validation.")

	var result := _run_save_round_trip_validation()
	_restore_save_slots(backups)
	return result


func _run_save_round_trip_validation() -> bool:
	_delete_user_file(SaveManager.SAVE_PATH)
	_delete_user_file(SaveManager.SAVE_BACKUP_PATH)
	_delete_user_file(SaveManager.SAVE_TEMP_PATH)

	var save_data := SaveManager.create_new_game_save()
	var progress := save_data.get("progress", {}) as Dictionary
	progress["current_day"] = 3
	progress["money"] = 275
	save_data["progress"] = progress

	var delivery := save_data.get("delivery", {}) as Dictionary
	delivery["state"] = "storage"
	save_data["delivery"] = delivery
	SaveManager.write_game_data(save_data)

	var reloaded_primary := SaveManager._read_save_file(SaveManager.SAVE_PATH)
	if int((reloaded_primary.get("progress", {}) as Dictionary).get("current_day", 0)) != 3:
		return _fail("Primary save round trip did not preserve current_day.")

	var primary_text := _read_user_file(SaveManager.SAVE_PATH)
	if primary_text.is_empty():
		return _fail("Primary save slot could not be read back for recovery validation.")
	if not _write_user_file(SaveManager.SAVE_BACKUP_PATH, primary_text):
		return _fail("Backup save slot could not be prepared for recovery validation.")
	if not _write_user_file(SaveManager.SAVE_PATH, "{\"broken\": true}"):
		return _fail("Primary save slot could not be corrupted for recovery validation.")

	var recovered_save := SaveManager._load_save_data_from_disk()
	var recovered_progress := recovered_save.get("progress", {}) as Dictionary
	if int(recovered_progress.get("current_day", 0)) != 3:
		return _fail("Backup recovery did not restore the expected save contents.")

	print("SMOKE: save round trip and recovery verified")
	return true


func _capture_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_BACKUP_PATH, SaveManager.SAVE_TEMP_PATH]:
		slots.append({
			"path": path,
			"exists": FileAccess.file_exists(path),
			"contents": _read_user_file(path)
		})
	return slots


func _restore_save_slots(slots: Array[Dictionary]) -> void:
	for slot in slots:
		var path := String(slot.get("path", ""))
		var exists := bool(slot.get("exists", false))
		var contents := String(slot.get("contents", ""))
		if exists:
			_write_user_file(path, contents)
		else:
			_delete_user_file(path)


func _read_user_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents := file.get_as_text()
	file.close()
	return contents


func _write_user_file(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true


func _delete_user_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> bool:
	push_error("SMOKE: %s" % message)
	return false
