extends RefCounted

## Kennedy Space Center scenery, pad effects and dynamic launch atmosphere.

const KENNEDY := preload("res://assets/3d-models/launch_area/kennedy_launch_area.glb")
const STATION_RANGE_M := 14000.0
const PAD_DETAIL_RANGE_M := 3500.0

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

static func populate_space_center(station: Node3D, rocket_height: float, rocket_radius: float) -> Dictionary:
	var area := KENNEDY.instantiate() as Node3D
	station.add_child(area)
	var origin := area.find_child("launch_origin", true, false) as Node3D
	area.position -= area.to_local(origin.global_position)
	for node in area.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var size := mesh.get_aabb().size
		# Small structures drop out before the barrier island and the water.
		mesh.visibility_range_end = clampf(size.length() * 25.0, 3500.0, STATION_RANGE_M)
	var rig := Node3D.new()
	rig.name = "PadEffects"
	station.add_child(rig)
	var pad_scale := clampf(rocket_height / 18.0, 1.0, 2.2)
	var steel_mat := mat(Color("4c5561"), 0.55, 0.35)
	var clamp_red_mat := mat(Color("262c33"), 0.65, 0.35)

	# Launch table collar + 4 articulated KSP red/steel hold-down clamps around the rocket base
	var ring_r := maxf(0.85, rocket_radius * 1.45)
	var clamps: Array[Node3D] = []
	for i in 4:
		var ang := PI * 0.25 + float(i) * PI * 0.5
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(ang) * (ring_r + 0.45), 0.02, sin(ang) * (ring_r + 0.45))
		pivot.rotation.y = -ang
		rig.add_child(pivot)
		# Base pedestal
		_box(pivot, Vector3(0.55, 0.55, 0.45), Vector3(0.22, 0.27, 0.0), steel_mat)
		# Hinged hold-down jaw that swings outward on clamp release
		var jaw := Node3D.new()
		jaw.position = Vector3(0.0, 0.52, 0.0)
		pivot.add_child(jaw)
		_box(jaw, Vector3(0.62, 0.22, 0.32), Vector3(-0.24, 0.08, 0.0), clamp_red_mat)
		clamps.append(jaw)

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
	rig.add_child(smoke)

	return {"root": rig, "clamps": clamps, "pad_smoke": smoke}

static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = material
	parent.add_child(item)
	return item
