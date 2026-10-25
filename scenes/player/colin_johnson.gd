extends CharacterBody3D

@export var mouse_sensitivity: float = 0.003

@export var speed : float = 3.0
@export var jump_mult : float = 2.5

@onready var player_head: Node3D = $Head
@onready var visual: Node3D = $Visual

@onready var interaction_ray: RayCast3D = $Head/RayCast3D


@export_node_path("Label") var interact_text_path: NodePath
@onready var interact_text: Label = get_node_or_null("CanvasLayer/BoxContainer/InteractText") as Label


func _ready() -> void:
	
	add_to_group("player")
	GameSettings.apply_player_sensitivity(self)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visual.visible = false
	
	if interact_text == null:
		push_error("Interact text not found")
	else:
		interact_text.hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		player_head.rotate_x(-event.relative.y * mouse_sensitivity)
		player_head.rotation.x = clampf(player_head.rotation.x, -deg_to_rad(90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	# Handle interaction prompts and input.
	_handle_interaction()

	# Add gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_mult

	# Get movement direction.
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_backward"
	)

	var direction := (
		transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()


func _handle_interaction() -> void:
	# Hide the prompt by default.
	interact_text.hide()

	if not interaction_ray.is_colliding():
		return

	var target: Object = interaction_ray.get_collider()

	if target == null or not target.has_method("interact"):
		return

	# Get the object's individual interaction prompt.
	if target.has_method("get_interaction_prompt"):
		interact_text.text = str(
			target.call("get_interaction_prompt")
		)
	else:
		interact_text.text = "E — Interact"

	interact_text.show()

	if Input.is_action_just_pressed("interact"):
		target.call("interact")
		interact_text.hide()
		
