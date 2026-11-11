extends MeshInstance3D

const SEGMENTS := 120
const PHYSICS = preload("res://scripts/AscentSim.gd")
var vertices: PackedVector3Array = []

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material_override = material

func redraw(orbit: OrbitState) -> void:
	vertices.clear()
	if orbit != null and orbit.is_valid():
		var a := orbit.semi_major_axis_km
		var b := a * sqrt(1.0 - orbit.eccentricity * orbit.eccentricity)
		var c := a * orbit.eccentricity
		for i in SEGMENTS + 1:
			var theta := TAU * float(i) / SEGMENTS
			var p := Vector2(a * cos(theta) - c, b * sin(theta) * orbit.direction).rotated(orbit.arg_periapsis_rad)
			vertices.append(Vector3(p.x, 0.0, p.y) * OrbitState.PHYSICS.RENDER_SCALE)
	_draw_path()

func redraw_coast(coast: Dictionary) -> void:
	if coast.periapsis >= PHYSICS.R_EARTH and coast.energy < 0.0:
		redraw(PHYSICS.orbit_from_coast(coast))
		return

	# Draw the forward arc to impact or the edge of the visible region.
	vertices.clear()
	var eccentricity := float(coast.eccentricity)
	var parameter := float(coast.parameter)
	if eccentricity < 0.000001 or parameter < 0.001:
		_draw_path()
		return
	var start := float(coast.anomaly)
	var end: float
	if coast.periapsis < PHYSICS.R_EARTH:
		end = TAU - acos(clampf((parameter / PHYSICS.R_EARTH - 1.0) / eccentricity, -1.0, 1.0))
		if start < 0.0:
			start += TAU
		if coast.energy >= 0.0 and coast.anomaly >= 0.0:
			end = acos(clampf((parameter / (PHYSICS.R_EARTH * 12.0) - 1.0) / eccentricity, -1.0, 1.0))
	else:
		end = acos(clampf((parameter / (PHYSICS.R_EARTH * 12.0) - 1.0) / eccentricity, -1.0, 1.0))
	for i in SEGMENTS + 1:
		var anomaly := lerpf(start, maxf(start, end), float(i) / SEGMENTS)
		var denominator := 1.0 + eccentricity * cos(anomaly)
		if denominator <= 0.0:
			break
		var radius := parameter / denominator
		var angle := float(coast.arg) + anomaly * float(coast.direction)
		vertices.append(Vector3(cos(angle), 0.0, sin(angle)) * radius * (OrbitState.PHYSICS.RENDER_SCALE / 1000.0))
	_draw_path()

func _draw_path() -> void:
	var line := ImmediateMesh.new()
	if vertices.size() >= 2:
		line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in vertices:
			line.surface_set_color(Color("00e5ff"))
			line.surface_add_vertex(point)
		line.surface_end()
	mesh = line
