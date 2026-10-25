extends StaticBody3D

@export var interaction_prompt: String = "E - Start Experience"

func get_interaction_prompt() -> String:
	return interaction_prompt

func interact() -> void:
	print("Interacted with: ", name)

#Start the game
