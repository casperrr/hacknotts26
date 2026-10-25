extends StaticBody3D

@export var interaction_prompt: String = "E - Setting configuration"


func get_interaction_prompt() -> String:
	return interaction_prompt


func interact() -> void:
	# Find the SettingsMenu in the main lobby scene.
	var settings_menu := get_tree().current_scene.get_node_or_null(
        "SettingsMenu"
	) as CanvasLayer

	if settings_menu == null:
		push_error(
            "SettingsMenu was not found under the main scene root."
		)
		return

	# Show the menu.
	settings_menu.show()
	
	
	# Pause gameplay and release the mouse.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
