extends Node3D
class_name ProfessorDoor

const NAME_WIDTH := 0.34
const NAME_HEIGHT := 0.05
const PORTRAIT_SIZE := Vector2(0.3, 0.38)

var professor: Professor  # null = no office behind door
var locked := true
var absent := false
var opened := false
var been_inside := false
var colin_near: Colin

@onready var portrait: Sprite3D = %Portrait
@onready var plate: MeshInstance3D = %Plate
@onready var nameplate: Label3D = %Nameplate
@onready var animation: AnimationPlayer = $Model/AnimationPlayer
@onready var pass_by: Area3D = $PassBy
@onready var reach: Area3D = $Reach
@onready var inside: Area3D = $Inside
@onready var voice_note: AudioStreamPlayer3D = $VoiceNote

func _ready() -> void:
	pass_by.body_entered.connect(_on_pass_by)
	reach.body_entered.connect(_on_reach_entered)
	reach.body_exited.connect(_on_reach_exited)
	inside.body_entered.connect(_on_inside_entered)

func setup(prof: Professor, is_locked: bool, title := "") -> void:
	professor = prof
	locked = is_locked
	absent = prof != null and is_locked
	var plate_text := prof.name if prof else title
	plate.visible = plate_text != ""
	portrait.visible = prof != null and prof.portrait != null
	if plate_text != "":
		nameplate.text = plate_text
		_fit_name()
	if prof:
		if prof.portrait:
			portrait.texture = prof.portrait
			portrait.pixel_size = minf(PORTRAIT_SIZE.x / prof.portrait.get_width(), PORTRAIT_SIZE.y / prof.portrait.get_height())
		if prof.voice_note:
			voice_note.stream = prof.voice_note

func _fit_name() -> void:
	var font := nameplate.font if nameplate.font else ThemeDB.fallback_font
	var width := font.get_string_size(nameplate.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nameplate.font_size).x
	nameplate.pixel_size = minf(NAME_HEIGHT / nameplate.font_size, NAME_WIDTH / width)

func _on_pass_by(body: Node3D) -> void:
	var colin := body as Colin
	if colin == null or not absent:
		return
	if voice_note.stream and not voice_note.playing:
		voice_note.play()
	colin.show_message("The door is locked.")

func _on_reach_entered(body: Node3D) -> void:
	var colin := body as Colin
	if colin == null:
		return
	colin_near = colin
	if not opened:
		colin.show_prompt("The door is locked." if absent else "Press E to open")

func _on_reach_exited(body: Node3D) -> void:
	if body != colin_near:
		return
	colin_near.hide_prompt()
	colin_near = null
	if opened and been_inside and to_local(body.global_position).z > 0.0:
		_shut()

func _on_inside_entered(body: Node3D) -> void:
	if body is Colin:
		been_inside = true
		if opened:
			_shut()

func _unhandled_input(event: InputEvent) -> void:
	if colin_near == null or opened or not event.is_action_pressed("interact"):
		return
	var from_inside := to_local(colin_near.global_position).z < 0.0
	if locked and not from_inside:
		colin_near.show_prompt("The door is locked.")
		return
	opened = true
	animation.play_section("open", 0.0, 1.2)
	colin_near.hide_prompt()

func _shut() -> void:
	opened = false
	locked = true
	animation.play_section("open", 1.2, 2.4)
