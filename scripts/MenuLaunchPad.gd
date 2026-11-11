extends Node3D

const FALCON_9 := preload("res://assets/3d-models/rockets/falcon9/launcher_falcon_9.glb")
const KENNEDY := preload("res://assets/3d-models/launch_area/kennedy_launch_area.glb")
const STEAM := preload("res://assets/vfx/kenney/smoke_08.png")
const MIST := preload("res://assets/vfx/kenney/smoke_07.png")
const VERTICAL_FOV := 70.0

var _camera: Camera3D
var _beacons: Array[OmniLight3D] = []
var _beacon_halos: Array[Sprite3D] = []
var _elapsed := 0.0
var _main_vent: CPUParticles3D

func _ready() -> void:
	_create_environment()
	var pad := KENNEDY.instantiate() as Node3D
	pad.rotation_degrees.y = 45.0
	add_child(pad)
	var ground := PlaneMesh.new()
	ground.size = Vector2(2400.0, 2400.0)
	ground.material = preload("res://scripts/SpaceCenterWorld.gd").mat(Color("202731"))
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.mesh = ground
	ground_mesh.position.y = -8.35
	add_child(ground_mesh)
	var rocket := FALCON_9.instantiate() as Node3D
	rocket.rotation_degrees.y = -40.0
	add_child(rocket)
	for mesh: MeshInstance3D in rocket.find_children("*", "MeshInstance3D", true, false):
		mesh.set_layer_mask_value(2, true)

	# Broad off-camera fill keeps the fairing readable above the pad lights.
	var fill := DirectionalLight3D.new()
	fill.light_cull_mask = 2
	fill.light_color = Color("cbdcff")
	fill.light_energy = 0.62
	add_child(fill)
	fill.look_at(Vector3(-0.65, 0.45, 0.55))

	_spot(Vector3(8, 12, -11), Vector3(0, 63, 0), Color("fff0d9"), 6.4, 102.0, 27.0)
	_spot(Vector3(-9, 24, 6), Vector3(0, 63, 0), Color("9fbdff"), 3.2, 80.0, 27.0)
	_spot(Vector3(11, 5, -13), Vector3(-2, 13, 1), Color("d4e4ff"), 3.0, 40.0, 34.0)

	var halo := _halo_texture()
	for height: float in [24.0, 46.0, 62.0]:
		_add_beacon(Vector3(-17.5, height, 6.5), halo)
	_add_floodlight_bank(Vector3(8, 12, -11), halo)
	_add_floodlight_bank(Vector3(-9, 24, 6), halo)
	for z: float in [15.0, 23.0, 31.0, 39.0]:
		_glow(Vector3(7.0, 0.32, z), halo, Color(1.0, 0.68, 0.31, 0.72), 0.9)

	_create_vapor()

	_camera = Camera3D.new()
	_camera.position = Vector3(15.5, 69.7, -21.8)
	_camera.far = 1400.0
	add_child(_camera)
	_camera.look_at(Vector3(14, 55, 0))
	_camera.rotate_object_local(Vector3.BACK, deg_to_rad(8.0))
	_camera.make_current()
	get_viewport().size_changed.connect(_frame_camera)
	_frame_camera()

func _frame_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.aspect()
	_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(VERTICAL_FOV * 0.5))
		* maxf(1.0, (16.0 / 9.0) / maxf(aspect, 0.1))))

func _process(delta: float) -> void:
	_elapsed += delta
	# Small changes at the vent carry downwind with newly emitted vapor.
	_main_vent.direction = Vector3(0.94, -0.18 + 0.09 * sin(_elapsed * 1.5),
		0.42 + 0.14 * sin(_elapsed * 0.81)).normalized()
	for i in _beacons.size():
		var pulse := pow(0.5 + 0.5 * cos(_elapsed * TAU / 4.5 - i * 0.38), 3.0)
		_beacons[i].light_energy = lerpf(0.16, 2.6, pulse)
		_beacon_halos[i].modulate.a = lerpf(0.13, 0.72, pulse)

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b1323")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8198c4")
	environment.ambient_light_energy = 0.26
	environment.ambient_light_sky_contribution = 0.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("101b2f")
	environment.fog_density = 0.006
	world.environment = environment
	add_child(world)

func _spot(origin: Vector3, target: Vector3, color: Color, energy: float, reach: float, angle: float) -> void:
	var light := SpotLight3D.new()
	light.position = origin
	light.light_color = color
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = angle
	light.spot_attenuation = 0.45
	add_child(light)
	light.look_at(target)

func _add_beacon(origin: Vector3, texture: Texture2D) -> void:
	var light := OmniLight3D.new()
	light.position = origin
	light.light_color = Color("ff2c22")
	light.omni_range = 8.0
	add_child(light)
	_beacons.append(light)
	_beacon_halos.append(_glow(origin, texture, Color("ff3b27"), 2.1))
	_glow(origin, texture, Color("ff9a77"), 0.32)

func _add_floodlight_bank(origin: Vector3, texture: Texture2D) -> void:
	var steel := preload("res://scripts/SpaceCenterWorld.gd").mat(Color("353d49"))
	var mast := MeshInstance3D.new()
	var support := BoxMesh.new()
	support.size = Vector3(0.28, origin.y, 0.28)
	support.material = steel
	mast.mesh = support
	mast.position = Vector3(origin.x, origin.y * 0.5, origin.z + 0.18)
	add_child(mast)
	var housing := MeshInstance3D.new()
	var bank := BoxMesh.new()
	bank.size = Vector3(1.54, 0.43, 0.35)
	bank.material = steel
	housing.mesh = bank
	housing.position = origin + Vector3(0, 0, 0.2)
	add_child(housing)
	for offset: float in [-0.5, 0.5]:
		var lamp := origin + Vector3(offset, 0, 0)
		_glow(lamp, texture, Color(0.67, 0.8, 1.0, 0.24), 4.4)
		_glow(lamp, texture, Color("f7f1df"), 0.58)

func _glow(origin: Vector3, texture: Texture2D, tint: Color, diameter: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.position = origin
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = diameter / texture.get_width()
	sprite.modulate = tint
	add_child(sprite)
	return sprite

func _halo_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.46, 1.0])
	gradient.colors = PackedColorArray([
		Color.WHITE, Color(1, 1, 1, 0.56), Color(1, 1, 1, 0.13), Color(1, 1, 1, 0)
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

func _create_vapor() -> void:
	var opacity := Gradient.new()
	opacity.offsets = PackedFloat32Array([0.0, 0.10, 0.34, 0.68, 1.0])
	opacity.colors = PackedColorArray([
		Color(0.96, 0.97, 1.0, 0.0), Color(0.96, 0.97, 1.0, 0.79),
		Color(0.90, 0.93, 0.98, 0.59), Color(0.76, 0.82, 0.91, 0.32),
		Color(0.60, 0.68, 0.80, 0.0)
	])
	var growth := Curve.new()
	growth.max_value = 3.0
	growth.add_point(Vector2(0.0, 0.27))
	growth.add_point(Vector2(0.17, 0.67))
	growth.add_point(Vector2(0.48, 1.82))
	growth.add_point(Vector2(1.0, 2.7))

	var steam := _vapor_mesh(STEAM, Vector2(2.7, 2.15))
	var mist := _vapor_mesh(MIST, Vector2(4.8, 2.4))
	var jet := _add_vent(Vector3(1.55, 47.85, -1.0), Vector3(0.94, -0.18, 0.42),
		34, 2.15, steam, growth, opacity)
	jet.initial_velocity_min = 3.4
	jet.initial_velocity_max = 5.2
	jet.scale_amount_min = 0.34
	jet.scale_amount_max = 0.60
	jet.spread = 7.0

	_main_vent = _add_vent(jet.position, jet.direction, 90, 6.5, steam, growth, opacity)
	_main_vent.initial_velocity_min = 2.3
	_main_vent.initial_velocity_max = 4.6
	_main_vent.spread = 15.0

	var lower := _add_vent(Vector3(1.62, 33.0, -0.9), Vector3(0.94, -0.34, 0.40),
		44, 5.1, steam, growth, opacity)
	lower.scale_amount_min = 0.48
	lower.scale_amount_max = 0.83
	lower.color.a = 0.72

	var pad_mist := _add_vent(Vector3(1.5, 1.6, 11.0), Vector3(0.73, 0.10, 0.67),
		58, 9.5, mist, growth, opacity)
	pad_mist.color.a = 0.61
	pad_mist.gravity = Vector3(0.14, 0.02, 0.16)
	pad_mist.spread = 18.0
	pad_mist.angle_min = -16.0
	pad_mist.angle_max = 16.0
	pad_mist.angular_velocity_min = -7.0
	pad_mist.angular_velocity_max = 7.0
	pad_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pad_mist.emission_sphere_radius = 1.4

func _vapor_mesh(texture: Texture2D, size: Vector2) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	return quad

func _add_vent(origin: Vector3, direction: Vector3, amount: int, duration: float, puff: QuadMesh,
		growth: Curve, opacity: Gradient) -> CPUParticles3D:
	var vapor := CPUParticles3D.new()
	vapor.position = origin
	vapor.mesh = puff
	vapor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vapor.amount = amount
	vapor.lifetime = duration
	vapor.preprocess = duration
	vapor.randomness = 0.65
	vapor.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	vapor.direction = direction.normalized()
	vapor.spread = 12.0
	vapor.gravity = Vector3(0.26, -0.19, 0.14)
	vapor.initial_velocity_min = 1.3
	vapor.initial_velocity_max = 2.8
	vapor.damping_min = 0.09
	vapor.damping_max = 0.23
	vapor.angle_min = -180.0
	vapor.angle_max = 180.0
	vapor.angular_velocity_min = -25.0
	vapor.angular_velocity_max = 25.0
	vapor.scale_amount_min = 0.65
	vapor.scale_amount_max = 1.26
	vapor.scale_amount_curve = growth
	vapor.color_ramp = opacity
	add_child(vapor)
	return vapor
