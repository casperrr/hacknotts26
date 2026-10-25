extends Node3D
class_name ProfessorDoor

var professor: Professor  # null = no office behind door
var locked := true

@onready var portrait: Sprite3D = $Portrait
@onready var nameplate: Label3D = $Nameplate

func setup(prof: Professor, is_locked: bool) -> void:
	professor = prof
	locked = is_locked
	portrait.visible = prof != null
	nameplate.visible = prof != null
	if prof:
		portrait.texture = prof.portrait
		nameplate.text = prof.name
