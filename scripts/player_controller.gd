extends CharacterBody3D
## Responsive FPS movement with momentum, slide, hold-to-bhop and restrained camera effects.

@export_group("Movement")
@export var walk_speed := 6.0
@export var sprint_speed := 9.2
@export var crouch_speed := 3.4
@export var ground_acceleration := 22.0
@export var air_acceleration := 5.0
@export var ground_friction := 12.0
@export var air_control := 0.35
@export var jump_velocity := 6.8
@export var gravity := 20.0
@export var slide_friction := 2.2
@export var slide_boost := 1.12
@export_group("Camera")
@export var mouse_sensitivity := 0.0018
@export var base_fov := 90.0
@export var sprint_fov := 98.0
@export var camera_smoothing := 12.0
@export var headbob_amount := 0.035
@export var landing_kick := 0.16
@export var landing_recovery := 10.0
@export var look_smoothing := 24.0
@export var strafe_roll_degrees := 2.0
@export var sprint_sway_amount := 0.012
@export var idle_breath_amount := 0.004
@export var speed_fov_amount := 1.2
@export var camera_effects_enabled := true

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var capsule: CollisionShape3D = $CollisionShape3D
var standing_height := 1.8
var crouching_height := 1.15
var camera_stand_y := 1.62
var camera_crouch_y := 1.02
var pitch := 0.0
var target_pitch := 0.0
var bob_time := 0.0
var landing_offset := 0.0
var landing_velocity := 0.0
var camera_clock := 0.0
var was_on_floor := false
var slide_active := false
var slide_speed := 0.0

func _ready() -> void:
	_add_action("move_forward", [KEY_W, KEY_UP])
	_add_action("move_back", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("crouch", [KEY_CTRL])
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = base_fov
	was_on_floor = is_on_floor()

func _add_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		target_pitch = clampf(target_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-89), deg_to_rad(89))
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var crouching := Input.is_action_pressed("crouch")
	var sprinting := Input.is_action_pressed("sprint") and not crouching
	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (global_transform.basis * Vector3(input_2d.x, 0, input_2d.y)).normalized()
	var horizontal := Vector3(velocity.x, 0, velocity.z)

	if grounded:
		if not was_on_floor and velocity.y < -2.0:
			var impact := clampf(absf(velocity.y) / jump_velocity, 0.35, 2.2)
			landing_offset = landing_kick * impact
			landing_velocity = landing_recovery * impact * 0.08
		if crouching and horizontal.length() > walk_speed * 0.7:
			if not slide_active:
				slide_active = true
				slide_speed = horizontal.length() * slide_boost
			slide_speed = maxf(0.0, slide_speed - slide_friction * delta)
			velocity.x = horizontal.normalized().x * slide_speed
			velocity.z = horizontal.normalized().z * slide_speed
			if wish_dir.length() > 0.01:
				var steered := Vector3(velocity.x, 0, velocity.z).lerp(wish_dir * slide_speed, delta * 1.4)
				velocity.x = steered.x
				velocity.z = steered.z
		else:
			slide_active = false
			var target_speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)
			var target := wish_dir * target_speed
			if wish_dir.length() > 0.01:
				horizontal = horizontal.move_toward(target, ground_acceleration * delta)
			else:
				horizontal = horizontal.move_toward(Vector3.ZERO, ground_friction * delta)
			velocity.x = horizontal.x
			velocity.z = horizontal.z
		# Hold Space to jump immediately on every grounded frame (auto-bhop).
		if Input.is_action_pressed("jump"):
			velocity.y = jump_velocity
			slide_active = false
	else:
		slide_active = false
		velocity.y -= gravity * delta
		if wish_dir.length() > 0.01:
			var air_target := wish_dir * sprint_speed
			horizontal = horizontal.move_toward(air_target, air_acceleration * air_control * delta)
			velocity.x = horizontal.x
			velocity.z = horizontal.z

	move_and_slide()
	_update_camera(delta, crouching, sprinting)
	was_on_floor = grounded

func _update_camera(delta: float, crouching: bool, sprinting: bool) -> void:
	camera_clock += delta
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var grounded := is_on_floor()
	# Smooth pitch independently from yaw for a controlled, immersive view.
	pitch = lerpf(pitch, target_pitch, 1.0 - exp(-look_smoothing * delta))
	head.rotation.x = pitch

	var moving := grounded and horizontal_speed > 0.5
	var bob := Vector3.ZERO
	if moving:
		var gait_rate := 8.5 if sprinting else 6.5
		bob_time += delta * gait_rate * clampf(horizontal_speed / walk_speed, 0.65, 1.65)
		if camera_effects_enabled:
			var intensity := headbob_amount * (1.25 if sprinting else 1.0)
			bob = Vector3(cos(bob_time * 0.5) * intensity, absf(sin(bob_time)) * intensity, 0.0)
	elif camera_effects_enabled:
		# Subtle idle breathing avoids a completely mechanical viewpoint.
		bob.y = sin(camera_clock * 1.15) * idle_breath_amount

	# A short dip on landing, followed by a smooth recovery.
	landing_velocity = move_toward(landing_velocity, 0.0, landing_recovery * delta)
	landing_offset = move_toward(landing_offset, 0.0, landing_recovery * 0.65 * delta)
	var target_y := camera_crouch_y if crouching else camera_stand_y
	head.position.y = lerpf(head.position.y, target_y, 1.0 - exp(-camera_smoothing * delta))

	var target_fov := base_fov
	if sprinting:
		target_fov = sprint_fov
	elif horizontal_speed > walk_speed:
		target_fov += minf(speed_fov_amount * (horizontal_speed - walk_speed), 3.0)
	if slide_active:
		target_fov += 2.5
	if camera_effects_enabled:
		target_fov += minf(horizontal_speed * 0.12, 1.5)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-4.5 * delta))

	var strafe := Input.get_axis("move_left", "move_right")
	var roll_target := 0.0
	if camera_effects_enabled:
		roll_target = deg_to_rad(-strafe_roll_degrees) * strafe
		if slide_active:
			roll_target += deg_to_rad(-1.0) * strafe
	head.rotation.z = lerpf(head.rotation.z, roll_target, 1.0 - exp(-camera_smoothing * delta))

	var sprint_sway := Vector3.ZERO
	if camera_effects_enabled and sprinting and moving:
		sprint_sway.x = sin(bob_time * 0.5) * sprint_sway_amount
		sprint_sway.y = cos(bob_time) * sprint_sway_amount * 0.6
	var target_camera_position := bob + sprint_sway + Vector3(0.0, -landing_offset, 0.0)
	camera.position = camera.position.lerp(target_camera_position, 1.0 - exp(-camera_smoothing * delta))
	_update_capsule(crouching, delta)

func _update_capsule(crouching: bool, delta: float) -> void:
	var shape := capsule.shape as CapsuleShape3D
	var desired := crouching_height if crouching else standing_height
	shape.height = lerpf(shape.height, desired, 1.0 - exp(-14.0 * delta))
	capsule.position.y = shape.height * 0.5
