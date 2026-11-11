extends Node3D

const FLAME := preload("res://assets/vfx/kenney/flame_04.png")
const PLUME_SHADER := preload("res://assets/vfx/launch_plume.gdshader")

var _plume_material: ShaderMaterial
var _fringe: CPUParticles3D
var _light: OmniLight3D

func setup(length_m: float, nozzle_width: float, upper_stage: bool) -> void:
	# The quad's top edge stays at the nozzle as the plume changes size.
	var shape := QuadMesh.new()
	shape.size = Vector2(nozzle_width * 3.4, length_m)
	shape.center_offset.y = -length_m * 0.5
	_plume_material = ShaderMaterial.new()
	_plume_material.shader = PLUME_SHADER
	_plume_material.set_shader_parameter("turbulence", FLAME)
	var plume := MeshInstance3D.new()
	plume.mesh = shape
	plume.material_override = _plume_material
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader turns the quad about the nozzle axis.
	plume.extra_cull_margin = shape.size.x * 0.5
	add_child(plume)

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# The flame texture is grayscale. Add its light so overlapping billboards
	# cannot darken the plume's hot core when viewed along the exhaust.
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = FLAME
	var curl := QuadMesh.new()
	curl.size = Vector2(nozzle_width * 1.65, nozzle_width * 1.9)
	curl.material = material
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.68, 1.0])
	fade.colors = PackedColorArray([
		Color(1.0, 0.96, 0.74, 0.0), Color(1.0, 0.88, 0.64, 0.68),
		Color(1.0, 0.59, 0.28, 0.36), Color(1.0, 0.41, 0.12, 0.0)
	])
	_fringe = CPUParticles3D.new()
	_fringe.mesh = curl
	_fringe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fringe.position.y = -length_m * 0.30
	_fringe.local_coords = true
	_fringe.emitting = false
	_fringe.amount = 14 if upper_stage else 30
	_fringe.lifetime = 0.48
	_fringe.preprocess = 0.3
	_fringe.direction = Vector3.DOWN
	_fringe.gravity = Vector3.ZERO
	_fringe.spread = 12.0
	_fringe.initial_velocity_min = length_m * 1.02
	_fringe.initial_velocity_max = length_m * 1.5
	_fringe.angle_min = -180.0
	_fringe.angle_max = 180.0
	_fringe.angular_velocity_min = -65.0
	_fringe.angular_velocity_max = 65.0
	_fringe.scale_amount_min = 0.65
	_fringe.scale_amount_max = 1.5
	_fringe.color_ramp = fade
	add_child(_fringe)

	_light = OmniLight3D.new()
	_light.position.y = -nozzle_width
	_light.light_color = Color("ffac5b")
	_light.omni_range = nozzle_width * 13.0
	add_child(_light)
	hide()

func update_thrust(throttle: float, altitude_m: float) -> void:
	var firing := throttle > 0.0
	visible = firing
	if _fringe.emitting != firing:
		_fringe.emitting = firing
	if not firing:
		return
	var expansion := clampf(altitude_m / 55000.0, 0.0, 1.0)
	var power := maxf(0.25, throttle)
	var width := lerpf(1.0, 2.35, expansion) * sqrt(power)
	scale = Vector3(width, power * lerpf(1.0, 1.65, expansion), width)
	_plume_material.set_shader_parameter("vacuum_expansion", expansion)
	_light.light_energy = throttle * lerpf(3.2, 0.6, expansion)
