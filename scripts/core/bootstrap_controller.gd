extends Control
class_name BootstrapController

var _title_label: Label
var _status_label: Label
var _progress_bar: ProgressBar
var _retry_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_connect_signals()
	GameManager.start_bootstrap()


func _exit_tree() -> void:
	if GameManager.boot_progress_changed.is_connected(_on_boot_progress_changed):
		GameManager.boot_progress_changed.disconnect(_on_boot_progress_changed)
	if GameManager.boot_failed.is_connected(_on_boot_failed):
		GameManager.boot_failed.disconnect(_on_boot_failed)
	if GameManager.boot_completed.is_connected(_on_boot_completed):
		GameManager.boot_completed.disconnect(_on_boot_completed)


func _build_interface() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.09, 0.07, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var vignette := ColorRect.new()
	vignette.name = "Overlay"
	vignette.color = Color(0.16, 0.10, 0.06, 0.35)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vignette)

	var safe_area := MarginContainer.new()
	safe_area.name = "SafeArea"
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 96)
	safe_area.add_theme_constant_override("margin_right", 96)
	safe_area.add_theme_constant_override("margin_top", 72)
	safe_area.add_theme_constant_override("margin_bottom", 72)
	add_child(safe_area)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	safe_area.add_child(layout)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "NIGHT SHIFT MARKET"
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82))
	layout.add_child(_title_label)

	var subtitle_label := Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.text = "Building the market for your next shift..."
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(0.93, 0.80, 0.67))
	layout.add_child(subtitle_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0.0, 30.0)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	layout.add_child(_progress_bar)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = "Starting bootstrap..."
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.73))
	layout.add_child(_status_label)

	_retry_button = Button.new()
	_retry_button.text = "Retry Startup"
	_retry_button.visible = false
	_retry_button.custom_minimum_size = Vector2(240.0, 52.0)
	_retry_button.pressed.connect(_on_retry_pressed)
	layout.add_child(_retry_button)


func _connect_signals() -> void:
	GameManager.boot_progress_changed.connect(_on_boot_progress_changed)
	GameManager.boot_failed.connect(_on_boot_failed)
	GameManager.boot_completed.connect(_on_boot_completed)


func _on_boot_progress_changed(progress: float, message: String) -> void:
	_progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0
	_status_label.text = message


func _on_boot_failed(message: String) -> void:
	_status_label.text = message
	_retry_button.visible = true


func _on_boot_completed() -> void:
	_status_label.text = "Launching main shell..."


func _on_retry_pressed() -> void:
	_retry_button.visible = false
	_progress_bar.value = 0.0
	_status_label.text = "Retrying startup..."
	GameManager.retry_bootstrap()
