extends RefCounted

## Procedural 3D Vehicle Assembly Building (VAB) / Spacecraft Cleanroom Warehouse for Workshop.gd.
## Uses standard primitives & ImmediateMesh compatible with gl_compatibility Web exports.

const MODEL_LIBRARY = preload("res://scripts/ModelLibrary.gd")

const FLOOR_Y := -2.35
const HALF_W := 15.5
const BACK_Z := -16.5
const FRONT_Z := 15.5
const ROOF_Y := 13.8

static func mat(albedo: Color, roughness := 0.8, metallic := 0.0, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	if emissive:
		m.emission_enabled = true
		m.emission = albedo
		m.emission_energy_multiplier = 1.25
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func populate_warehouse(world: Node3D, launcher_id: String) -> void:
	var hangar := Node3D.new()
	hangar.name = "WarehouseHangar"
	world.add_child(hangar)

	var concrete_mat := mat(Color("73767b"), 0.88)
	var concrete_dark := mat(Color("575b61"), 0.9)
	var line_white := mat(Color("dcdfe3"), 0.75)
	var line_yellow := mat(Color("cfa336"), 0.75)
	var wall_panel_mat := mat(Color("7c828a"), 0.78, 0.12)
	var wall_lower_mat := mat(Color("5d636c"), 0.82, 0.15)
	var beam_mat := mat(Color("3c424b"), 0.62, 0.45)
	var truss_mat := mat(Color("2e333b"), 0.65, 0.5)
	var skylight_mat := mat(Color("eef5ff"), 0.2, 0.0, true)
	var door_green_mat := mat(Color("22382c"), 0.78, 0.15)
	var tank_white_mat := mat(Color("cfd6dc"), 0.55, 0.15)
	var tank_band_mat := mat(Color("6f9c7a"), 0.65, 0.1)
	var crate_red_mat := mat(Color("6e2b2b"), 0.82)
	var crate_grey_mat := mat(Color("454c56"), 0.8)

	# Warm industrial key light + cool skylight bounce fill
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-62, 145, 0)
	fill_light.light_color = Color("cfe0f5")
	fill_light.light_energy = 0.55
	hangar.add_child(fill_light)

	var spot := OmniLight3D.new()
	spot.position = Vector3(0.0, 7.5, 1.5)
	spot.omni_range = 26.0
	spot.light_color = Color("fff3de")
	spot.light_energy = 0.95
	hangar.add_child(spot)

	# Concrete hangar floor
	_box(hangar, Vector3(HALF_W * 2.0, 0.3, FRONT_Z - BACK_Z), Vector3(0.0, FLOOR_Y - 0.15, (FRONT_Z + BACK_Z) * 0.5), concrete_mat)

	# Subtle floor expansion-joint grid + white painted circular VAB assembly ring
	var markings := ImmediateMesh.new()
	markings.surface_begin(Mesh.PRIMITIVE_LINES)
	for gx in range(-14, 15, 4):
		markings.surface_add_vertex(Vector3(gx, FLOOR_Y + 0.008, BACK_Z + 0.5))
		markings.surface_add_vertex(Vector3(gx, FLOOR_Y + 0.008, FRONT_Z - 0.5))
	for gz in range(-16, 16, 4):
		markings.surface_add_vertex(Vector3(-HALF_W + 0.5, FLOOR_Y + 0.008, gz))
		markings.surface_add_vertex(Vector3(HALF_W - 0.5, FLOOR_Y + 0.008, gz))
	markings.surface_end()
	var grid_inst := MeshInstance3D.new()
	grid_inst.mesh = markings
	grid_inst.material_override = concrete_dark
	hangar.add_child(grid_inst)

	# Painted white circular safety zone ring on floor (signature KSP VAB floor circle!)
	_add_floor_ring(hangar, 4.8, 0.14, FLOOR_Y + 0.012, line_white)
	_add_floor_ring(hangar, 1.85, 0.08, FLOOR_Y + 0.012, line_yellow)
	# Center white safety T-mark & right-side haul lane lines
	_box(hangar, Vector3(1.9, 0.012, 0.12), Vector3(0.0, FLOOR_Y + 0.012, -2.5), line_white)
	_box(hangar, Vector3(0.14, 0.012, 24.0), Vector3(8.8, FLOOR_Y + 0.012, -1.0), line_white)
	_box(hangar, Vector3(0.12, 0.012, 24.0), Vector3(9.4, FLOOR_Y + 0.012, -1.0), line_yellow)

	# Central Spacecraft Cleanroom Integration Pedestal beneath _craft (stops at y = -1.12 so craft is unobstructed)
	var base_pad := MeshInstance3D.new()
	var bp_cyl := CylinderMesh.new()
	bp_cyl.top_radius = 1.45
	bp_cyl.bottom_radius = 1.65
	bp_cyl.height = 0.16
	bp_cyl.radial_segments = 24
	base_pad.mesh = bp_cyl
	base_pad.position = Vector3(0.0, FLOOR_Y + 0.08, 0.0)
	base_pad.material_override = beam_mat
	hangar.add_child(base_pad)

	var collar := MeshInstance3D.new()
	var col_cyl := CylinderMesh.new()
	col_cyl.top_radius = 0.62
	col_cyl.bottom_radius = 0.72
	col_cyl.height = 0.12
	col_cyl.radial_segments = 20
	collar.mesh = col_cyl
	collar.position = Vector3(0.0, -1.22, 0.0)
	collar.material_override = mat(Color("8a95a3"), 0.45, 0.6)
	hangar.add_child(collar)

	for i in 4:
		var ang := PI * 0.25 + i * PI * 0.5
		var leg := _box(hangar, Vector3(0.10, 1.18, 0.10), Vector3(cos(ang) * 0.92, -1.78, sin(ang) * 0.92), beam_mat)
		leg.rotation.z = cos(ang) * 0.34
		leg.rotation.x = -sin(ang) * 0.34

	# Four Industrial Hangar Walls + H-Columns + X-Bracing + Skylights
	_build_wall(hangar, Vector3(0.0, 0.0, BACK_Z), 0.0, HALF_W * 2.0, 5, wall_panel_mat, wall_lower_mat, beam_mat, skylight_mat, false)
	_build_wall(hangar, Vector3(0.0, 0.0, FRONT_Z), PI, HALF_W * 2.0, 5, wall_panel_mat, wall_lower_mat, beam_mat, skylight_mat, false)
	_build_wall(hangar, Vector3(-HALF_W, 0.0, -0.5), PI * 0.5, FRONT_Z - BACK_Z, 5, wall_panel_mat, wall_lower_mat, beam_mat, skylight_mat, false)
	_build_wall(hangar, Vector3(HALF_W, 0.0, -0.5), -PI * 0.5, FRONT_Z - BACK_Z, 5, wall_panel_mat, wall_lower_mat, beam_mat, skylight_mat, true)

	# Roof & Overhead Steel Trusses
	_box(hangar, Vector3(HALF_W * 2.0 + 1.0, 0.4, FRONT_Z - BACK_Z + 1.0), Vector3(0.0, ROOF_Y + 0.2, -0.5), truss_mat)
	for tz in range(-14, 15, 5):
		_box(hangar, Vector3(HALF_W * 2.0, 0.45, 0.28), Vector3(0.0, ROOF_Y - 0.35, tz), truss_mat)
		_box(hangar, Vector3(HALF_W * 2.0, 0.22, 0.22), Vector3(0.0, ROOF_Y - 1.15, tz), truss_mat)

	# Twin White/Green Cylindrical Storage Silos in back corners (matches Photo 3!)
	for tx: float in [-11.2, 11.4]:
		_add_silo_tank(hangar, Vector3(tx, FLOOR_Y, BACK_Z + 2.2), tank_white_mat, tank_band_mat)

	# Overhead twin ventilation pipes dropping down the back wall into utility room
	for px: float in [0.9, 1.55]:
		var vpipe := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.22
		pm.bottom_radius = 0.22
		pm.height = 11.5
		vpipe.mesh = pm
		vpipe.position = Vector3(px, FLOOR_Y + 7.2, BACK_Z + 0.55)
		vpipe.material_override = wall_panel_mat
		hangar.add_child(vpipe)
	# Utility room box on back-right floor
	_box(hangar, Vector3(4.2, 3.6, 3.4), Vector3(4.8, FLOOR_Y + 1.8, BACK_Z + 1.8), beam_mat)

	# Lattice Scaffolding Towers (right-back & center-back, like Photo 3!)
	_add_scaffolding(hangar, Vector3(8.6, FLOOR_Y, -9.2), Vector3(2.8, 10.8, 2.8), truss_mat)
	_add_scaffolding(hangar, Vector3(2.0, FLOOR_Y, -13.6), Vector3(2.0, 7.2, 2.0), truss_mat)

	# Warehouse crates, pallets & slanted ladders
	for crate_cfg in [
		[Vector3(-6.2, FLOOR_Y + 0.45, BACK_Z + 1.4), Vector3(1.5, 0.9, 1.2), crate_red_mat],
		[Vector3(-4.3, FLOOR_Y + 0.35, BACK_Z + 1.6), Vector3(1.2, 0.7, 1.0), crate_grey_mat],
		[Vector3(-1.2, FLOOR_Y + 0.4, BACK_Z + 1.3), Vector3(1.6, 0.8, 1.1), crate_red_mat],
		[Vector3(-12.5, FLOOR_Y + 0.4, -7.2), Vector3(1.4, 0.8, 1.4), crate_grey_mat],
		[Vector3(-11.8, FLOOR_Y + 0.35, -5.4), Vector3(1.1, 0.7, 1.1), crate_grey_mat]
	]:
		_box(hangar, crate_cfg[1], crate_cfg[0], crate_cfg[2])

	# Assigned Launcher Rocket parked on vertical integration stand in back-left bay
	_add_launcher_backdrop(hangar, launcher_id, Vector3(-8.2, FLOOR_Y, -11.4), beam_mat)

	# Tiny Kerbal-style Engineers / Ground Crew standing around the floor ring for scale!
	var crew_spots := [
		[Vector3(-3.3, FLOOR_Y, -1.6), 0.5, Color("d9e64e")],
		[Vector3(-2.1, FLOOR_Y, -2.5), 0.9, Color("e6ece8")],
		[Vector3(-2.4, FLOOR_Y, -1.1), 0.2, Color("d9e64e")],
		[Vector3(3.4, FLOOR_Y, -2.1), -0.8, Color("e6ece8")],
		[Vector3(0.4, FLOOR_Y, 3.6), 3.0, Color("e6ece8")]
	]
	for cs in crew_spots:
		_add_crew_figure(hangar, cs[0], float(cs[1]), cs[2])

static func _build_wall(parent: Node3D, origin: Vector3, rot_y: float, length: float, bays: int, panel_mat: Material, lower_mat: Material, beam_mat: Material, sky_mat: Material, has_big_door: bool) -> void:
	var wall := Node3D.new()
	wall.position = origin
	wall.rotation.y = rot_y
	parent.add_child(wall)

	var total_h := ROOF_Y - FLOOR_Y
	var lower_h := 3.4
	var mid_h := total_h - lower_h - 3.2
	# Lower dado wall & main corrugated wall
	_box(wall, Vector3(length, lower_h, 0.35), Vector3(0.0, FLOOR_Y + lower_h * 0.5, 0.0), lower_mat)
	_box(wall, Vector3(length, mid_h, 0.3), Vector3(0.0, FLOOR_Y + lower_h + mid_h * 0.5, 0.0), panel_mat)
	# Upper clerestory skylight band
	_box(wall, Vector3(length, 3.2, 0.32), Vector3(0.0, ROOF_Y - 1.6, 0.0), beam_mat)

	if has_big_door:
		# Tall green VAB vehicle rollout door
		_box(wall, Vector3(length * 0.42, total_h * 0.76, 0.48), Vector3(length * 0.16, FLOOR_Y + total_h * 0.38, 0.08), mat(Color("1e382b"), 0.8))

	var bay_w := length / float(bays)
	for i in (bays + 1):
		var bx := -length * 0.5 + i * bay_w
		_box(wall, Vector3(0.42, total_h, 0.65), Vector3(bx, FLOOR_Y + total_h * 0.5, 0.18), beam_mat)

	# Horizontal girts + X-bracing + glowing skylight panes per bay
	_box(wall, Vector3(length, 0.34, 0.52), Vector3(0.0, FLOOR_Y + lower_h, 0.16), beam_mat)
	_box(wall, Vector3(length, 0.34, 0.52), Vector3(0.0, ROOF_Y - 3.2, 0.16), beam_mat)

	for i in bays:
		var cx := -length * 0.5 + (i + 0.5) * bay_w
		# Skylight pane
		_box(wall, Vector3(bay_w - 0.7, 2.2, 0.12), Vector3(cx, ROOF_Y - 1.6, 0.16), sky_mat)
		if has_big_door and i >= 2:
			continue
		# Diagonal X-brace in middle tier
		var diag_len := sqrt(bay_w * bay_w + mid_h * mid_h) * 0.94
		var ang := atan2(mid_h, bay_w)
		for s: float in [-1.0, 1.0]:
			var brace := _box(wall, Vector3(diag_len, 0.18, 0.18), Vector3(cx, FLOOR_Y + lower_h + mid_h * 0.5, 0.22), beam_mat)
			brace.rotation.z = s * ang

static func _add_floor_ring(parent: Node3D, radius: float, width: float, y: float, material: Material) -> void:
	var ring := ImmediateMesh.new()
	ring.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var segs := 64
	var r_in := radius - width * 0.5
	var r_out := radius + width * 0.5
	for i in (segs + 1):
		var a := TAU * float(i) / segs
		ring.surface_set_normal(Vector3.UP)
		ring.surface_add_vertex(Vector3(cos(a) * r_in, y, sin(a) * r_in))
		ring.surface_set_normal(Vector3.UP)
		ring.surface_add_vertex(Vector3(cos(a) * r_out, y, sin(a) * r_out))
	ring.surface_end()
	var inst := MeshInstance3D.new()
	inst.mesh = ring
	inst.material_override = material
	parent.add_child(inst)

static func _add_silo_tank(parent: Node3D, base_pos: Vector3, body_mat: Material, band_mat: Material) -> void:
	var h := 6.4
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.45
	cm.bottom_radius = 1.45
	cm.height = h
	cm.radial_segments = 20
	cyl.mesh = cm
	cyl.position = base_pos + Vector3(0.0, h * 0.5, 0.0)
	cyl.material_override = body_mat
	parent.add_child(cyl)
	for by: float in [1.4, 3.2, 5.0]:
		var band := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 1.48
		bm.bottom_radius = 1.48
		bm.height = 0.28
		bm.radial_segments = 20
		band.mesh = bm
		band.position = base_pos + Vector3(0.0, by, 0.0)
		band.material_override = band_mat
		parent.add_child(band)

static func _add_scaffolding(parent: Node3D, base_pos: Vector3, dims: Vector3, frame_mat: Material) -> void:
	var scaf := Node3D.new()
	scaf.position = base_pos
	parent.add_child(scaf)
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			_box(scaf, Vector3(0.10, dims.y, 0.10), Vector3(sx * dims.x, dims.y * 0.5, sz * dims.z), frame_mat)
	var levels := int(maxf(2.0, floor(dims.y / 2.2)))
	for lvl in range(1, levels + 1):
		var ly := float(lvl) * (dims.y / levels)
		_box(scaf, Vector3(dims.x, 0.07, dims.z), Vector3(0.0, ly, 0.0), frame_mat)

static func _add_launcher_backdrop(parent: Node3D, launcher_id: String, base_pos: Vector3, gantry_mat: Material) -> void:
	var stand := Node3D.new()
	stand.position = base_pos
	parent.add_child(stand)
	_box(stand, Vector3(2.6, 0.25, 2.6), Vector3(0.0, 0.125, 0.0), gantry_mat)
	var target_h := 11.2
	var model := MODEL_LIBRARY.instantiate("launchers", launcher_id)
	if model:
		var raw_h: float = {"launcher_electron": 18.0, "launcher_vega_c": 35.0, "launcher_falcon_9": 70.0}.get(launcher_id, 18.0)
		var s := target_h / raw_h
		model.scale = Vector3.ONE * s
		model.position = Vector3(0.0, 0.25, 0.0)
		stand.add_child(model)
	else:
		var body := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.42
		cm.bottom_radius = 0.45
		cm.height = target_h * 0.82
		body.mesh = cm
		body.position = Vector3(0.0, 0.25 + target_h * 0.41, 0.0)
		body.material_override = mat(Color("dce2e8"), 0.55)
		stand.add_child(body)
		var nose := MeshInstance3D.new()
		var nm := CylinderMesh.new()
		nm.top_radius = 0.04
		nm.bottom_radius = 0.46
		nm.height = target_h * 0.18
		nose.mesh = nm
		nose.position = Vector3(0.0, 0.25 + target_h * 0.91, 0.0)
		nose.material_override = mat(Color("e6ecf2"), 0.5)
		stand.add_child(nose)

static func _add_crew_figure(parent: Node3D, pos: Vector3, yaw: float, coat_color: Color) -> void:
	var fig := Node3D.new()
	fig.position = pos
	fig.rotation.y = yaw
	parent.add_child(fig)
	_box(fig, Vector3(0.18, 0.28, 0.12), Vector3(0.0, 0.22, 0.0), mat(coat_color, 0.8))
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	head.mesh = sm
	head.position = Vector3(0.0, 0.46, 0.0)
	head.material_override = mat(Color("8ec94f"), 0.7)
	fig.add_child(head)
	var hat := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.10
	hm.height = 0.11
	hat.mesh = hm
	hat.position = Vector3(0.0, 0.52, 0.0)
	hat.material_override = mat(Color("f2c938"), 0.45)
	fig.add_child(hat)

static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node
