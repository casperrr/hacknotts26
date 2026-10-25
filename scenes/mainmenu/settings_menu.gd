extends CanvasLayer

@onready var volume_slider: HSlider = %AudioSlider
@onready var volume_value: Label = %VolumeValue

@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value: Label = %SensitivityValue

@onready var fullscreen_check: CheckBox = %FullscreenCheckBox
@onready var vsync_check: CheckBox = %VSyncCheckBox

@onready var reset_button: Button = %ResetButton
@onready var resume_button: Button = %ResumeButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	_configure_sliders()
	_sync_ui_from_settings()
	_connect_signals()
	
	
func _configure_sliders() -> void:
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	
	sensitivity_slider.min_value = 0.0005
	sensitivity_slider.max_value = 0.01
	sensitivity_slider.step = 0.0001

func _connect_signals() -> void:
	volume_slider.value_changed.connect(_on_volume_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)

	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)

	reset_button.pressed.connect(_on_reset_pressed)
	resume_button.pressed.connect(close_menu)


func _sync_ui_from_settings() -> void:
	# Prevent ui updates from playing triggering function calls
	_set_controls_blocked(true)

	volume_slider.value = clampf(
		GameSettings.master_volume,
		volume_slider.min_value,
		volume_slider.max_value
	)
	sensitivity_slider.value = clampf(
		GameSettings.mouse_sensitivity,
		sensitivity_slider.min_value,
		sensitivity_slider.max_value
	)

	fullscreen_check.button_pressed = (
		GameSettings.window_mode
		== DisplayServer.WINDOW_MODE_FULLSCREEN
	)

	vsync_check.button_pressed = GameSettings.vsync_enabled

	_set_controls_blocked(false)
	_update_value_labels()


func _set_controls_blocked(blocked: bool) -> void:
	volume_slider.set_block_signals(blocked)
	sensitivity_slider.set_block_signals(blocked)
	fullscreen_check.set_block_signals(blocked)
	vsync_check.set_block_signals(blocked)

func _update_value_labels() -> void:
	volume_value.text = "%d%%" % int(round(volume_slider.value))
	sensitivity_value.text = "%.4f" % sensitivity_slider.value


func _on_volume_changed(value: float) -> void:
	volume_value.text = "%d%%" % int(round(value))
	GameSettings.set_master_volume(value)

func _on_sensitivity_changed(value: float) -> void:
	sensitivity_value.text = "%.4f" % value
	GameSettings.set_mouse_sensitivity(value)
#random slop from documentation and tutorials rofl

func _on_fullscreen_toggled(enabled: bool) -> void:
	var new_mode: int

	if enabled:
		new_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	else:
		new_mode = DisplayServer.WINDOW_MODE_WINDOWED

	GameSettings.set_window_mode(new_mode)


func _on_vsync_toggled(enabled: bool) -> void:
	GameSettings.set_vsync_enabled(enabled)

func _on_reset_pressed() -> void:
	GameSettings.reset_to_defaults()
	_sync_ui_from_settings()


func open_menu() -> void:
	if visible:
		return

	_sync_ui_from_settings()

	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	if not visible:
		return

	GameSettings.save_settings()

	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
