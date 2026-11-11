extends Node3D

const DURATION := 3.0
const CLOUD_SHADER := preload("res://assets/vfx/launch_breakup.gdshader")
const CLOUD_MASKS := [
	preload("res://assets/vfx/kenney/smoke_08.png"),
	preload("res://assets/vfx/kenney/smoke_07.png"),
]

var _age := 0.0
var _air: float
var _height: float
var _drift: Vector3
var _grounded: bool
var _clouds: Array[Dictionary] = []
var _fragments: Array[Dictionary] = []
var _streaks := ImmediateMesh.new()
var _streak_material := StandardMaterial3D.new()
var _flash: OmniLight3D
var _flash_sprite: MeshInstance3D
var _rng := RandomNumberGenerator.new()

func setup(height: float, altitude_m: float, flight_drift: Vector3, on_ground: bool) -> void:
	_height = height
	_grounded = on_ground
	_air = lerpf(1.0, 0.10, smoothstep(13000.0, 85000.0, altitude_m))
	_drift = Vector3.ZERO if on_ground else flight_drift
	_rng.seed = 2042 + int(height * 17.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	for i in 16:
		var material := ShaderMaterial.new()
		material.shader = CLOUD_SHADER
		material.set_shader_parameter("cloud_texture", CLOUD_MASKS[i % CLOUD_MASKS.size()])
		material.set_shader_parameter("air", _air)
		material.set_shader_parameter("heat_duration", _rng.randf_range(0.63, 1.10) * lerpf(0.57, 1.0, _air))
		var puff := _mesh(quad, material)
		var outward := _direction()
		if _grounded:
			outward.y = absf(outward.y) * 0.65
		if i < 4:
			outward *= 0.39
		_clouds.append({
			"node": puff, "material": material, "direction": outward,
			"delay": 0.0 if i < 4 else _rng.randf_range(0.03, 0.35),
			"size": _rng.randf_range(0.58, 1.12), "rotation": _rng.randf_range(0.0, TAU),
		})

	var scrap := BoxMesh.new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("504a46")
	metal.roughness = 0.8
	for i in 30:
		var outward := _direction()
		if _grounded:
			outward.y = absf(outward.y)
		var chunk: MeshInstance3D
		if i < 11:
			chunk = _mesh(scrap, metal)
			chunk.scale = Vector3(0.018, 0.045, 0.011) * height * _rng.randf_range(0.6, 1.6)
		_fragments.append({
			"node": chunk, "velocity": outward * height * _rng.randf_range(0.65, 2.5) + _drift * 0.7,
			"spin": _direction() * _rng.randf_range(2.0, 10.0), "glow": _rng.randf_range(0.62, 2.55),
		})
	_streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_streak_material.vertex_color_use_as_albedo = true
	_mesh(_streaks, _streak_material)
	_flash = OmniLight3D.new()
	_flash.light_color = Color("ffc879")
	_flash.omni_range = height * 4.0
	add_child(_flash)
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 0.0)
	glow.gradient = Gradient.new()
	glow.gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	glow.gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 0.73, 0.36, 0.54), Color(1.0, 0.47, 0.14, 0.0)])
	var flare := StandardMaterial3D.new()
	flare.albedo_texture = glow
	flare.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flare.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flare.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flare.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flare.billboard_keep_scale = true
	flare.render_priority = 1
	_flash_sprite = _mesh(quad, flare)
	advance(0.035)

func advance(delta: float) -> void:
	_age += delta
	_flash.light_energy = 12.0 * exp(-_age * 10.0)
	_flash_sprite.visible = _age < 0.24
	if _flash_sprite.visible:
		_flash_sprite.scale = Vector3.ONE * _height * (0.30 + 2.8 * _age)
		(_flash_sprite.material_override as StandardMaterial3D).albedo_color.a = 1.0 - smoothstep(0.025, 0.24, _age)
	for cloud in _clouds:
		var age: float = _age - cloud.delay
		var puff: MeshInstance3D = cloud.node
		puff.visible = age > 0.0
		if not puff.visible:
			continue
		var expansion := 1.0 - exp(-age * 2.4)
		var radius: float = _height * cloud.size * (0.15 + expansion * lerpf(0.69, 0.47, _air))
		puff.scale = Vector3(radius, radius * 1.13, radius)
		puff.position = cloud.direction * (_height * (0.12 + expansion * 0.68))
		puff.position += _drift * minf(age, 1.5) * 0.26 + Vector3.UP * age * _height * 0.11 * _air
		var material: ShaderMaterial = cloud.material
		material.set_shader_parameter("age", age)
		material.set_shader_parameter("rotation", cloud.rotation + age * 0.42)
	_update_fragments()

func _update_fragments() -> void:
	_streaks.clear_surfaces()
	var has_trails := false
	for piece in _fragments:
		var velocity: Vector3 = piece.velocity
		var position := _fragment_position(velocity, _age)
		var buried := _grounded and position.y < -_height * 0.18
		var chunk: MeshInstance3D = piece.node
		if chunk:
			chunk.position = position
			chunk.rotation = piece.spin * _age
			chunk.visible = not buried
		var glow := 1.0 - smoothstep(0.12, piece.glow, _age)
		if buried or glow <= 0.0:
			continue
		if not has_trails:
			_streaks.surface_begin(Mesh.PRIMITIVE_LINES)
			has_trails = true
		var tail := _fragment_position(velocity, maxf(0.0, _age - 0.10 - _age * 0.035))
		_streaks.surface_set_color(Color(1.0, 0.44, 0.12, 0.0))
		_streaks.surface_add_vertex(tail)
		_streaks.surface_set_color(Color(1.0, 0.83, 0.47, glow))
		_streaks.surface_add_vertex(position)
	if has_trails:
		_streaks.surface_end()

func _fragment_position(velocity: Vector3, time: float) -> Vector3:
	return velocity * time + Vector3.DOWN * 4.9 * time * time

func _mesh(geometry: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _direction() -> Vector3:
	var y := _rng.randf_range(-1.0, 1.0)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := sqrt(1.0 - y * y)
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)
