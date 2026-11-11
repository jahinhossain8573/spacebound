extends RefCounted

## Procedural 3D Space Center (KSC-inspired coastal launch complex) and dynamic atmosphere
## for Launch.gd and shared-world FlightView.gd. Built with standard meshes for gl_compatibility.

const SKY_ZENITH_DAY := Color("5079a6")
const SKY_HORIZON_DAY := Color("cbd6db")
const GROUND_HORIZON_DAY := Color("8d9c7e")
const GROUND_BOTTOM_DAY := Color("3e5729")
const SPACE_COLOR := Color("05070d")

static func mat(albedo: Color, roughness := 0.85, metallic := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func create_environment() -> Dictionary:
	var environment := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_ZENITH_DAY
	sky_mat.sky_horizon_color = SKY_HORIZON_DAY
	sky_mat.ground_horizon_color = GROUND_HORIZON_DAY
	sky_mat.ground_bottom_color = GROUND_BOTTOM_DAY
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b7c6d6")
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	return {"environment": environment, "sky_material": sky_mat}

static func update_atmosphere(env_data: Dictionary, altitude_m: float) -> void:
	if env_data.is_empty():
		return
	var env: Environment = env_data.get("environment")
	var sky_mat: ProceduralSkyMaterial = env_data.get("sky_material")
	if env == null or sky_mat == null:
		return
	var t := clampf(altitude_m / 65000.0, 0.0, 1.0)
	var curved := pow(t, 0.65)
	sky_mat.sky_top_color = SKY_ZENITH_DAY.lerp(SPACE_COLOR, curved)
	sky_mat.sky_horizon_color = SKY_HORIZON_DAY.lerp(Color("16294a"), clampf(t * 1.8, 0.0, 1.0)).lerp(SPACE_COLOR, clampf((t - 0.45) / 0.55, 0.0, 1.0))
	sky_mat.ground_horizon_color = GROUND_HORIZON_DAY.lerp(SPACE_COLOR, curved)
	sky_mat.ground_bottom_color = GROUND_BOTTOM_DAY.lerp(SPACE_COLOR, curved)
	env.ambient_light_color = Color("b7c6d6").lerp(Color("455878"), curved)
	env.ambient_light_energy = lerpf(0.72, 0.42, curved)

static func populate_space_center(station: Node3D, rotating_surface: Node3D, rocket_height: float, rocket_radius := 0.6) -> Dictionary:
	var grass_mat := mat(Color("587a35"), 0.95)
	var grass_far_mat := mat(Color("4e6e30"), 0.96)
	var berm_mat := mat(Color("b99f94"), 0.9)
	var berm_trim_mat := mat(Color("9e877d"), 0.9)
	var pad_deck_mat := mat(Color("686e75"), 0.85)
	var crawler_mat := mat(Color("7b8187"), 0.88)
	var scorch_outer_mat := mat(Color("1c1e21"), 0.98)
	var scorch_core_mat := mat(Color("090a0c"), 1.0)
	var steel_mat := mat(Color("4c5561"), 0.55, 0.45)
	var clamp_red_mat := mat(Color("9e3026"), 0.65, 0.35)
	var dark_bldg_mat := mat(Color("262c33"), 0.78)
	var mid_bldg_mat := mat(Color("3a414a"), 0.75)
	var mountain_mat := mat(Color("4a5952"), 0.95)
	var mountain_far_mat := mat(Color("5d6e6c"), 0.96)

	# Large regional continental shelf on co-rotating surface so ascent from 5 km - 60 km shows green coast
	var region := MeshInstance3D.new()
	var region_cyl := CylinderMesh.new()
	region_cyl.top_radius = 42000.0
	region_cyl.bottom_radius = 43000.0
	region_cyl.height = 3.0
	region_cyl.radial_segments = 48
	region.mesh = region_cyl
	region.position = Vector3(-6000.0, 6371000.0 - 3.2, -8000.0)
	region.material_override = grass_far_mat
	rotating_surface.add_child(region)

	# Local KSC flat grassy plain inside station (hidden above 5 km)
	var plain := MeshInstance3D.new()
	var plain_cyl := CylinderMesh.new()
	plain_cyl.top_radius = 4800.0
	plain_cyl.bottom_radius = 4800.0
	plain_cyl.height = 0.6
	plain_cyl.radial_segments = 64
	plain.mesh = plain_cyl
	plain.position = Vector3(0.0, -1.5, -600.0)
	plain.material_override = grass_mat
	station.add_child(plain)

	# Raised sloped tan/pinkish-concrete KSP pad mound (octagonal frustum)
	var pad_scale := clampf(rocket_height / 18.0, 1.0, 2.2)
	var deck_r := 22.0 * pad_scale
	var berm_r := 33.0 * pad_scale

	var berm := MeshInstance3D.new()
	var berm_mesh := CylinderMesh.new()
	berm_mesh.top_radius = deck_r + 1.8
	berm_mesh.bottom_radius = berm_r
	berm_mesh.height = 1.25
	berm_mesh.radial_segments = 8
	berm.mesh = berm_mesh
	berm.position = Vector3(0.0, -0.62, 0.0)
	berm.rotation.y = PI / 8.0
	berm.material_override = berm_mat
	station.add_child(berm)

	# Sloped crawlerway ramp joining the pad mound on the -Z side (leading toward KSC)
	var ramp := MeshInstance3D.new()
	var ramp_box := BoxMesh.new()
	ramp_box.size = Vector3(18.0 * pad_scale, 1.2, 22.0 * pad_scale)
	ramp.mesh = ramp_box
	ramp.position = Vector3(0.0, -0.66, -(deck_r + 8.0 * pad_scale))
	ramp.rotation.x = deg_to_rad(3.2)
	ramp.material_override = berm_trim_mat
	station.add_child(ramp)

	# Circular grey concrete pad deck right beneath the rocket (y = -0.02 top)
	var deck := MeshInstance3D.new()
	var deck_mesh := CylinderMesh.new()
	deck_mesh.top_radius = deck_r
	deck_mesh.bottom_radius = deck_r + 0.5
	deck_mesh.height = 0.12
	deck_mesh.radial_segments = 32
	deck.mesh = deck_mesh
	deck.position = Vector3(0.0, -0.06, 0.0)
	deck.material_override = pad_deck_mat
	station.add_child(deck)

	# Radial KSP blast scorch marks on the concrete pad deck
	_add_scorch_marks(station, deck_r * 0.78, scorch_outer_mat, scorch_core_mat)

	# Flame trench grate slot under rocket
	var trench := MeshInstance3D.new()
	var trench_box := BoxMesh.new()
	trench_box.size = Vector3(3.2 * pad_scale, 0.04, 9.0 * pad_scale)
	trench.mesh = trench_box
	trench.position = Vector3(0.0, -0.005, 0.0)
	trench.material_override = scorch_core_mat
	station.add_child(trench)

	# Launch table collar + 4 articulated KSP red/steel hold-down clamps around the rocket base
	var ring_r := maxf(0.85, rocket_radius * 1.45)
	var clamps: Array[Node3D] = []
	for i in 4:
		var ang := PI * 0.25 + float(i) * PI * 0.5
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(ang) * (ring_r + 0.45), 0.02, sin(ang) * (ring_r + 0.45))
		pivot.rotation.y = -ang
		station.add_child(pivot)
		# Base pedestal
		_box(pivot, Vector3(0.55, 0.55, 0.45), Vector3(0.22, 0.27, 0.0), steel_mat)
		# Hinged hold-down jaw that swings outward on clamp release
		var jaw := Node3D.new()
		jaw.position = Vector3(0.0, 0.52, 0.0)
		pivot.add_child(jaw)
		_box(jaw, Vector3(0.62, 0.22, 0.32), Vector3(-0.24, 0.08, 0.0), clamp_red_mat)
		clamps.append(jaw)

	# Strongback / umbilical tower on -X side of the rocket + hinged swing-arm
	var tower_x := -maxf(2.6, rocket_height * 0.14)
	var tower_h := rocket_height * 0.82
	_box(station, Vector3(1.1, tower_h, 1.1), Vector3(tower_x, tower_h * 0.5, 0.0), steel_mat)
	var arm_pivot := Node3D.new()
	arm_pivot.position = Vector3(tower_x + 0.45, rocket_height * 0.62, 0.0)
	station.add_child(arm_pivot)
	var arm_len := maxf(1.2, absf(tower_x) - rocket_radius - 0.35)
	_box(arm_pivot, Vector3(arm_len, 0.32, 0.42), Vector3(arm_len * 0.5, 0.0, 0.0), clamp_red_mat)

	# Pad flame-trench steam / exhaust billowing cloud particles (CPU Particles for gl_compatibility!)
	var smoke := CPUParticles3D.new()
	smoke.emitting = false
	smoke.amount = 64
	smoke.lifetime = 2.4
	smoke.explosiveness = 0.08
	smoke.randomness = 0.35
	var puff := SphereMesh.new()
	puff.radius = 0.85 * pad_scale
	puff.height = 1.7 * pad_scale
	puff.radial_segments = 10
	puff.rings = 6
	var puff_mat := StandardMaterial3D.new()
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.vertex_color_use_as_albedo = true
	puff_mat.albedo_color = Color(0.92, 0.93, 0.95, 0.62)
	puff_mat.roughness = 1.0
	puff.material = puff_mat
	smoke.mesh = puff
	smoke.local_coords = true
	smoke.position = Vector3(0.0, 0.18, 0.0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.4 * pad_scale
	smoke.direction = Vector3(0.0, 0.22, 0.0)
	smoke.spread = 86.0
	smoke.gravity = Vector3(0.0, 2.6, 0.0)
	smoke.initial_velocity_min = 7.0 * pad_scale
	smoke.initial_velocity_max = 18.0 * pad_scale
	smoke.damping_min = 3.5
	smoke.damping_max = 6.5
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.45))
	scale_curve.add_point(Vector2(0.4, 1.55))
	scale_curve.add_point(Vector2(1.0, 2.8))
	smoke.scale_amount_curve = scale_curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.88, 0.72, 0.75))
	grad.add_point(0.25, Color(0.88, 0.89, 0.92, 0.58))
	grad.set_color(1, Color(0.75, 0.78, 0.82, 0.0))
	smoke.color_ramp = grad
	station.add_child(smoke)

	# Twin parallel crawlerway tracks extending straight toward KSC (-Z)
	var track_len := 720.0
	var track_offset := 5.2 * pad_scale
	for side: float in [-1.0, 1.0]:
		_box(station, Vector3(4.6 * pad_scale, 0.08, track_len), Vector3(side * track_offset, -1.16, -(berm_r + track_len * 0.5 - 6.0)), crawler_mat)
		_box(station, Vector3(1.8 * pad_scale, 0.05, 14.0 * pad_scale), Vector3(side * track_offset, -0.18, -(deck_r + 5.5 * pad_scale)), mat(Color("7d6a60"), 0.95))

	# Pad perimeter fuel spheres on the sides
	for sx: float in [-1.0, 1.0]:
		var sphere_tank := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 2.4 * pad_scale
		sm.height = 4.8 * pad_scale
		sphere_tank.mesh = sm
		sphere_tank.position = Vector3(sx * (berm_r + 6.0), 1.0 * pad_scale, 10.0 * pad_scale)
		sphere_tank.material_override = mat(Color("dce2e8"), 0.55, 0.2)
		station.add_child(sphere_tank)

	# Distant Space Center Complex along -Z horizon
	var ksc_z := -760.0
	_box(station, Vector3(58.0, 74.0, 52.0), Vector3(26.0, 35.5, ksc_z), dark_bldg_mat)
	_box(station, Vector3(46.0, 14.0, 54.0), Vector3(26.0, 76.0, ksc_z), mid_bldg_mat)
	_box(station, Vector3(18.0, 56.0, 1.2), Vector3(26.0, 27.0, ksc_z + 26.2), mat(Color("181c21"), 0.85))
	_box(station, Vector3(110.0, 24.0, 48.0), Vector3(185.0, 10.5, ksc_z + 75.0), dark_bldg_mat)
	_box(station, Vector3(48.0, 16.0, 36.0), Vector3(-60.0, 6.5, ksc_z - 30.0), mid_bldg_mat)
	for dish_cfg: Vector3 in [Vector3(-195.0, -1.2, -520.0), Vector3(-92.0, -1.2, -560.0), Vector3(-255.0, -1.2, -610.0)]:
		_add_tracking_dish(station, dish_cfg, dark_bldg_mat, steel_mat)

	# Distant mountain range arc across the horizon
	var rng := RandomNumberGenerator.new()
	rng.seed = 42069
	for i in 38:
		var angle := lerpf(-PI * 0.95, PI * 0.95, float(i) / 37.0)
		var dist := rng.randf_range(2900.0, 4200.0)
		var mw := rng.randf_range(260.0, 540.0)
		var mh := rng.randf_range(140.0, 410.0)
		var peak := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = mw * 0.06
		cone.bottom_radius = mw
		cone.height = mh
		cone.radial_segments = 7
		peak.mesh = cone
		peak.position = Vector3(sin(angle) * dist, mh * 0.45 - 8.0, -cos(angle) * dist - 500.0)
		peak.rotation.y = rng.randf() * TAU
		peak.material_override = mountain_mat if dist < 3500.0 else mountain_far_mat
		station.add_child(peak)

	return {"clamps": clamps, "umbilical_arm": arm_pivot, "pad_smoke": smoke}

static func _add_scorch_marks(parent: Node3D, radius: float, outer_mat: Material, core_mat: Material) -> void:
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = radius * 0.36
	dm.bottom_radius = radius * 0.36
	dm.height = 0.015
	dm.radial_segments = 24
	disc.mesh = dm
	disc.position = Vector3(0.0, 0.008, 0.0)
	disc.material_override = core_mat
	parent.add_child(disc)

	var streak_mesh := ImmediateMesh.new()
	streak_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rays := 22
	for i in rays:
		var a0 := TAU * float(i) / rays
		var a1 := TAU * float(i + 0.55) / rays
		var a_mid := (a0 + a1) * 0.5
		var len_r := radius * (0.62 + 0.36 * absf(sin(float(i) * 2.3 + 0.4)))
		var p0 := Vector3(0.0, 0.004, 0.0)
		var p1 := Vector3(cos(a0) * radius * 0.28, 0.004, sin(a0) * radius * 0.28)
		var p2 := Vector3(cos(a_mid) * len_r, 0.004, sin(a_mid) * len_r)
		var p3 := Vector3(cos(a1) * radius * 0.28, 0.004, sin(a1) * radius * 0.28)
		streak_mesh.surface_set_normal(Vector3.UP)
		streak_mesh.surface_add_vertex(p0)
		streak_mesh.surface_add_vertex(p1)
		streak_mesh.surface_add_vertex(p2)
		streak_mesh.surface_set_normal(Vector3.UP)
		streak_mesh.surface_add_vertex(p0)
		streak_mesh.surface_add_vertex(p2)
		streak_mesh.surface_add_vertex(p3)
	streak_mesh.surface_end()
	var streaks := MeshInstance3D.new()
	streaks.mesh = streak_mesh
	streaks.material_override = outer_mat
	parent.add_child(streaks)

static func _add_tracking_dish(parent: Node3D, pos: Vector3, base_mat: Material, dish_mat: Material) -> void:
	_box(parent, Vector3(12.0, 7.0, 12.0), pos + Vector3(0, 3.5, 0), base_mat)
	var dish := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 9.5
	cyl.bottom_radius = 2.0
	cyl.height = 4.2
	cyl.radial_segments = 14
	dish.mesh = cyl
	dish.position = pos + Vector3(0, 10.5, 0)
	dish.rotation_degrees = Vector3(38.0, 25.0, 0.0)
	dish.material_override = dish_mat
	parent.add_child(dish)

static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = material
	parent.add_child(item)
	return item
