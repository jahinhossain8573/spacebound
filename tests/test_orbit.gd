extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func run_tests() -> void:
	var manager := root.get_node("GameManager")
	var sim := root.get_node("FlightSim")
	var source := OrbitState.new()
	manager.initial_orbit = source
	var scene: PackedScene = load("res://scenes/FlightView.tscn")
	var flight = scene.instantiate()
	root.add_child(flight)
	flight.set_process(false)
	check(flight.orbit != source and flight.orbit.semi_major_axis_km == 6771.0, "handoff copied")
	check(flight._plotter.vertices.size() == 121 and flight._plotter.vertices[0].distance_to(flight._plotter.vertices[120]) < 0.001, "closed orbit line")
	check(flight._plotter.material_override.vertex_color_use_as_albedo and flight._plotter.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "orbit material")
	check(not flight._map_view and flight._camera_mode == "Spacecraft", "flight starts focused on spacecraft")
	flight._yaw = 1.1
	flight._distance = 0.25
	flight.toggle_map_view()
	check(flight._map_view and flight._camera_mode == "Earth", "map view toggle")
	flight.toggle_map_view()
	check(not flight._map_view and is_equal_approx(flight._yaw, 1.1) and is_equal_approx(flight._distance, 0.25), "flight camera restored")
	var period: float = sim.orbital_period_s(6771.0)
	flight.set_warp(1000)
	flight.advance_time(period / 1000.0)
	check(flight.position_km.distance_to(Vector2(6771,0)) < 0.01 and absf(flight.mission_elapsed_s - period) < 0.001, "one LEO orbit at 1000x")
	check(source.time_since_periapsis_s == 0, "source unchanged")
	var position: Vector2 = flight.position_km
	flight.set_warp(10)
	check(position == flight.position_km, "warp switch continuity")
	flight.advance_time(2)
	check(absf(flight.mission_elapsed_s - period - 20) < 0.001, "elapsed time unwrapped")
	check(flight.is_in_eclipse(Vector2(-6771,0)) and not flight.is_in_eclipse(Vector2(6771,0)), "shadow orientation")
	check(not flight.is_in_eclipse(Vector2(-7000,6371)) and flight.is_in_eclipse(Vector2(-7000,6370)), "shadow boundary")
	var shadow_samples := 0
	for i in 3600:
		var p: Vector2 = sim.position_on_orbit_km(6771,0,period * i / 3600.0)
		if flight.is_in_eclipse(p): shadow_samples += 1
	check(absf(period * shadow_samples / 3600.0 / 60.0 - 36.0) < 0.5, "36 minute LEO eclipse")
	var transfer := OrbitState.new()
	transfer.semi_major_axis_km = 24392.5
	transfer.eccentricity = (42164.0-6621.0)/(42164.0+6621.0)
	transfer.arg_periapsis_rad = PI/2
	check(flight.set_orbit(transfer), "GTO accepted")
	check(flight.position_km.distance_to(Vector2(0,6621)) < 0.1, "rotated periapsis")
	var fast: float = flight.speed_kms
	flight.set_warp(1)
	flight.advance_time(sim.orbital_period_s(24392.5)/2.0)
	check(flight.position_km.distance_to(Vector2(0,-42164)) < 0.1 and flight.speed_kms < fast, "rotated apoapsis slower")
	check(absf(flight.mission_elapsed_s - period - 20 - sim.orbital_period_s(24392.5)/2) < 0.1, "redraw retains elapsed")
	transfer.eccentricity = 1
	check(not flight.set_orbit(transfer) and not flight._error.text.is_empty(), "unbound rejected")
	transfer.eccentricity = 0
	transfer.semi_major_axis_km = NAN
	check(not flight.set_orbit(transfer), "NaN rejected")
	flight.queue_free()
	manager.initial_orbit = null
	print("Orbit failures: ", failures)
	quit(1 if failures else 0)
