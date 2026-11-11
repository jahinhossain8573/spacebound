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
	var navball = flight._flight_hud.navball
	flight._craft_visual.rotation.y = -PI * 0.5
	flight._update_position()
	check(navball.direction_offset(navball.prograde_pitch_rad, 66.0).is_zero_approx(), "prograde centers when the nose points along orbital velocity")
	flight._craft_visual.rotation.y = 0.0
	flight._update_position()
	var prograde_offset: Vector2 = navball.direction_offset(navball.prograde_pitch_rad, 66.0)
	check(prograde_offset.x == 0.0 and prograde_offset.y > 0.0, "prograde appears below a nose pointing radially outward")
	navball.pitch_rad = deg_to_rad(179.0)
	var wrapped_offset: Vector2 = navball.direction_offset(deg_to_rad(-179.0), 66.0)
	check(wrapped_offset.x == 0.0 and is_equal_approx(wrapped_offset.y, -66.0 * sin(deg_to_rad(2.0))), "navball uses the shortest signed turn across the angle boundary")
	navball.pitch_rad = deg_to_rad(30.0)
	check(is_equal_approx(navball.direction_offset(0.0, 66.0).y, navball.horizon_offset(0.0, 66.0)), "horizontal velocity sits on the projected horizon")
	navball.pitch_rad = deg_to_rad(150.0)
	check(is_equal_approx(navball.direction_offset(PI, 66.0).y, navball.horizon_offset(0.0, 66.0)), "the inverted horizon uses the forward-facing tangent")
	check(navball.direction_offset(0.0, 66.0).y == 66.0, "a direction behind the nose stays off scale")
	flight._yaw = 1.1
	flight._distance = 0.25
	flight.toggle_map_view()
	check(flight._map_view and flight._camera_mode == "Earth", "map view toggle")
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	drag.relative = Vector2(80, 40)
	var center: Vector2 = flight._camera.unproject_position(Vector3.ZERO)
	flight._view_input(drag)
	var after_pan: Vector2 = flight._camera.unproject_position(Vector3.ZERO)
	check(after_pan.distance_to(center + drag.relative) < 1.0, "middle-drag pans the orbital map in screen space")
	flight.toggle_map_view()
	check(not flight._map_view and is_equal_approx(flight._yaw, 1.1) and is_equal_approx(flight._distance, 0.25), "flight camera restored")
	flight._view_input(drag)
	flight.toggle_map_view()
	check(flight._camera.unproject_position(Vector3.ZERO).distance_to(after_pan) < 1.0, "map pan persists and middle-drag has no effect in flight view")
	flight._reset_view()
	check(flight._map_pan == Vector3.ZERO, "reset camera recenters the orbital map")
	flight.toggle_map_view()
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
