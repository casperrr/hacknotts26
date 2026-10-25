extends Node

# Persistent game settings manager.

const CONFIG_PATH: String = "user://settings.cfg"

const DEFAULT_MASTER_VOLUME: float = 100.0
const DEFAULT_MOUSE_SENSITIVITY: float = 0.003
const DEFAULT_WINDOW_MODE: int = DisplayServer.WINDOW_MODE_WINDOWED
const DEFAULT_VSYNC_ENABLED: bool = true

const VALID_WINDOW_MODES: Array[int] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_MAXIMIZED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
]

var master_volume: float = DEFAULT_MASTER_VOLUME
var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var window_mode: int = DEFAULT_WINDOW_MODE
var vsync_enabled: bool = DEFAULT_VSYNC_ENABLED


func _ready() -> void:
	# Load saved preferences before applying them to the running game.
	var loaded_from_file: bool = _load_settings()
	_apply_all()

	if not loaded_from_file:
		save_settings()


func _load_settings() -> bool:
	var config := ConfigFile.new()
	var error: Error = config.load(CONFIG_PATH)

	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			push_warning(
                "Could not load settings from %s (error %s). Using defaults."
				% [CONFIG_PATH, error]
			)
		return false

	master_volume = clampf(
		float(config.get_value("Audio", "master_volume", DEFAULT_MASTER_VOLUME)),
		0.0,
		100.0
	)

	mouse_sensitivity = clampf(
		float(config.get_value("Controls", "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)),
		0.0005,
		0.01
	)

	window_mode = int(
		config.get_value("Display", "window_mode", DEFAULT_WINDOW_MODE)
	)
	if not VALID_WINDOW_MODES.has(window_mode):
		window_mode = DEFAULT_WINDOW_MODE

	vsync_enabled = bool(
		config.get_value("Display", "vsync_enabled", DEFAULT_VSYNC_ENABLED)
	)

	return true


func _apply_all() -> void:
	_apply_audio()
	_apply_display()
	apply_player_sensitivity()


func _apply_audio() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index < 0:
		push_warning("The audio bus named 'Master' was not found.")
		return

	AudioServer.set_bus_mute(bus_index, master_volume <= 0.0)
	if master_volume > 0.0:
		AudioServer.set_bus_volume_linear(bus_index, master_volume / 100.0)


func _apply_display() -> void:
	DisplayServer.window_set_mode(window_mode)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED
		if vsync_enabled
		else DisplayServer.VSYNC_DISABLED
	)

func apply_player_sensitivity(player: Node = null) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	player.set("mouse_sensitivity", mouse_sensitivity)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 100.0)
	_apply_audio()
	save_settings()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0005, 0.01)
	apply_player_sensitivity()
	save_settings()

func set_window_mode(value: int) -> void:
	if not VALID_WINDOW_MODES.has(value):
		push_warning("Invalid window mode supplied; using windowed mode.")
		value = DEFAULT_WINDOW_MODE

	window_mode = value
	DisplayServer.window_set_mode(window_mode)
	save_settings()


func set_vsync_enabled(value: bool) -> void:
	vsync_enabled = value
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED
		if vsync_enabled
		else DisplayServer.VSYNC_DISABLED
	)
	save_settings()



func reset_to_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY
	window_mode = DEFAULT_WINDOW_MODE
	vsync_enabled = DEFAULT_VSYNC_ENABLED

	_apply_all()
	save_settings()


func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("Audio", "master_volume", master_volume)
	config.set_value("Controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("Display", "window_mode", window_mode)
	config.set_value("Display", "vsync_enabled", vsync_enabled)

	var error: Error = config.save(CONFIG_PATH)
	if error != OK:
		push_error(
			"Could not save settings to %s (error %s)." % [CONFIG_PATH, error]
		)
