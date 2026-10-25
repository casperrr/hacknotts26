extends Timer

@export var time_remaning : float = 500

func _ready() -> void:
	start(time_remaning)

func _process(delta: float) -> void:
	pass
