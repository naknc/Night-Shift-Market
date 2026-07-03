extends Node

signal performance_profile_applied(profile_name: StringName)
signal fps_visibility_changed(visible: bool)

const TARGET_FPS: int = 60

var _fps_layer: CanvasLayer
var _fps_label: Label
var _show_fps: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func apply_startup_profile() -> void:
	Engine.max_fps = TARGET_FPS
	Engine.physics_ticks_per_second = TARGET_FPS
	_show_fps = bool(SaveManager.get_setting(&"ui", &"show_fps", false))
	_set_fps_overlay_visible(_show_fps)
	performance_profile_applied.emit(&"mobile_balanced")


func set_show_fps(visible: bool) -> void:
	_show_fps = visible
	SaveManager.set_setting(&"ui", &"show_fps", visible)
	_set_fps_overlay_visible(visible)
	fps_visibility_changed.emit(visible)


func is_show_fps_enabled() -> bool:
	return _show_fps


func _process(_delta: float) -> void:
	if _fps_label == null or not _show_fps:
		return

	_fps_label.text = "FPS %d" % Engine.get_frames_per_second()


func _set_fps_overlay_visible(visible: bool) -> void:
	if visible:
		_ensure_fps_overlay()

	if _fps_layer != null:
		_fps_layer.visible = visible


func _ensure_fps_overlay() -> void:
	if _fps_layer != null:
		return

	_fps_layer = CanvasLayer.new()
	_fps_layer.name = "PerformanceOverlay"
	_fps_layer.layer = 90
	add_child(_fps_layer)

	var margin := MarginContainer.new()
	margin.name = "OverlayMargin"
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.offset_left = 16.0
	margin.offset_top = 16.0
	margin.offset_right = 236.0
	margin.offset_bottom = 72.0
	_fps_layer.add_child(margin)

	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.text = "FPS 0"
	_fps_label.add_theme_font_size_override("font_size", 20)
	_fps_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84))
	_fps_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	margin.add_child(_fps_label)
