extends Node3D

const MODEL := preload("res://assets/3d-models/earth/earth.glb")
const KENNEDY_LATITUDE := deg_to_rad(28.6084)
const KENNEDY_LONGITUDE := deg_to_rad(-80.6043)
# The closest point on any triangle in the imported globe is at radius 0.999606.
const OCCLUDER_RADIUS := 0.9996
const OUTER_RADIUS := 1.0

var _patches: Array[MeshInstance3D] = []
var _bounds: Array[AABB] = []

func _ready() -> void:
	var globe := MODEL.instantiate() as Node3D
	add_child(globe)
	for node in globe.find_children("*", "MeshInstance3D", true, false):
		var patch := node as MeshInstance3D
		_patches.append(patch)
		# The GLB patch vertices share the globe's origin and coordinate system.
		_bounds.append(patch.get_aabb())

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
