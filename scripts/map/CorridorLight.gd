extends Node3D
class_name CorridorLight

var burst_left := 0.0
var wait_left := 0.0

@onready var spot: SpotLight3D = $Spot
@onready var glow: MeshInstance3D = $Glow
@onready var energy := spot.light_energy

func _ready() -> void:
	set_process(false)

func setup(dead: bool, flicker: bool) -> void:
	spot.visible = not dead
	glow.visible = not dead
	wait_left = randf_range(0.5, 6.0)
	set_process(flicker and not dead)

func _process(delta: float) -> void:
	if burst_left > 0.0:
		burst_left -= delta
		var on := burst_left <= 0.0 or randf() < 0.5
		spot.light_energy = energy if on else energy * 0.1
		glow.visible = on
		if burst_left <= 0.0:
			wait_left = randf_range(1.0, 6.0)
	else:
		wait_left -= delta
		if wait_left <= 0.0:
			burst_left = randf_range(0.1, 0.5)
