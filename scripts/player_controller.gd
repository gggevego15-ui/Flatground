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
@export var air_wishspeed_cap := 8.0
@export var air_acceleration_gain := 18.0
@export var bunnyhop_speed_retention := 0.98
@export var ground_jump_friction_scale := 0.08
@export var crouch_transition_speed := 14.0
@export var slide_min_speed := 4.2
@export var slide_steering := 1.4
@export var slide_exit_speed := 2.0
@export var collision_margin := 0.04
@export var ladder_climb_speed := 3.0
@export var step_snap_length := 0.38
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
var crouch_blocked := false

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
	floor_snap_length = step_snap_length
	_build_character_model()

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
	var jump_held := Input.is_action_pressed("jump")
	var crouch_requested := Input.is_action_pressed("crouch")
	var crouching := crouch_requested or not _can_stand_up()
	crouch_blocked = not crouch_requested and not _can_stand_up()
	var sprinting := Input.is_action_pressed("sprint") and not crouching
	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (global_transform.basis * Vector3(input_2d.x, 0.0, input_2d.y)).normalized()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := horizontal.length()
	var on_ladder := _near_ladder()
	var ladder_axis := -input_2d.y
	if on_ladder and absf(ladder_axis) > 0.1:
		velocity.y = ladder_axis * ladder_climb_speed
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)
		move_and_slide()
		_update_camera(delta, true, false)
		was_on_floor = is_on_floor()
		return

	if grounded:
		if not was_on_floor and velocity.y < -2.0:
			var impact := clampf(absf(velocity.y) / jump_velocity, 0.35, 2.2)
			landing_offset = landing_kick * impact
			landing_velocity = landing_recovery * impact * 0.08

		if crouching and horizontal_speed > slide_min_speed and not jump_held:
			if not slide_active:
				slide_active = true
				slide_speed = horizontal_speed * slide_boost
			slide_speed = maxf(0.0, slide_speed - slide_friction * delta)
			horizontal = horizontal.normalized() * slide_speed
			if wish_dir.length_squared() > 0.001:
				horizontal = horizontal.lerp(wish_dir * slide_speed, minf(delta * slide_steering, 1.0))
			if slide_speed < slide_exit_speed and not crouch_requested:
				slide_active = false
		else:
			slide_active = false
			var target_speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)
			if jump_held:
				# Preserve most horizontal momentum on a perfectly timed hop.
				horizontal = horizontal.move_toward(Vector3.ZERO, ground_friction * ground_jump_friction_scale * delta)
			elif wish_dir.length_squared() > 0.001:
				horizontal = _ground_accelerate(horizontal, wish_dir, target_speed, ground_acceleration, delta)
			else:
				horizontal = horizontal.move_toward(Vector3.ZERO, ground_friction * delta)

		velocity.x = horizontal.x
		velocity.z = horizontal.z
		if jump_held:
			velocity.y = jump_velocity
			slide_active = false
			# Avoid a sudden speed drop at take-off while keeping tiny losses stable.
			if horizontal.length() > sprint_speed:
				horizontal *= bunnyhop_speed_retention
				velocity.x = horizontal.x
				velocity.z = horizontal.z
	else:
		slide_active = false
		velocity.y -= gravity * delta
		if wish_dir.length_squared() > 0.001:
			# Quake-style air acceleration: accelerate along the desired direction,
			# rather than pulling the whole velocity vector toward a fixed target.
			horizontal = _air_accelerate(horizontal, wish_dir, air_wishspeed_cap, air_acceleration_gain, delta)
			velocity.x = horizontal.x
			velocity.z = horizontal.z

	move_and_slide()
	_update_camera(delta, crouching, sprinting)
	was_on_floor = grounded


func _ground_accelerate(current: Vector3, wish_dir: Vector3, wish_speed: float, acceleration: float, delta: float) -> Vector3:
	var add_speed := wish_speed - current.dot(wish_dir)
	if add_speed <= 0.0:
		return current
	var accel_speed := minf(acceleration * wish_speed * delta, add_speed)
	return current + wish_dir * accel_speed


func _air_accelerate(current: Vector3, wish_dir: Vector3, wish_speed: float, acceleration: float, delta: float) -> Vector3:
	var add_speed := wish_speed - current.dot(wish_dir)
	if add_speed <= 0.0:
		return current
	var accel_speed := minf(acceleration * wish_speed * delta, add_speed)
	return current + wish_dir * accel_speed


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


func _can_stand_up() -> bool:
	var shape := capsule.shape as CapsuleShape3D
	if shape == null or shape.height >= standing_height - 0.01:
		return true
	var probe := CapsuleShape3D.new()
	probe.radius = shape.radius
	probe.height = standing_height
	probe.margin = collision_margin
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = global_transform * Transform3D(Basis(), Vector3(0.0, standing_height * 0.5 + collision_margin * 2.0, 0.0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = collision_margin
	var space := get_world_3d().direct_space_state
	var hits := space.intersect_shape(query, 8)
	probe.free()
	return hits.is_empty()


func _update_capsule(crouching: bool, delta: float) -> void:
	var shape := capsule.shape as CapsuleShape3D
	if shape == null:
		return
	# Keep the capsule bottom near the player's feet as its height changes.
	var desired := crouching_height if crouching else standing_height
	shape.height = lerpf(shape.height, desired, 1.0 - exp(-crouch_transition_speed * delta))
	capsule.position.y = shape.height * 0.5


func _near_ladder() -> bool:
	var probe := SphereShape3D.new()
	probe.radius = 0.85
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * 1.0)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 8)
	probe.free()
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider is Node and collider.is_in_group("climbable_ladder"):
			return true
	return false


func _build_character_model() -> void:
	# Head is omitted so the first-person camera never clips inside the face.
	var uniform := StandardMaterial3D.new()
	uniform.albedo_color = Color(0.19, 0.22, 0.23)
	uniform.roughness = 0.94
	var trousers := StandardMaterial3D.new()
	trousers.albedo_color = Color(0.12, 0.14, 0.15)
	trousers.roughness = 0.98
	var boots := StandardMaterial3D.new()
	boots.albedo_color = Color(0.07, 0.075, 0.075)
	boots.roughness = 0.92
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.62, 0.43, 0.31)
	skin.roughness = 0.88
	_add_body_box("Torso", Vector3(0, 1.12, 0.04), Vector3(0.48, 0.58, 0.27), uniform)
	_add_body_box("Pelvis", Vector3(0, 0.78, 0.04), Vector3(0.38, 0.2, 0.25), trousers)
	for side in [-1.0, 1.0]:
		_add_body_box("UpperLeg", Vector3(side * 0.115, 0.48, 0.04), Vector3(0.17, 0.48, 0.2), trousers)
		_add_body_box("Boot", Vector3(side * 0.115, 0.12, -0.025), Vector3(0.18, 0.2, 0.29), boots)
		_add_body_box("Sleeve", Vector3(side * 0.31, 1.12, 0.04), Vector3(0.16, 0.48, 0.19), uniform)
		_add_body_box("Hand", Vector3(side * 0.32, 0.86, -0.005), Vector3(0.12, 0.14, 0.13), skin)


func _add_body_box(label: String, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
