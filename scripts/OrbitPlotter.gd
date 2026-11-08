extends MeshInstance3D

const SEGMENTS := 120
var vertices: PackedVector3Array = []

func redraw(orbit: OrbitState) -> void:
	vertices.clear()
	var line := ImmediateMesh.new()
	mesh = line
	if orbit == null or not orbit.is_valid(): return
	var a := orbit.semi_major_axis_km
	var b := a * sqrt(1.0 - orbit.eccentricity * orbit.eccentricity)
	var c := a * orbit.eccentricity
	var angle := orbit.arg_periapsis_rad
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in SEGMENTS + 1:
		var theta := TAU * float(i) / SEGMENTS
		var x := a * cos(theta) - c
		var y := b * sin(theta)
		var point := Vector3(x * cos(angle) - y * sin(angle), 0.0, x * sin(angle) + y * cos(angle)) * OrbitState.PHYSICS.RENDER_SCALE
		vertices.append(point)
		line.surface_set_color(Color("00e5ff"))
		line.surface_add_vertex(point)
	line.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = material
