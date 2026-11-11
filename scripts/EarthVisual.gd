extends Node3D

const MODEL := preload("res://assets/3d-models/earth/earth.glb")
const GROUND_SHADER := preload("res://assets/3d-models/launch_area/kennedy_ground.gdshader")
const GROUND_TEXTURE := preload("res://assets/3d-models/launch_area/kennedy_ground.png")
const PAD_TEXTURE := preload("res://assets/3d-models/launch_area/kennedy_pad_detail.png")
const FLORIDA_TEXTURE := preload("res://assets/3d-models/earth/florida_coast.jpg")
const EARTH_TEXTURE := preload("res://assets/3d-models/earth/earth_spacebound-blue-marble-graded.png")
const GROUND_HEIGHT_M := -8.2
const GROUND_RADIUS_M := preload("res://scripts/AscentSim.gd").R_EARTH + GROUND_HEIGHT_M
const KENNEDY_LATITUDE := deg_to_rad(28.6084)
const KENNEDY_LONGITUDE := deg_to_rad(-80.6043)
# The closest point on any triangle in the imported globe is at radius 0.999607.
const OCCLUDER_RADIUS := 0.9996
const OUTER_RADIUS := 1.0

var _surface: ShaderMaterial
var _patches: Array[MeshInstance3D] = []
var _bounds: Array[AABB] = []

func _ready() -> void:
	var globe := MODEL.instantiate() as Node3D
	add_child(globe)
	_surface = make_surface(false)
	for node in globe.find_children("*", "MeshInstance3D", true, false):
		var patch := node as MeshInstance3D
		patch.material_override = _surface
		_patches.append(patch)
		# The GLB patch vertices share the globe's origin and coordinate system.
		_bounds.append(patch.get_aabb())

static func make_surface(launch_plane: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("local_ground", GROUND_TEXTURE)
	material.set_shader_parameter("pad_ground", PAD_TEXTURE)
	material.set_shader_parameter("florida_surface", FLORIDA_TEXTURE)
	material.set_shader_parameter("globe_surface", EARTH_TEXTURE)
	material.set_shader_parameter("globe_to_kennedy", kennedy_basis())
	material.set_shader_parameter("ground_radius", GROUND_RADIUS_M)
	material.set_shader_parameter("launch_plane", launch_plane)
	return material

func set_local_detail(detail: float) -> void:
	_surface.set_shader_parameter("local_detail", detail)

static func kennedy_basis() -> Basis:
	var east := Vector3(-sin(KENNEDY_LONGITUDE), 0.0, -cos(KENNEDY_LONGITUDE))
	var up := Vector3(cos(KENNEDY_LATITUDE) * cos(KENNEDY_LONGITUDE), sin(KENNEDY_LATITUDE),
		-cos(KENNEDY_LATITUDE) * sin(KENNEDY_LONGITUDE))
	return Basis(east, up, east.cross(up)).transposed()

func update_horizon(camera: Camera3D) -> void:
	var inverse_basis := global_basis.inverse()
	var to_camera := inverse_basis * (camera.global_position - global_position)
	var distance := to_camera.length()
	var orthogonal := camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var can_cull := orthogonal or distance > OCCLUDER_RADIUS
	var direction := (inverse_basis * camera.global_basis.z).normalized() if orthogonal else to_camera.normalized()
	var cutoff := 0.0
	if can_cull:
		# The far intersection of the tangent ray and the outer sphere allows for
		# raised land and mesh curvature outside the occluding sphere.
		var tangent := 0.0 if orthogonal else OCCLUDER_RADIUS / distance
		cutoff = OCCLUDER_RADIUS * tangent - sqrt((1.0 - tangent * tangent) *
			(OUTER_RADIUS * OUTER_RADIUS - OCCLUDER_RADIUS * OCCLUDER_RADIUS))
	for i in _patches.size():
		var bounds := _bounds[i]
		var support := direction.dot(bounds.get_center()) + direction.abs().dot(bounds.size * 0.5)
		_patches[i].visible = not can_cull or support >= cutoff
