extends Timer

@export var duration : float = 500

func _ready() -> void:
	start(duration)

func add_time(extra_time: float) -> void:
	var saved_time_left : float = self.time_left
	stop()
	start(saved_time_left + extra_time)

# USE THE TIMER TIMEOUT SIGNAL TO SIGNFY TO THE GAME THAT THE TIMER FINISHED
