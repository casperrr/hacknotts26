extends CharacterBody3D
class_name Colin

@export_group("Look")
@export var mouse_sensitivity: float = 0.003
@export var fov := 80.0
@export var sprint_fov := 92.0

@export_group("Movement")
@export var walk_speed := 6.0
@export var sprint_speed := 9.5
@export var acceleration := 46.0
@export var friction := 35.0
@export var air_control := 12.0
@export var jump_velocity := 5.0
@export var gravity_scale := 2.0
@export var sprint_seconds := 4.0

@export_group("Cam")
@export var bob_height := 0.06
@export var bob_frequency := 2.2
@export var strafe_tilt := 2

@onready var player_head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var visual: Node3D = $Visual
@onready var message: Label = $HUD/Message
@onready var message_timer: Timer = $HUD/MessageTimer

var prompt_text := ""
var stamina := 0.0
var winded := false
var bob_distance := 0.0
var bob_amount := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visual.visible = false
	message_timer.timeout.connect(_on_message_timeout)
	camera.fov = fov
	stamina = sprint_seconds

func respawn(at: Vector3, yaw: float) -> void:
	global_position = at
	velocity = Vector3.ZERO
	rotation = Vector3(0.0, yaw, 0.0)
	($Head as Node3D).rotation.x = 0.0
	stamina = sprint_seconds
	winded = false

# On-screen text that clears itself after a few seconds
func show_message(text: String, seconds := 3.0) -> void:
	message.text = text
	message.show()
	message_timer.start(seconds)

func show_prompt(text: String) -> void:
	prompt_text = text
	if message_timer.is_stopped():
		message.text = text
		message.show()

func hide_prompt() -> void:
	prompt_text = ""
	if message_timer.is_stopped():
		message.hide()

func _on_message_timeout() -> void:
	message.text = prompt_text
	message.visible = prompt_text != ""

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-motion.screen_relative.x * mouse_sensitivity)
		player_head.rotate_x(-motion.screen_relative.y * mouse_sensitivity)
		player_head.rotation.x = clampf(player_head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if stamina <= 0.0:
		winded = true
	elif stamina >= sprint_seconds * 0.5:
		winded = false
	var sprinting := Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO and not winded
	if sprinting:
		stamina -= delta
	else:
		stamina += delta * 0.5
	stamina = clampf(stamina, 0.0, sprint_seconds)

	var target := wish * (sprint_speed if sprinting else walk_speed)
	var rate := air_control
	if is_on_floor():
		rate = acceleration if input_dir != Vector2.ZERO else friction
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()
	_update_camera(delta, input_dir, sprinting)

func _update_camera(delta: float, input_dir: Vector2, sprinting: bool) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and speed > 1.0
	bob_amount = move_toward(bob_amount, 1.0 if moving else 0.0, delta * 4.0)
	if moving:
		bob_distance += speed * delta
	var phase := bob_distance * bob_frequency
	camera.position = Vector3(cos(phase * 0.5) * bob_height * 0.5, sin(phase) * bob_height, 0.0) * bob_amount
	camera.rotation.z = lerpf(camera.rotation.z, -input_dir.x * deg_to_rad(strafe_tilt), minf(1.0, delta * 8.0))
	camera.fov = lerpf(camera.fov, sprint_fov if sprinting else fov, minf(1.0, delta * 6.0))
