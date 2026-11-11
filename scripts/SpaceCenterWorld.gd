extends RefCounted

## Kennedy Space Center scenery, pad effects and dynamic launch atmosphere.

const KENNEDY := preload("res://assets/3d-models/launch_area/kennedy_launch_area.glb")
const SMOKE_SHADER := preload("res://assets/vfx/launch_smoke.gdshader")
const DENSE_SMOKE := preload("res://assets/vfx/kenney/smoke_08.png")
const SOFT_SMOKE := preload("res://assets/vfx/kenney/smoke_07.png")
const EARTH_VISUAL := preload("res://scripts/EarthVisual.gd")
const STATION_RANGE_M := 14000.0
const PAD_DETAIL_RANGE_M := 3500.0
const STRUCTURE_RANGE_M := 7000.0
const PLANE_BLEND_BEGIN_M := 6000.0
const PLANE_BLEND_END_M := 8500.0
const GROUND_BLEND_BEGIN_M := 3500.0
const GROUND_BLEND_END_M := 11500.0

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

static func add_scenery(station: Node3D) -> MeshInstance3D:
	var area := KENNEDY.instantiate() as Node3D
	station.add_child(area)
	var origin := area.find_child("launch_origin", true, false) as Node3D
	area.position -= area.to_local(origin.global_position)
	for node in area.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var size := mesh.get_aabb().size
		# Small structures drop out before the barrier island and the water.
		mesh.visibility_range_end = clampf(size.length() * 25.0, 3500.0, STRUCTURE_RANGE_M)
	var ground := MeshInstance3D.new()
	ground.name = "KennedyGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(12288.0, 12288.0)
	ground.mesh = plane
	ground.position.y = EARTH_VISUAL.GROUND_HEIGHT_M
	ground.material_override = EARTH_VISUAL.make_surface(true)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	station.add_child(ground)
	return ground

static func populate_space_center(station: Node3D, rocket_height: float, rocket_radius: float) -> Dictionary:
	var ground := add_scenery(station)
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

	var exhaust := [
		_pad_cloud(rig, Vector3(0.95, 0.13, 0.31), pad_scale, DENSE_SMOKE, false),
		_pad_cloud(rig, Vector3(-0.91, 0.12, 0.39), pad_scale, SOFT_SMOKE, false),
		_pad_cloud(rig, Vector3(0.82, 0.12, 0.57), pad_scale, SOFT_SMOKE, true),
		_pad_cloud(rig, Vector3(-0.89, 0.14, 0.45), pad_scale, DENSE_SMOKE, true)
	]
	return {"root": rig, "clamps": clamps, "pad_smoke": exhaust,
		"ground": ground, "ground_material": ground.material_override}

static func set_pad_exhaust(pad: Dictionary, firing: bool) -> void:
	for cloud: CPUParticles3D in pad.pad_smoke:
		if cloud.emitting != firing:
			cloud.emitting = firing

static func _pad_cloud(parent: Node3D, direction: Vector3, size: float,
		texture: Texture2D, lingering: bool) -> CPUParticles3D:
	var puff := QuadMesh.new()
	puff.size = (Vector2(13.0, 7.0) if lingering else Vector2(6.5, 5.2)) * size
	var material := ShaderMaterial.new()
	material.shader = SMOKE_SHADER
	material.set_shader_parameter("smoke_texture", texture)
	puff.material = material

	var growth := Curve.new()
	growth.max_value = 3.0
	growth.add_point(Vector2(0.0, 0.70))
	growth.add_point(Vector2(0.34, 1.53))
	growth.add_point(Vector2(1.0, 2.65))
	var tint := Gradient.new()
	if lingering:
		tint.offsets = PackedFloat32Array([0.0, 0.05, 0.16, 0.55, 0.8, 1.0])
		tint.colors = PackedColorArray([
			Color(1.0, 0.96, 0.90, 0.0), Color(1.0, 0.97, 0.93, 0.86),
			Color(0.98, 0.98, 0.97, 0.94), Color(0.94, 0.95, 0.96, 0.76),
			Color(0.88, 0.90, 0.93, 0.40), Color(0.88, 0.90, 0.93, 0.0)
		])
	else:
		tint.offsets = PackedFloat32Array([0.0, 0.08, 0.25, 0.58, 1.0])
		tint.colors = PackedColorArray([
			Color(1.0, 0.89, 0.76, 0.0), Color(1.0, 0.94, 0.85, 0.92),
			Color(0.98, 0.97, 0.94, 0.87), Color(0.90, 0.91, 0.93, 0.48),
			Color(0.86, 0.88, 0.91, 0.0)
		])

	var smoke := CPUParticles3D.new()
	smoke.mesh = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.emitting = false
	smoke.amount = 100 if lingering else 76
	smoke.lifetime = 24.0 if lingering else 7.5
	smoke.randomness = 0.61
	# The floating origin moves the pad. Local particles stay grounded in the scene.
	smoke.local_coords = true
	smoke.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	smoke.position = Vector3(direction.x * 2.4, 2.45 if lingering else 1.75, 0.7) * size
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = (2.0 if lingering else 0.9) * size
	smoke.direction = direction.normalized()
	smoke.spread = 18.0 if lingering else 28.0
	smoke.gravity = (Vector3(0.04, 0.035, 0.06) if lingering else Vector3(0, 0.88, 0)) * size
	smoke.initial_velocity_min = (0.8 if lingering else 6.0) * size
	smoke.initial_velocity_max = (2.9 if lingering else 11.0) * size
	smoke.damping_min = (0.05 if lingering else 0.65) * size
	smoke.damping_max = (0.16 if lingering else 1.65) * size
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	smoke.angular_velocity_min = -24.0
	smoke.angular_velocity_max = 24.0
	smoke.scale_amount_min = 0.72
	smoke.scale_amount_max = 1.35
	smoke.scale_amount_curve = growth
	smoke.color_ramp = tint
	parent.add_child(smoke)
	return smoke

static func update_visibility(station: Node3D, pad: Dictionary, distance_m: float) -> float:
	station.visible = distance_m < STATION_RANGE_M
	pad.root.visible = distance_m < PAD_DETAIL_RANGE_M
	pad.ground.visible = distance_m < PLANE_BLEND_END_M
	pad.ground_material.set_shader_parameter("plane_weight",
		1.0 - smoothstep(PLANE_BLEND_BEGIN_M, PLANE_BLEND_END_M, distance_m))
	var detail := 1.0 - smoothstep(GROUND_BLEND_BEGIN_M, GROUND_BLEND_END_M, distance_m)
	pad.ground_material.set_shader_parameter("local_detail", detail)
	return detail

static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = material
	parent.add_child(item)
	return item
