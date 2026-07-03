extends Node
class_name MainRoot

const SETTINGS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/settings/settings_panel.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause/pause_menu.tscn")

@onready var world_root: Node3D = $WorldRoot
@onready var screen_root: Control = $UIRoot/ScreenRoot
@onready var overlay_root: Control = $UIRoot/OverlayRoot

var _active_screen: Control = null
var _active_game: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_root.visible = false
	GameManager.register_main_root(self)


func show_main_menu(menu_scene: PackedScene) -> void:
	_clear_overlay()
	_clear_world()
	_clear_screen()

	var menu := menu_scene.instantiate() as Control
	if menu == null:
		push_error("MainRoot could not instantiate the main menu scene.")
		return

	_active_screen = menu
	screen_root.add_child(menu)
	if menu.has_signal("new_game_requested"):
		menu.connect("new_game_requested", Callable(GameManager, "start_new_game"))
	if menu.has_signal("continue_game_requested"):
		menu.connect("continue_game_requested", Callable(GameManager, "continue_game"))
	if menu.has_signal("settings_requested"):
		menu.connect("settings_requested", Callable(self, "_open_settings"))
	if menu.has_signal("exit_requested"):
		menu.connect("exit_requested", Callable(GameManager, "request_exit"))
	if menu.has_method("refresh_state"):
		menu.call("refresh_state", SaveManager.has_save_data())


func show_game(game_scene: PackedScene, save_data: Dictionary) -> void:
	_clear_overlay()
	_clear_screen()
	_clear_world()

	var game_instance := game_scene.instantiate() as Node3D
	if game_instance == null:
		push_error("MainRoot could not instantiate the game scene.")
		return

	_active_game = game_instance
	world_root.add_child(game_instance)

	if game_instance.has_method("configure_from_save"):
		game_instance.call("configure_from_save", save_data)


func _open_settings() -> void:
	if overlay_root.get_node_or_null("SettingsPanel") != null:
		return

	var panel := SETTINGS_PANEL_SCENE.instantiate() as Control
	if panel == null:
		push_error("MainRoot could not instantiate the settings panel.")
		return

	if panel.has_signal("closed"):
		panel.connect("closed", Callable(self, "_close_settings_overlay"))
	overlay_root.visible = true
	overlay_root.add_child(panel)


func open_pause_menu() -> void:
	if _active_game == null:
		return
	if overlay_root.get_node_or_null("PauseMenu") != null:
		return

	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	if menu == null:
		push_error("MainRoot could not instantiate the pause menu.")
		return

	if menu.has_signal("resume_requested"):
		menu.connect("resume_requested", Callable(self, "close_pause_menu"))
	if menu.has_signal("settings_requested"):
		menu.connect("settings_requested", Callable(self, "_open_settings"))
	if menu.has_signal("main_menu_requested"):
		menu.connect("main_menu_requested", Callable(self, "_return_to_main_menu_from_pause"))

	overlay_root.visible = true
	overlay_root.add_child(menu)
	get_tree().paused = true


func close_pause_menu() -> void:
	var pause_menu := overlay_root.get_node_or_null("PauseMenu")
	if pause_menu != null:
		pause_menu.queue_free()
	if overlay_root.get_node_or_null("SettingsPanel") == null:
		overlay_root.visible = false
		get_tree().paused = false


func _close_settings_overlay() -> void:
	var panel := overlay_root.get_node_or_null("SettingsPanel")
	if panel != null:
		panel.queue_free()
	if overlay_root.get_node_or_null("PauseMenu") == null:
		overlay_root.visible = false
		get_tree().paused = false


func _return_to_main_menu_from_pause() -> void:
	_clear_overlay()
	GameManager.return_to_main_menu()


func _clear_screen() -> void:
	if is_instance_valid(_active_screen):
		_active_screen.queue_free()
	_active_screen = null


func _clear_world() -> void:
	if is_instance_valid(_active_game):
		_active_game.queue_free()
	_active_game = null


func _clear_overlay() -> void:
	get_tree().paused = false
	overlay_root.visible = false
	for child in overlay_root.get_children():
		child.queue_free()
