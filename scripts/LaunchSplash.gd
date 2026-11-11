extends Node3D

const FOAM_SHADER := preload("res://assets/vfx/water_impact_foam.gdshader")
const SPRAY_SHADER := preload("res://assets/vfx/launch_breakup.gdshader")
const SPRAY_TEXTURES := [
	preload("res://assets/vfx/kenney/smoke_07.png"),
	preload("res://assets/vfx/kenney/smoke_08.png"),
]

var _height: float
var _foam: ShaderMaterial
var _spray: Array[Dictionary] = []

func setup(height: float) -> void:
	_height = height
	_foam = ShaderMaterial.new()
	_foam.shader = FOAM_SHADER
	var surface := PlaneMesh.new()
	surface.size = Vector2.ONE * height * 6.4
	var wake := _mesh(surface, _foam)
	wake.position.y = 0.12

	var rng := RandomNumberGenerator.new()
	rng.seed = 8127
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	for i in 24:
		var material := ShaderMaterial.new()
		material.shader = SPRAY_SHADER
		material.set_shader_parameter("water", true)
		material.set_shader_parameter("cloud_texture", SPRAY_TEXTURES[i % SPRAY_TEXTURES.size()])
		var plume := _mesh(quad, material)
		var angle := TAU * (float(i) / 24.0 + rng.randf_range(-0.018, 0.018))
		var column := i % 3 == 0
		var horizontal := rng.randf_range(0.24, 0.68) if column else rng.randf_range(0.95, 1.65)
		var rise := rng.randf_range(1.8, 2.8) if column else rng.randf_range(0.45, 1.14)
		_spray.append({
			"node": plume, "velocity": Vector3(cos(angle) * horizontal, rise, sin(angle) * horizontal),
			"column": column, "delay": rng.randf_range(0.015, 0.22),
			"size": rng.randf_range(0.25, 0.43), "angle": rng.randf_range(-0.45, 0.45)
		})

func show_at(age: float) -> void:
	_foam.set_shader_parameter("age", age)
	for layer in _spray:
		var plume: MeshInstance3D = layer.node
		var time: float = age - layer.delay
		plume.visible = time > 0.0
		if not plume.visible:
			continue
		var velocity: Vector3 = layer.velocity
		var spread := 1.0 - exp(-time * 1.6)
		var rise := maxf(0.0, velocity.y * time * exp(-time * 1.08) - time * time * 0.048)
		var radius: float = _height * layer.size * (0.20 + spread * 0.80)
		plume.position = _height * Vector3(velocity.x * spread, rise, velocity.z * spread)
		plume.scale = Vector3(radius, radius * (1.83 if layer.column else 0.64), radius)
		var material := plume.material_override as ShaderMaterial
		material.set_shader_parameter("age", time)
		material.set_shader_parameter("rotation", layer.angle + time * 0.18)

func _mesh(geometry: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
