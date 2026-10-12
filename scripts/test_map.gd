extends Node3D
## Procedural greybox arena: sprint lanes, stairs, platforms and ramps.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

func _ready() -> void:
	_build_environment()
	_build_arena()
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.15, 8)
	add_child(player)
	_build_hud()

func _material(color: Color, roughness := 0.82, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material, rotation := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	body.rotation = rotation
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = mat
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.19, 0.29)
	sky_mat.sky_horizon_color = Color(0.55, 0.59, 0.62)
	sky_mat.ground_bottom_color = Color(0.07, 0.075, 0.08)
	sky_mat.ground_horizon_color = Color(0.38, 0.39, 0.4)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _build_arena() -> void:
	var concrete := _material(Color(0.31, 0.33, 0.34))
	var dark := _material(Color(0.12, 0.15, 0.17), 0.68, 0.12)
	var paint := _material(Color(0.78, 0.39, 0.12), 0.62)
	var floor_mat := _material(Color(0.22, 0.24, 0.25), 0.95)
	_box(self, "ArenaFloor", Vector3(0, -0.25, 0), Vector3(44, 0.5, 60), floor_mat)
	_box(self, "BackWall", Vector3(0, 2.5, -30), Vector3(44, 5, 0.7), concrete)
	_box(self, "LeftWall", Vector3(-22, 2.5, 0), Vector3(0.7, 5, 60), concrete)
	_box(self, "RightWall", Vector3(22, 2.5, 0), Vector3(0.7, 5, 60), concrete)
	_box(self, "FrontWallLeft", Vector3(-17, 2.5, 30), Vector3(10, 5, 0.7), concrete)
	_box(self, "FrontWallRight", Vector3(17, 2.5, 30), Vector3(10, 5, 0.7), concrete)
	# Sprint and strafe lanes.
	for x in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		_box(self, "LaneStripe", Vector3(x, 0.012, 0), Vector3(0.055, 0.02, 52), paint)
	# Jump platforms and cover blocks.
	_box(self, "LowPlatform", Vector3(-8, 0.65, -8), Vector3(3.0, 1.3, 3.0), dark)
	_box(self, "HighPlatform", Vector3(-8, 1.5, -15), Vector3(3.0, 3.0, 3.0), concrete)
	_box(self, "CoverA", Vector3(5, 0.7, -7), Vector3(3.5, 1.4, 1.0), dark)
	_box(self, "CoverB", Vector3(10, 0.7, -12), Vector3(1.0, 1.4, 4.0), dark)
	# Staircase, each tread is independently collidable.
	for i in range(7):
		var h := 0.22 * float(i + 1)
		_box(self, "Stair_%02d" % i, Vector3(5, h * 0.5, 7.0 - i * 1.0), Vector3(3.5, h, 1.05), concrete)
	# Ramp blocks with matching rotated collision boxes.
	_box(self, "RampLeft", Vector3(-14, 0.9, -3), Vector3(5, 0.35, 12), concrete, Vector3(deg_to_rad(-9), 0, 0))
	_box(self, "RampRight", Vector3(14, 0.9, -3), Vector3(5, 0.35, 12), concrete, Vector3(deg_to_rad(-9), 0, 0))
	# Industrial columns and warm practical lights.
	for x in [-18.0, -9.0, 9.0, 18.0]:
		for z in [-24.0, -18.0, 18.0, 24.0]:
			_box(self, "Pillar", Vector3(x, 2.5, z), Vector3(0.65, 5, 0.65), dark)
	for x in [-12.0, 0.0, 12.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 4.2, -2)
		lamp.light_color = Color(1.0, 0.78, 0.58)
		lamp.light_energy = 1.3
		lamp.omni_range = 10
		add_child(lamp)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "FLATGROUND  //  MOVEMENT TEST\nWASD Move   SHIFT Sprint   CTRL Crouch/Slide   SPACE Hold: Auto-Bhop   ESC Mouse"
	label.position = Vector2(24, 22)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.95))
	layer.add_child(label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-5, -12)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	layer.add_child(crosshair)
