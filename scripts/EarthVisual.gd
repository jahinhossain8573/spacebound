extends Node3D

const MODEL := preload("res://assets/3d-models/earth/earth.glb")
const GROUND_SHADER := preload("res://assets/3d-models/launch_area/kennedy_ground.gdshader")
const ATMOSPHERE_SHADER := preload("res://assets/3d-models/earth/earth_atmosphere.gdshader")
const GROUND_TEXTURE := preload("res://assets/3d-models/launch_area/kennedy_ground.png")
const PAD_TEXTURE := preload("res://assets/3d-models/launch_area/kennedy_pad_detail.png")
const FLORIDA_TEXTURE := preload("res://assets/3d-models/earth/florida_coast.jpg")
const EARTH_TEXTURE := preload("res://assets/3d-models/earth/earth_spacebound-blue-marble-graded.png")
# The masks use the same UVs as the color maps, with the Florida crop supplying finer coastline detail.
const EARTH_WATER := preload("res://assets/3d-models/earth/earth_water_mask.png")
const FLORIDA_WATER := preload("res://assets/3d-models/earth/florida_water_mask.png")
const GROUND_HEIGHT_M := -8.2
const GROUND_RADIUS_M := preload("res://scripts/AscentSim.gd").R_EARTH + GROUND_HEIGHT_M
const KENNEDY_LATITUDE := deg_to_rad(28.6084)
const KENNEDY_LONGITUDE := deg_to_rad(-80.6043)
# The closest point on any triangle in the imported globe is at radius 0.999607.
const OCCLUDER_RADIUS := 0.9996
const OUTER_RADIUS := 1.0
const EARTH_RADIUS_KM := 6371.0

var sun: DirectionalLight3D
var _globe: Node3D
var _surface: ShaderMaterial
var _atmosphere: MeshInstance3D
var _atmosphere_material: ShaderMaterial
var _patches: Array[MeshInstance3D] = []
var _bounds: Array[AABB] = []

func _ready() -> void:
	_globe = MODEL.instantiate() as Node3D
	add_child(_globe)
	_surface = make_surface(false)
	for node in _globe.find_children("*", "MeshInstance3D", true, false):
		var patch := node as MeshInstance3D
		patch.material_override = _surface
		_patches.append(patch)
		# The GLB patch vertices share the globe's origin and coordinate system.
		_bounds.append(patch.get_aabb())
	_atmosphere_material = ShaderMaterial.new()
	_atmosphere_material.shader = ATMOSPHERE_SHADER
	_atmosphere_material.render_priority = Material.RENDER_PRIORITY_MIN
	_atmosphere_material.set_shader_parameter("earth_radius_km", EARTH_RADIUS_KM)
	_atmosphere = MeshInstance3D.new()
	_atmosphere.name = "EarthAtmosphere"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_atmosphere.mesh = quad
	_atmosphere.material_override = _atmosphere_material
	_atmosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_atmosphere.hide()
	add_child(_atmosphere)

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

func set_ocean_detail(detail: float) -> void:
	_surface.set_shader_parameter("ocean_detail", detail)

func is_water_at(world_position: Vector3) -> bool:
	var radial := to_local(world_position).normalized()
	var longitude := atan2(-radial.z, radial.x)
	var latitude := asin(clampf(radial.y, -1.0, 1.0))
	var florida_uv := (Vector2(rad_to_deg(longitude), rad_to_deg(latitude)) - Vector2(-83.5, 31.5)) / Vector2(6.0, -5.5)
	var mask := EARTH_WATER
	var uv := Vector2(fposmod(longitude / TAU + 0.5, 1.0), 0.5 - latitude / PI)
	if Rect2(0.0, 0.0, 1.0, 1.0).has_point(florida_uv):
		mask = FLORIDA_WATER
		uv = florida_uv
	var image := mask.get_image()
	var pixel := Vector2i(uv * Vector2(image.get_size())).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixelv(pixel).r >= 0.5

func make_impact_surface(frame: Basis) -> MeshInstance3D:
	# The globe's large triangles can intersect a camera at sea level.
	# Use the same geographic textures on a finer local surface during the impact.
	var plane := PlaneMesh.new()
	plane.size = Vector2(150000.0, 150000.0)
	plane.subdivide_width = 110
	plane.subdivide_depth = 110
	var material := make_surface(false)
	material.set_shader_parameter("impact_surface", true)
	material.set_shader_parameter("impact_to_globe", global_basis.orthonormalized().inverse() * frame)
	var surface := MeshInstance3D.new()
	surface.mesh = plane
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return surface

func show_globe(show: bool) -> void:
	_globe.visible = show

static func kennedy_basis() -> Basis:
	var east := Vector3(-sin(KENNEDY_LONGITUDE), 0.0, -cos(KENNEDY_LONGITUDE))
	var up := Vector3(cos(KENNEDY_LATITUDE) * cos(KENNEDY_LONGITUDE), sin(KENNEDY_LATITUDE),
		-cos(KENNEDY_LATITUDE) * sin(KENNEDY_LONGITUDE))
	return Basis(east, up, east.cross(up)).transposed()

func visible_distance_from(camera_position: Vector3) -> float:
	var radius := global_basis.x.length()
	var inner_radius_squared := pow(radius * OCCLUDER_RADIUS, 2.0)
	var camera_distance_squared := camera_position.distance_squared_to(global_position)
	# A ray grazing the inner sphere can reach the far side of the outer shell.
	var distance_to_tangent := sqrt(maxf(0.0, camera_distance_squared - inner_radius_squared))
	var distance_through_shell := sqrt(maxf(0.0, radius * radius - inner_radius_squared))
	return (distance_to_tangent + distance_through_shell) * 1.01

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
	_update_atmosphere(camera)

func _update_atmosphere(camera: Camera3D) -> void:
	_atmosphere.visible = is_instance_valid(sun) and camera.projection == Camera3D.PROJECTION_PERSPECTIVE
	if not _atmosphere.visible:
		return
	if _atmosphere.get_parent() != camera:
		_atmosphere.reparent(camera, false)
	_atmosphere.position.z = -camera.near * 2.0
	var km_per_unit := EARTH_RADIUS_KM / global_basis.x.length()
	var view_basis := camera.global_basis.inverse()
	_atmosphere_material.set_shader_parameter("km_per_unit", km_per_unit)
	_atmosphere_material.set_shader_parameter("observer_km", view_basis * ((camera.global_position - global_position) * km_per_unit))
	_atmosphere_material.set_shader_parameter("sun_direction", view_basis * sun.global_basis.z.normalized())
