extends SceneTree

var failures := 0
var skips := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func run_tests() -> void:
	root.get_node("EventManager").random_enabled = false
	var sim := root.get_node("FlightSim")
	var manager := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	var period: float = sim.orbital_period_s(6771.0)
	var fraction: float = sim.eclipse_fraction(6771.0)
	var result: Dictionary = sim.simulate_mission_skip(7*86400,period,fraction,7,2.7,70)
	check(result.survived and result.lowest_wh < 70 and result.lowest_wh > 60, "Mission 1 survives seven days")
	result = sim.simulate_mission_skip(86400,period,fraction,7,2.7,0)
	check(not result.survived and result.failed_orbit == 1, "no battery fails first eclipse")
	result = sim.simulate_mission_skip(60,period,fraction,7,2.7,70,0.001,period*(1-fraction))
	check(not result.survived, "skip starts with current charge in eclipse")
	result = sim.simulate_mission_skip(60,period,0,0,0,0)
	check(result.survived, "zero load needs no stored energy")
	result = sim.simulate_mission_skip(365*86400,86160,72.0/1436,320,100,500)
	check(result.survived, "GEO year simulation")
	manager.save_path = "user://spa14-test-%d.json" % Time.get_ticks_usec()
	manager.new_campaign()
	manager.start_mission(1)
	manager.current_build = {"launcher":data.get_launcher(manager.current_mission.requiredLauncher),"bus":data.get_bus(manager.current_mission.requiredBus),"installed_components":[data.get_part("pwr_gomspace_p31u"),data.get_part("pwr_gomspace_bp4"),data.get_part("av_gomspace_a3200"),data.get_part("com_endurosat_uhf")],"propellant_mass_kg":0.0}
	manager.last_result = {"mission_number":1,"attempt_id":manager.attempt_id,"launched":true,"objectives":[{"name":"Reach starting orbit","done":true},{"name":"Survive mission duration","done":false},{"name":"Mission objective","done":false}],"flight_log":[]}
	var flight = load("res://scenes/FlightView.tscn").instantiate()
	root.add_child(flight)
	flight.set_process(false)
	check(flight.power_active and flight.battery_capacity_wh == 70 and flight.can_skip_mission(), "approved Mission 1 power initialized")
	flight.orbit.time_since_periapsis_s = period/2
	flight.advance_time(60)
	check(flight.battery_charge_wh < 70 and flight.in_eclipse, "live eclipse drains battery")
	flight.orbit.time_since_periapsis_s = 0
	flight.advance_time(60)
	check(is_equal_approx(flight.battery_charge_wh,70), "sunlight recharges and caps battery")
	manager.mission_skip_started.connect(func(_remaining): skips += 1)
	flight.skip_mission_time()
	flight.skip_mission_time()
	check(skips == 1 and not flight._skip_result.is_empty(), "skip emits once and rejects repeated press")
	flight._process(1.5)
	check(not flight.mission_finished and flight.mission_elapsed_s > 86400, "clock animates during skip")
	flight._process(1.5)
	check(flight.mission_finished and manager.last_result.objectives[1].done and manager.last_result.objectives[2].done, "skip completes at three seconds")
	check(manager.last_result.battery_lowest_pct < 100 and manager.last_result.battery_lowest_pct > 30, "minimum battery reaches scoring")
	var receipt: Dictionary = manager.finalize_mission(manager.last_result)
	check(receipt.outcome == "Success", "survival settles successful mission")
	flight.queue_free()
	await process_frame
	manager.current_mission = data.get_mission(4)
	manager.last_result.objectives[1].done = false
	flight = load("res://scenes/FlightView.tscn").instantiate()
	root.add_child(flight)
	flight.set_process(false)
	check(not flight.can_skip_mission(), "GTO cannot skip required maneuver")
	var geo := OrbitState.new()
	geo.semi_major_axis_km = 42164
	flight.set_orbit(geo)
	check(flight.can_skip_mission(), "circular GEO enables skip")
	flight.battery_capacity_wh = 0
	flight.battery_charge_wh = 0
	flight.orbit.time_since_periapsis_s = sim.orbital_period_s(42164)/2
	flight.advance_time(5)
	check(flight.power_failed and not manager.last_result.objectives[1].done and flight._failure_delay == 3, "live power failure preserves failed survival")
	flight.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.save_path))
	print("Power failures: ",failures)
	quit(1 if failures else 0)
