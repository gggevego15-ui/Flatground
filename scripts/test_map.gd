extends Node3D
## Walkable, non-neon urban block built from simple PBR-style materials and collidable geometry.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

func _ready() -> void:
	_build_environment()
	_build_city()
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.08, 13)
	add_child(player)
	_build_hud()


var _detail_texture: NoiseTexture2D


func _material(color: Color, roughness := 0.88, metallic := 0.0, texture_scale := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.uv1_scale = Vector3(texture_scale, texture_scale, texture_scale)
	# One shared 4K seamless detail map keeps memory use bounded across the whole city.
	if _detail_texture == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		noise.fractal_octaves = 4
		noise.fractal_gain = 0.48
		_detail_texture = NoiseTexture2D.new()
		_detail_texture.width = 4096
		_detail_texture.height = 4096
		_detail_texture.seamless = true
		_detail_texture.generate_mipmaps = true
		_detail_texture.normalize = true
		_detail_texture.noise = noise
	mat.albedo_texture = _detail_texture
	return mat


func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material, rotation := Vector3.ZERO, collidable := true) -> Node3D:
	var node: Node3D
	if collidable:
		node = StaticBody3D.new()
	else:
		node = Node3D.new()
	node.name = label
	node.position = pos
	node.rotation = rotation
	parent.add_child(node)
	var mesh := MeshInstance3D.new()
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = mat
	node.add_child(mesh)
	if collidable:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	return node


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.19, 0.29, 0.42)
	sky_mat.sky_horizon_color = Color(0.68, 0.70, 0.68)
	sky_mat.ground_bottom_color = Color(0.16, 0.17, 0.17)
	sky_mat.ground_horizon_color = Color(0.48, 0.49, 0.47)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssr_enabled = true
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_city() -> void:
	var asphalt := _material(Color(0.32, 0.33, 0.32), 0.98, 0.0, 5.0)
	var concrete := _material(Color(0.72, 0.70, 0.64), 0.94, 0.0, 2.4)
	var curb := _material(Color(0.82, 0.80, 0.72), 0.92, 0.0, 1.8)
	var white := _material(Color(0.82, 0.81, 0.75), 0.78)
	var yellow := _material(Color(0.72, 0.56, 0.25), 0.75)
	var brick_a := _material(Color(0.68, 0.46, 0.36), 0.95, 0.0, 2.8)
	var brick_b := _material(Color(0.76, 0.71, 0.61), 0.94, 0.0, 2.2)
	var plaster := _material(Color(0.84, 0.79, 0.67), 0.97, 0.0, 2.5)
	var glass := _material(Color(0.18, 0.27, 0.31), 0.24, 0.18)
	var dark_metal := _material(Color(0.105, 0.12, 0.12), 0.42, 0.45)
	var wood := _material(Color(0.29, 0.22, 0.15))
	var foliage := _material(Color(0.43, 0.52, 0.35), 0.96, 0.0, 1.2)

	# Broad street and sidewalks form the central traversal corridor.
	_box(self, "RoadSurface", Vector3(0, -0.18, 0), Vector3(24, 0.35, 110), asphalt)
	_box(self, "WestSidewalk", Vector3(-14.2, -0.02, 0), Vector3(4.4, 0.45, 110), concrete)
	_box(self, "EastSidewalk", Vector3(14.2, -0.02, 0), Vector3(4.4, 0.45, 110), concrete)
	_box(self, "WestCurb", Vector3(-12.05, 0.08, 0), Vector3(0.22, 0.25, 110), curb)
	_box(self, "EastCurb", Vector3(12.05, 0.08, 0), Vector3(0.22, 0.25, 110), curb)
	for z in range(-50, 51, 5):
		_box(self, "CenterRoadDash", Vector3(0, 0.002, z), Vector3(0.13, 0.025, 2.2), white, Vector3.ZERO, false)
	# Crosswalk at the central junction.
	for i in range(9):
		_box(self, "CrosswalkStripe", Vector3(-4.8 + i * 1.2, 0.015, 5), Vector3(0.72, 0.025, 3.0), white, Vector3.ZERO, false)

	# Small-scale street wear: repaired asphalt, cracks, manholes and drainage.
	var asphalt_patch := _material(Color(0.25, 0.26, 0.25), 0.99, 0.0, 4.2)
	var crack_mat := _material(Color(0.12, 0.13, 0.12), 1.0, 0.0, 1.0)
	var iron := _material(Color(0.20, 0.22, 0.22), 0.72, 0.35, 1.0)
	for patch_index in range(8):
		var pz := -39.0 + float(patch_index) * 10.5
		var px := -7.0 if patch_index % 2 == 0 else 6.0
		_box(self, "AsphaltRepairPatch", Vector3(px, 0.004, pz), Vector3(2.4 + float(patch_index % 3) * 0.6, 0.018, 1.1), asphalt_patch, Vector3(0, deg_to_rad(float((patch_index % 3) - 1) * 7.0), 0), false)
	for crack_index in range(18):
		var cz := -47.0 + float(crack_index) * 5.1
		var cx := -8.0 + float((crack_index * 7) % 15)
		_box(self, "AsphaltHairlineCrack", Vector3(cx, 0.009, cz), Vector3(0.035, 0.012, 0.75 + float(crack_index % 4) * 0.22), crack_mat, Vector3(0, deg_to_rad(float((crack_index * 31) % 50 - 25)), 0), false)
	for drain_index in range(7):
		var dz := -42.0 + float(drain_index) * 14.0
		for side in [-1.0, 1.0]:
			_box(self, "StormDrainFrame", Vector3(side * 11.72, 0.215, dz), Vector3(0.34, 0.035, 1.25), iron, Vector3.ZERO, false)
			for slot in range(7):
				_box(self, "StormDrainSlot", Vector3(side * 11.72, 0.237, dz - 0.48 + float(slot) * 0.16), Vector3(0.25, 0.012, 0.045), crack_mat, Vector3.ZERO, false)
	for manhole_index in range(4):
		var mz := -32.0 + float(manhole_index) * 22.0
		var cover := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = 0.48
		disk.bottom_radius = 0.48
		disk.height = 0.035
		cover.mesh = disk
		cover.name = "ManholeCover"
		cover.position = Vector3(3.8 if manhole_index % 2 == 0 else -3.8, 0.015, mz)
		cover.material_override = iron
		add_child(cover)
		for groove in range(5):
			_box(self, "ManholeGroove", cover.position + Vector3(-0.29 + float(groove) * 0.145, 0.023, 0), Vector3(0.025, 0.008, 0.58), crack_mat, Vector3.ZERO, false)

	# Concrete sidewalk expansion joints and tactile warning strips at crossing corners.
	var joint_mat := _material(Color(0.48, 0.47, 0.43), 0.98, 0.0, 1.0)
	for joint_index in range(22):
		var jz := -52.0 + float(joint_index) * 4.8
		for side in [-1.0, 1.0]:
			_box(self, "SidewalkExpansionJoint", Vector3(side * 14.2, 0.211, jz), Vector3(4.1, 0.009, 0.035), joint_mat, Vector3.ZERO, false)
	for side in [-1.0, 1.0]:
		_box(self, "TactilePaving", Vector3(side * 10.4, 0.214, 5.0), Vector3(2.1, 0.025, 1.4), yellow, Vector3.ZERO, false)
		for dot_x in range(7):
			for dot_z in range(4):
				var tactile_dot := MeshInstance3D.new()
				var dot_mesh := CylinderMesh.new()
				dot_mesh.top_radius = 0.045
				dot_mesh.bottom_radius = 0.045
				dot_mesh.height = 0.025
				tactile_dot.mesh = dot_mesh
				tactile_dot.position = Vector3(side * (9.65 + float(dot_x) * 0.25), 0.24, 4.55 + float(dot_z) * 0.3)
				tactile_dot.material_override = curb
				add_child(tactile_dot)

	# Three blocks of varied mid-rise buildings on each side, with repetitive but varied facades.
	var facades: Array[Material] = [brick_a, brick_b, plaster, concrete]
	for side in [-1.0, 1.0]:
		for block in range(5):
			var z := -40.0 + float(block) * 20.0
			var width := 10.0 + float(block % 3) * 1.5
			var height := 10.0 + float((block + 1) % 3) * 3.5
			var x := side * (19.0 + width * 0.5)
			var facade: Material = facades[(block + (1 if side > 0 else 0)) % facades.size()]
			_box(self, "Building_%s_%02d" % ["E" if side > 0 else "W", block], Vector3(x, height * 0.5 - 0.02, z), Vector3(width, height, 17.0), facade)
			# Flat roof parapet and subtle cornice.
			_box(self, "RoofParapet", Vector3(x, height + 0.35, z), Vector3(width + 0.15, 0.7, 17.15), concrete)
			# Window grids face the street, using dark frames and muted reflective glass.
			var front_x := side * 19.05
			for floor_index in range(maxi(2, int(height / 3.0))):
				var wy := 1.9 + floor_index * 2.8
				if wy > height - 1.0:
					continue
				for col in range(3):
					var wz := z - 5.2 + col * 5.0
					_box(self, "WindowFrame", Vector3(front_x, wy, wz), Vector3(0.16, 1.45, 1.75), dark_metal, Vector3.ZERO, false)
					_box(self, "WindowGlass", Vector3(front_x - side * 0.09, wy, wz), Vector3(0.04, 1.22, 1.48), glass, Vector3.ZERO, false)
					_box(self, "WindowSill", Vector3(front_x - side * 0.12, wy - 0.82, wz), Vector3(0.22, 0.12, 1.9), curb, Vector3.ZERO, false)
					# Narrow mullions and lintels give windows a more convincing assembled frame.
					_box(self, "WindowMullion", Vector3(front_x - side * 0.13, wy, wz), Vector3(0.055, 1.3, 0.07), dark_metal, Vector3.ZERO, false)
					_box(self, "WindowLintel", Vector3(front_x - side * 0.13, wy + 0.76, wz), Vector3(0.22, 0.09, 1.88), concrete, Vector3.ZERO, false)
					if (floor_index + col + block) % 3 == 0:
						_box(self, "FacadeACUnit", Vector3(front_x - side * 0.42, wy - 0.15, wz + 1.25), Vector3(0.38, 0.42, 0.72), dark_metal, Vector3.ZERO, false)
						_box(self, "ACVentPanel", Vector3(front_x - side * 0.63, wy - 0.15, wz + 1.25), Vector3(0.025, 0.28, 0.52), iron, Vector3.ZERO, false)
			# Ground-floor storefronts and understated signage panels (no emissive/neon).
			_box(self, "ShopfrontGlass", Vector3(side * 19.03, 1.45, z - 3.0), Vector3(0.12, 2.5, 3.2), glass, Vector3.ZERO, false)
			_box(self, "ShopDoor", Vector3(side * 19.0, 1.25, z + 1.5), Vector3(0.18, 2.3, 1.0), dark_metal, Vector3.ZERO, false)
			_box(self, "ShopSign", Vector3(side * 19.0, 3.1, z - 2.8), Vector3(0.22, 0.55, 4.0), wood, Vector3.ZERO, false)
			# Fire escape platforms, rails, and ladder-like side detail.
			if block % 2 == 0:
				for level in range(2):
					var fy := 3.6 + level * 3.0
					_box(self, "FireEscapeLanding", Vector3(side * 19.55, fy, z + 5.8), Vector3(1.0, 0.12, 4.0), dark_metal, Vector3.ZERO, false)
					_box(self, "FireEscapeRail", Vector3(side * 19.55, fy + 0.55, z + 3.85), Vector3(1.0, 0.08, 0.08), dark_metal, Vector3.ZERO, false)
					_box(self, "FireEscapeRail", Vector3(side * 19.55, fy + 0.55, z + 7.75), Vector3(1.0, 0.08, 0.08), dark_metal, Vector3.ZERO, false)

	# Street furniture, bins, trees, bollards, and warm-white street lamps.
	for z in range(-40, 46, 12):
		for side in [-1.0, 1.0]:
			var x := side * 14.5
			_box(self, "TreeTrunk", Vector3(x, 1.0, z), Vector3(0.35, 2.0, 0.35), wood)
			var crown := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 1.35
			sphere.height = 2.7
			crown.mesh = sphere
			crown.position = Vector3(x, 2.8, z)
			crown.material_override = foliage
			add_child(crown)
			_box(self, "StreetBin", Vector3(side * 11.1, 0.65, z + 2.5), Vector3(0.7, 1.3, 0.7), dark_metal)
			# Planter curbs, soil and low street-level clutter.
			_box(self, "TreePlanterRim", Vector3(x, 0.25, z), Vector3(2.25, 0.18, 2.25), curb)
			_box(self, "TreePlanterSoil", Vector3(x, 0.35, z), Vector3(1.95, 0.08, 1.95), wood, Vector3.ZERO, false)
			_box(self, "LampPost", Vector3(side * 10.8, 3.0, z + 4.5), Vector3(0.12, 6.0, 0.12), dark_metal, Vector3.ZERO, false)
			_box(self, "LampArm", Vector3(side * 10.45, 5.7, z + 4.5), Vector3(0.8, 0.1, 0.12), dark_metal, Vector3.ZERO, false)
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(side * 10.2, 5.55, z + 4.5)
			lamp.light_color = Color(1.0, 0.87, 0.69)
			lamp.light_energy = 0.45
			lamp.omni_range = 7.0
			add_child(lamp)
			for bollard in range(3):
				_box(self, "Bollard", Vector3(side * 11.9, 0.5, z - 2.0 + bollard * 1.0), Vector3(0.18, 1.0, 0.18), dark_metal)

	# Parked, low-detail civilian vehicles as static obstacles with visible wheels and windows.
	_build_car(Vector3(-6.8, 0.0, -13.0), 0.0, dark_metal, glass, white)
	_build_car(Vector3(7.1, 0.0, 20.0), 180.0, brick_b, glass, dark_metal)
	_build_car(Vector3(-7.0, 0.0, 31.0), 0.0, plaster, glass, dark_metal)

	# Traversal test: a curb ramp, stair flight, and a climbable ladder zone.
	_box(self, "StairBase", Vector3(-9.0, 0.12, -2.0), Vector3(3.0, 0.24, 5.0), curb)
	for i in range(6):
		var h := 0.18 * float(i + 1)
		_box(self, "TraversalStep_%02d" % i, Vector3(-9.0, h * 0.5, -4.0 + i * 0.72), Vector3(2.8, h, 0.78), concrete)
	_box(self, "LadderLeftRail", Vector3(8.8, 2.0, -28.0), Vector3(0.12, 4.0, 0.12), dark_metal, Vector3.ZERO, false)
	_box(self, "LadderRightRail", Vector3(9.7, 2.0, -28.0), Vector3(0.12, 4.0, 0.12), dark_metal, Vector3.ZERO, false)
	for rung in range(10):
		_box(self, "LadderRung", Vector3(9.25, 0.25 + rung * 0.38, -28.0), Vector3(0.95, 0.07, 0.08), dark_metal, Vector3.ZERO, false)
	var ladder_zone := Area3D.new()
	ladder_zone.name = "LadderZone"
	ladder_zone.add_to_group("climbable_ladder")
	ladder_zone.position = Vector3(9.25, 2.0, -28.0)
	ladder_zone.collision_layer = 0
	ladder_zone.collision_mask = 1
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(1.5, 4.2, 1.2)
	zone_shape.shape = zone_box
	ladder_zone.add_child(zone_shape)
	add_child(ladder_zone)


func _build_car(pos: Vector3, yaw: float, body_mat: Material, glass_mat: Material, trim_mat: Material) -> void:
	var car := Node3D.new()
	car.position = pos
	car.rotation.y = deg_to_rad(yaw)
	add_child(car)
	_box(car, "CarBody", Vector3(0, 0.65, 0), Vector3(2.0, 0.85, 4.2), body_mat)
	_box(car, "CarCabin", Vector3(0, 1.25, -0.2), Vector3(1.65, 0.75, 2.0), glass_mat, Vector3.ZERO, false)
	for x in [-1.03, 1.03]:
		for z in [-1.3, 1.3]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.34
			cylinder.bottom_radius = 0.34
			cylinder.height = 0.2
			wheel.mesh = cylinder
			wheel.position = Vector3(x, 0.35, z)
			wheel.rotation.z = deg_to_rad(90)
			wheel.material_override = trim_mat
			car.add_child(wheel)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "FLATGROUND // CITY BLOCK\nWASD Move   SHIFT Sprint   CTRL Crouch/Slide   SPACE Bunny Hop   ESC Release Mouse"
	label.position = Vector2(24, 22)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	layer.add_child(label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-5, -12)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	layer.add_child(crosshair)
