extends Sprite3D

# Maximum height of the sin wave
@export var AMPLITUDE : float = 0.05
# How many waves cycles per second
@export var FREQUENCY : float = 1.0
var time_passed : float = 0.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	time_passed += delta
	
	var height_offset : float = AMPLITUDE * sin(time_passed * FREQUENCY)
	self.position = Vector3(self.position.x, self.position.y + height_offset, self.position.z)
