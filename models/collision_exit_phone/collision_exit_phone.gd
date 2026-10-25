extends StaticBody3D

@export var interaction_prompt: String = "E — Make up an Excuse"

#Audiotream job
@export var exit_sound: AudioStream

@export_range(0.1, 5.0, 0.1) var fade_duration: float = 1.5

var is_exiting: bool = false


func get_interaction_prompt() -> String:
	return interaction_prompt


func interact() -> void:
	#check if interaction has occured before so that player cant spam it
	if is_exiting:
		return

	is_exiting = true

	await _play_exit_sound()
	await _fade_to_black()
	#wait for sound and fade to end before exit
	
	get_tree().quit()


func _play_exit_sound() -> void:
	#in case path files mess up
	if exit_sound == null:
		return

	var sound_player := AudioStreamPlayer3D.new()
	sound_player.stream = exit_sound
	sound_player.bus = "Master"

	#makes sound come from phone
	add_child(sound_player)
	sound_player.play()

	await sound_player.finished

	sound_player.queue_free()


func _fade_to_black() -> void:
	#Places layer infront of camera to make it easier
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "ExitFade"
	fade_layer.layer = 100
	get_tree().root.add_child(fade_layer)

	#Rectangle object creatiom
	var fade_rect := ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	fade_rect.modulate.a = 0.0
	fade_layer.add_child(fade_rect)

	#changes rectangle opacitiy
	var tween := get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(
		fade_rect,
		"modulate:a",
		1.0,
		fade_duration
	)

	await tween.finished
