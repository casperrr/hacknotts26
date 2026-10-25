extends Control

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$CenterContainer/Label.text = get_formatted_time($Timer.time_left)

func get_formatted_time(time: float) -> String:
	var minutes_left : int = time / 60
	var seconds_left : int = (round(int(time)) % 60)
	
	return "%s:%s" % [str(minutes_left), str(seconds_left)]
