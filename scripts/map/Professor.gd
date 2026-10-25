class_name Professor
extends Resource
 
@export var name := ""
@export var portrait: Texture2D
@export var voice_note: AudioStream
@export_range(0.0, 1.0) var chance_in_office := 0.5
