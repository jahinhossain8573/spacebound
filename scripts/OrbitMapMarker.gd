extends MeshInstance3D

const HEIGHT_PX := 14.0

var _angle := 0.0

func _init(color: Color) -> void:
	var triangle := ImmediateMesh.new()
	triangle.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	triangle.surface_add_vertex(Vector3(0.0, 0.5, 0.0))
	triangle.surface_add_vertex(Vector3(0.32, -0.5, 0.0))
	triangle.surface_add_vertex(Vector3(-0.32, -0.5, 0.0))
	triangle.surface_end()
	mesh = triangle

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func aim(camera: Camera3D, direction: Vector3, view_height: float) -> void:
	var point := camera.to_local(global_position)
	var depth := -point.z
	if depth <= 0.0:
		return
	var camera_direction := camera.global_basis.inverse() * direction.normalized()
	# Include perspective so the tip follows the path even when the craft is off center.
	var projected := Vector2(camera_direction.x, camera_direction.y)
	projected += Vector2(point.x, point.y) * (camera_direction.z / depth)
	if not projected.is_zero_approx():
		_angle = projected.angle() - PI * 0.5
	var height := HEIGHT_PX * 2.0 * depth * tan(deg_to_rad(camera.fov * 0.5)) / maxf(1.0, view_height)
	global_basis = camera.global_basis * Basis(Vector3.BACK, _angle).scaled(Vector3.ONE * height)
