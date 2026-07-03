extends Node
class_name MainRoot

const SETTINGS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/settings/settings_panel.tscn")

@onready var world_root: Node3D = $WorldRoot
@onready var screen_root: Control = $UIRoot/ScreenRoot
@onready var overlay_root: Control = $UIRoot/OverlayRoot

var _active_screen: Control = null
var _active_game: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if overlay_root.get_child_count() > 0:
		return

	var panel := SETTINGS_PANEL_SCENE.instantiate() as Control
	if panel == null:
		push_error("MainRoot could not instantiate the settings panel.")
		return

	if panel.has_signal("closed"):
		panel.connect("closed", Callable(self, "_close_settings_overlay"))
	overlay_root.add_child(panel)


func _close_settings_overlay() -> void:
	_clear_overlay()


func _clear_screen() -> void:
	if is_instance_valid(_active_screen):
		_active_screen.queue_free()
	_active_screen = null


func _clear_world() -> void:
	if is_instance_valid(_active_game):
		_active_game.queue_free()
	_active_game = null


func _clear_overlay() -> void:
	for child in overlay_root.get_children():
		child.queue_free()
