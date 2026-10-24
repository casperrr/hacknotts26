extends Node3D

var intersected_player : bool = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Lazy
	if body.name == "Player":
		intersected_player = true

func _process(delta: float) -> void:
	if($Sprite3D.modulate.a < 0.001):
		# Persistent storage will be done here
		
		queue_free()
	
	if(intersected_player):
		var tween : Tween = create_tween()
		tween.tween_property($Sprite3D, "modulate:a", 0.0, 0.3)
