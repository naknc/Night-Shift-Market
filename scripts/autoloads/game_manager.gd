extends Node

signal boot_progress_changed(progress: float, message: String)
signal boot_failed(message: String)
signal boot_completed()
signal app_state_changed(state: int)

const MAIN_SCENE_PATH: String = "res://scenes/core/main.tscn"
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu/main_menu.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/game/game.tscn")
const SMOKE_TEST_RUNNER_SCRIPT: Script = preload("res://scripts/debug/smoke_test_runner.gd")

enum AppState {
	BOOTSTRAPPING,
	MAIN_MENU,
	LOADING_GAME,
	IN_GAME
}

var _state: AppState = AppState.BOOTSTRAPPING
var _main_root: Node = null
var _boot_requested: bool = false
var _main_scene_cache: PackedScene = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_bootstrap() -> void:
	if _boot_requested:
		return

	_boot_requested = true
	_main_scene_cache = null
	_state = AppState.BOOTSTRAPPING

	SaveManager.initialize()
	LocalizationManager.initialize()
	boot_progress_changed.emit(0.05, LocalizationManager.text(&"bootstrap.step.saved_data"))
	boot_progress_changed.emit(0.12, LocalizationManager.text(&"bootstrap.step.localization"))
	boot_progress_changed.emit(0.18, LocalizationManager.text(&"bootstrap.step.input_map"))
	InputManager.initialize()
	boot_progress_changed.emit(0.30, LocalizationManager.text(&"bootstrap.step.performance"))
	PerformanceManager.apply_startup_profile()
	boot_progress_changed.emit(0.42, LocalizationManager.text(&"bootstrap.step.audio"))
	AudioManager.initialize_from_settings()
	if _is_smoke_test_requested():
		call_deferred("_run_smoke_tests")
		return
	boot_progress_changed.emit(0.60, LocalizationManager.text(&"bootstrap.step.scene"))

	_main_scene_cache = load(MAIN_SCENE_PATH) as PackedScene
	if _main_scene_cache == null:
		_fail_boot("Main scene could not be loaded from %s." % MAIN_SCENE_PATH)
		return

	boot_progress_changed.emit(0.92, LocalizationManager.text(&"bootstrap.step.interface"))
	call_deferred("_complete_boot")


func retry_bootstrap() -> void:
	_boot_requested = false
	_main_scene_cache = null
	start_bootstrap()


func register_main_root(root: Node) -> void:
	_main_root = root
	show_main_menu()


func show_main_menu() -> void:
	if _main_root == null:
		return

	_state = AppState.MAIN_MENU
	_main_root.show_main_menu(MAIN_MENU_SCENE)
	app_state_changed.emit(_state)


func start_new_game() -> void:
	var save_data := SaveManager.create_new_game_save()
	_enter_game(save_data)


func continue_game() -> void:
	var save_data := SaveManager.load_game_data()
	_enter_game(save_data)


func return_to_main_menu() -> void:
	show_main_menu()


func open_pause_menu() -> void:
	if _main_root == null or _state != AppState.IN_GAME:
		return
	_main_root.open_pause_menu()


func close_pause_menu() -> void:
	if _main_root == null:
		return
	_main_root.close_pause_menu()


func request_exit() -> void:
	get_tree().quit()


func _enter_game(save_data: Dictionary) -> void:
	if _main_root == null:
		return

	_state = AppState.LOADING_GAME
	app_state_changed.emit(_state)
	_main_root.show_game(GAME_SCENE, save_data)
	_state = AppState.IN_GAME
	app_state_changed.emit(_state)

func _complete_boot() -> void:
	if _main_scene_cache == null:
		_fail_boot("Main scene was loaded but no PackedScene was returned.")
		return

	boot_progress_changed.emit(0.97, LocalizationManager.text(&"bootstrap.step.finalizing"))
	var change_error := get_tree().change_scene_to_packed(_main_scene_cache)
	if change_error != OK:
		_fail_boot("Scene switch failed with error %s." % change_error)
		return

	await get_tree().process_frame
	_boot_requested = false
	boot_progress_changed.emit(1.0, LocalizationManager.text(&"bootstrap.status.ready"))
	boot_completed.emit()


func _fail_boot(message: String) -> void:
	_boot_requested = false
	push_error(message)
	boot_failed.emit(message)


func _is_smoke_test_requested() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == "--smoke-test":
			return true
	return false


func _run_smoke_tests() -> void:
	var smoke_runner: RefCounted = SMOKE_TEST_RUNNER_SCRIPT.new()
	if smoke_runner == null:
		_fail_boot("Smoke test runner could not be created.")
		get_tree().quit(1)
		return

	var did_pass: bool = await smoke_runner.run(get_tree())
	if did_pass:
		_boot_requested = false
		boot_progress_changed.emit(1.0, LocalizationManager.text(&"bootstrap.status.ready"))
		boot_completed.emit()
		get_tree().quit()
		return

	_fail_boot("Smoke tests failed.")
	get_tree().quit(1)
