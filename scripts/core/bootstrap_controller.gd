extends Control
class_name BootstrapController

var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _progress_bar: ProgressBar
var _retry_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_connect_signals()
	_apply_localized_text()
	GameManager.start_bootstrap()


func _exit_tree() -> void:
	if GameManager.boot_progress_changed.is_connected(_on_boot_progress_changed):
		GameManager.boot_progress_changed.disconnect(_on_boot_progress_changed)
	if GameManager.boot_failed.is_connected(_on_boot_failed):
		GameManager.boot_failed.disconnect(_on_boot_failed)
	if GameManager.boot_completed.is_connected(_on_boot_completed):
		GameManager.boot_completed.disconnect(_on_boot_completed)
	if LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.disconnect(_on_locale_changed)


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

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 20)
	_subtitle_label.add_theme_color_override("font_color", Color(0.93, 0.80, 0.67))
	layout.add_child(_subtitle_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0.0, 30.0)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	layout.add_child(_progress_bar)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.73))
	layout.add_child(_status_label)

	_retry_button = Button.new()
	_retry_button.text = "Retry Startup"
	_retry_button.visible = false
	_retry_button.custom_minimum_size = Vector2(240.0, 52.0)
	_retry_button.pressed.connect(_on_retry_pressed)
	_attach_button_feedback(_retry_button)
	layout.add_child(_retry_button)


func _connect_signals() -> void:
	GameManager.boot_progress_changed.connect(_on_boot_progress_changed)
	GameManager.boot_failed.connect(_on_boot_failed)
	GameManager.boot_completed.connect(_on_boot_completed)
	LocalizationManager.locale_changed.connect(_on_locale_changed)


func _on_boot_progress_changed(progress: float, message: String) -> void:
	_progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0
	_status_label.text = message


func _on_boot_failed(message: String) -> void:
	_status_label.text = message
	_retry_button.visible = true


func _on_boot_completed() -> void:
	_status_label.text = LocalizationManager.text(&"bootstrap.status.launching")


func _on_retry_pressed() -> void:
	_retry_button.visible = false
	_progress_bar.value = 0.0
	_status_label.text = LocalizationManager.text(&"bootstrap.status.retrying")
	GameManager.retry_bootstrap()


func _on_locale_changed(_locale_code: StringName, _is_rtl: bool) -> void:
	_apply_localized_text()


func _apply_localized_text() -> void:
	LocalizationManager.apply_control_locale(self)
	if _title_label != null:
		_title_label.text = LocalizationManager.text(&"app.title")
	if _subtitle_label != null:
		_subtitle_label.text = LocalizationManager.text(&"bootstrap.subtitle")
	if _retry_button != null:
		_retry_button.text = LocalizationManager.text(&"bootstrap.retry")
	if _status_label != null and _status_label.text.is_empty():
		_status_label.text = LocalizationManager.text(&"bootstrap.status.starting")


func _attach_button_feedback(button: BaseButton) -> void:
	button.pivot_offset = button.size * 0.5
	button.resized.connect(func() -> void:
		button.pivot_offset = button.size * 0.5
	)
	button.button_down.connect(func() -> void:
		_animate_button_state(button, true)
	)
	button.button_up.connect(func() -> void:
		_animate_button_state(button, false)
	)
	button.pressed.connect(func() -> void:
		_animate_button_state(button, false)
	)
	button.mouse_exited.connect(func() -> void:
		_animate_button_state(button, false)
	)


func _animate_button_state(button: Control, is_pressed: bool) -> void:
	if button == null:
		return
	if not button.has_meta("rest_position"):
		button.set_meta("rest_position", button.position)
	var target_scale := Vector2.ONE
	var target_position := button.get_meta("rest_position") as Vector2
	if is_pressed:
		target_scale = Vector2(0.975, 0.975)
		target_position = (button.get_meta("rest_position") as Vector2) + Vector2(0.0, 4.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.08)
	tween.parallel().tween_property(button, "position", target_position, 0.08)
