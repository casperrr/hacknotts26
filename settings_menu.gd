extends Control

var volume_slider: HSlider
var sensitivity_slider: HSlider
var render_scale_slider: HSlider

var window_mode_option: OptionButton
var vsync_check: CheckBox
var fps_option: OptionButton

var volume_value_label: Label
var sensitivity_value_label: Label
var render_scale_value_label: Label

var _closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_ui()
	_sync_ui_from_settings()
	_connect_ui()

	# Pause the game but leave the menu active.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_ui() -> void:
	# Darken the game in the background.
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.02, 0.03, 0.85)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	# Centre the settings panel.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Configure your experience"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	column.add_child(HSeparator.new())

	# AUDIO
	_add_heading(column, "AUDIO")

	volume_value_label = Label.new()
	column.add_child(volume_value_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(volume_slider)

	# CONTROLS
	_add_heading(column, "CONTROLS")

	sensitivity_value_label = Label.new()
	column.add_child(sensitivity_value_label)

	sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 0.0005
	sensitivity_slider.max_value = 0.01
	sensitivity_slider.step = 0.0001
	sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(sensitivity_slider)

	# GRAPHICS
	_add_heading(column, "GRAPHICS")

	render_scale_value_label = Label.new()
	column.add_child(render_scale_value_label)

	render_scale_slider = HSlider.new()
	render_scale_slider.min_value = 0.5
	render_scale_slider.max_value = 1.0
	render_scale_slider.step = 0.05
	render_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(render_scale_slider)

	window_mode_option = OptionButton.new()
	window_mode_option.add_item(
		"Windowed",
		DisplayServer.WINDOW_MODE_WINDOWED
	)
	window_mode_option.add_item(
		"Maximised",
		DisplayServer.WINDOW_MODE_MAXIMIZED
	)
	window_mode_option.add_item(
		"Fullscreen",
		DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	_add_option_row(column, "Window mode", window_mode_option)

	vsync_check = CheckBox.new()
	vsync_check.text = "Enable V-Sync"
	column.add_child(vsync_check)

	# PERFORMANCE
	_add_heading(column, "PERFORMANCE")

	fps_option = OptionButton.new()
	fps_option.add_item("30 FPS", 30)
	fps_option.add_item("60 FPS", 60)
	fps_option.add_item("120 FPS", 120)
	fps_option.add_item("144 FPS", 144)
	fps_option.add_item("Unlimited", 0)
	_add_option_row(column, "Frame-rate limit", fps_option)

	column.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)

	var reset_button := Button.new()
	reset_button.text = "Reset defaults"
	buttons.add_child(reset_button)
	reset_button.pressed.connect(_on_reset_pressed)

	var close_button := Button.new()
	close_button.text = "Resume game"
	buttons.add_child(close_button)
	close_button.pressed.connect(_close_menu)


func _add_heading(parent: VBoxContainer, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 17)
	parent.add_child(heading)


func _add_option_row(
	parent: VBoxContainer,
	label_text: String,
	option: OptionButton
) -> void:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(155, 0)
	row.add_child(label)

	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)

	parent.add_child(row)


func _sync_ui_from_settings() -> void:
	# Prevent UI refreshes from triggering setting changes.
	volume_slider.set_block_signals(true)
	sensitivity_slider.set_block_signals(true)
	render_scale_slider.set_block_signals(true)
	window_mode_option.set_block_signals(true)
	vsync_check.set_block_signals(true)
	fps_option.set_block_signals(true)

	volume_slider.value = GameSettings.master_volume
	sensitivity_slider.value = GameSettings.mouse_sensitivity
	render_scale_slider.value = GameSettings.render_scale

	window_mode_option.select(
		_find_option_index(window_mode_option, GameSettings.window_mode)
	)

	vsync_check.button_pressed = GameSettings.vsync_enabled

	fps_option.select(
		_find_option_index(fps_option, GameSettings.max_fps)
	)

	volume_slider.set_block_signals(false)
	sensitivity_slider.set_block_signals(false)
	render_scale_slider.set_block_signals(false)
	window_mode_option.set_block_signals(false)
	vsync_check.set_block_signals(false)
	fps_option.set_block_signals(false)

	_update_value_labels()


func _find_option_index(option: OptionButton, id: int) -> int:
	for index in range(option.item_count):
		if option.get_item_id(index) == id:
			return index

	return 0


func _update_value_labels() -> void:
	volume_value_label.text = (
		"Master volume: %d%%" % int(volume_slider.value)
	)

	sensitivity_value_label.text = (
		"Mouse sensitivity: %.4f" % sensitivity_slider.value
	)

	render_scale_value_label.text = (
        "3D render scale: %d%%"
		% int(round(render_scale_slider.value * 100.0))
	)


func _connect_ui() -> void:
	volume_slider.value_changed.connect(_on_volume_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	render_scale_slider.value_changed.connect(_on_render_scale_changed)

	window_mode_option.item_selected.connect(_on_window_mode_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	fps_option.item_selected.connect(_on_fps_selected)


func _on_volume_changed(value: float) -> void:
	volume_value_label.text = "Master volume: %d%%" % int(value)
	GameSettings.set_master_volume(value)


func _on_sensitivity_changed(value: float) -> void:
	sensitivity_value_label.text = "Mouse sensitivity: %.4f" % value
	GameSettings.set_mouse_sensitivity(value)


func _on_render_scale_changed(value: float) -> void:
	render_scale_value_label.text = (
		"3D render scale: %d%%" % int(round(value * 100.0))
	)
	GameSettings.set_render_scale(value)


func _on_window_mode_selected(index: int) -> void:
	GameSettings.set_window_mode(
		window_mode_option.get_item_id(index)
	)


func _on_vsync_toggled(enabled: bool) -> void:
	GameSettings.set_vsync_enabled(enabled)


func _on_fps_selected(index: int) -> void:
	GameSettings.set_max_fps(fps_option.get_item_id(index))


func _on_reset_pressed() -> void:
	GameSettings.reset_to_defaults()
	_sync_ui_from_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()


func _close_menu() -> void:
	if _closing:
		return

	_closing = true

	GameSettings.save_settings()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	queue_free()
