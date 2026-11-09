extends SceneTree
var failures := 0
var signals := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func run_tests() -> void:
	root.get_node("EventManager").random_enabled = false
	var gm := root.get_node("GameManager")
	var sim := root.get_node("FlightSim")
	var data := root.get_node("GlobalData")
	gm.current_mission = data.get_mission(4)
	gm.current_build = {"launcher":data.get_launcher("launcher_falcon_9"), "bus":data.get_bus("bus_heavy_geo_lunar"), "installed_components":[data.get_part("prop_aerojet_r4d15"),data.get_part("pwr_airbus_l"),data.get_part("pwr_eaglepicher_l")], "propellant_mass_kg":500.0}
	gm.attempt_id = "burn-test"
	gm.last_result = {"flight_log":[]}
	gm.burn_executed.connect(func(_dv): signals += 1)
	var flight = load("res://scenes/FlightView.tscn").instantiate()
	root.add_child(flight)
	flight.set_process(false)
	var panel = flight._burn_panel
	var period: float = sim.orbital_period_s(flight.orbit.semi_major_axis_km)
	flight.wait_for_apsis(true)
	flight.advance_time(period)
	check(absf(flight.orbit.time_since_periapsis_s - period/2) < 0.01 and flight.warp == 1, "wait stops exactly at apoapsis")
	var previous: Vector2 = flight.position_km
	var initial_fuel: float = panel.fuel_kg
	check(panel.execute_burn(1470.0, false), "GTO prograde burn")
	check(flight.orbit.eccentricity < 0.01 and absf(flight.orbit.semi_major_axis_km - 42164.0) < 421.64, "GTO to GEO")
	check(previous.distance_to(flight.position_km) < 0.1, "position continuous")
	check(panel.fuel_kg < initial_fuel and signals == 1 and gm.last_result.flight_log.size() == 1, "fuel, signal and flight log")
	check(not panel.execute_burn(panel.remaining_dv()+1.0, false) and signals == 1, "over-budget burn rejected")
	var o := OrbitState.new()
	o.semi_major_axis_km = 12000
	o.eccentricity = 0.25
	o.arg_periapsis_rad = 0.7
	o.time_since_periapsis_s = sim.orbital_period_s(12000)*0.19
	var p: Vector2 = sim.position_on_orbit_km(o.semi_major_axis_km,o.eccentricity,o.time_since_periapsis_s).rotated(o.arg_periapsis_rad)
	var prediction: Dictionary = sim.predict_orbit_burn(o,-100.0)
	var n: OrbitState = prediction.orbit
	var q: Vector2 = sim.position_on_orbit_km(n.semi_major_axis_km,n.eccentricity,n.time_since_periapsis_s).rotated(n.arg_periapsis_rad)
	check(p.distance_to(q) < 0.1 and n.semi_major_axis_km < o.semi_major_axis_km, "off-apsis retrograde remains continuous")
	flight.queue_free()
	print("Burn failures: ", failures)
	quit(1 if failures else 0)
