extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func run_tests() -> void:
	root.get_node("EventManager").random_enabled = false
	var gm := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	var sim := root.get_node("FlightSim")
	var partial: Dictionary = sim.simulate_mission_skip(170, 100, 0.2, 2, 1, 100, 100, 10, false)
	check(absf(partial.sunlit_pass_completed_s - 170.0) < 0.01, "partial pass discarded until full next pass")
	var midway: Dictionary = sim.simulate_mission_skip(70, 100, 0.2, 2, 1, 100, 100, 10, true)
	check(absf(midway.sunlit_pass_completed_s - 70.0) < 0.01, "skip continues in-progress sunlight")
	var early: Dictionary = sim.simulate_mission_skip(200, 100, 0.2, 0, 3600, 100, 5, 10, true)
	check(not early.survived and early.sunlit_pass_completed_s < 0 and absf(early.elapsed_s - 5) < 0.01, "depletion before beacon stops simulation")
	var late: Dictionary = sim.simulate_mission_skip(200, 100, 0.2, 0, 3600, 100, 100, 10, true)
	check(not late.survived and absf(late.sunlit_pass_completed_s - 70) < 0.01, "beacon retained after later depletion")
	gm.save_path = "user://spa15-%d.json" % Time.get_ticks_usec()
	gm.new_campaign()
	gm.start_mission(1)
	var mission: Dictionary = gm.current_mission
	gm.current_build = {"launcher":data.get_launcher(mission.requiredLauncher),"bus":data.get_bus(mission.requiredBus),"installed_components":[data.get_part("pwr_gomspace_p31u"),data.get_part("pwr_gomspace_bp4"),data.get_part("av_gomspace_a3200"),data.get_part("com_endurosat_uhf")],"propellant_mass_kg":0.0}
	var stats: Dictionary = load("res://scripts/BuildStats.gd").new().calculate_stats(gm.current_build,mission)
	gm.last_result = {"mission_number":1,"attempt_id":gm.attempt_id,"launched":true,"objectives":[],"flight_log":[],"total_cost_m":stats.cost_millions,"mass_margin_pct":stats.mass_margin_pct}
	for o in mission.objectives: gm.last_result.objectives.append({"id":o.id,"name":o.name,"done":o.id == "reach_orbit"})
	var flight = load("res://scenes/FlightView.tscn").instantiate()
	root.add_child(flight)
	flight.set_process(false)
	var period: float = sim.orbital_period_s(flight.orbit.semi_major_axis_km)
	flight.advance_time(period * 0.3)
	check(not gm.last_result.objectives[1].done, "initial partial sunlight does not award beacon")
	flight.skip_mission_time()
	flight._process(1.5)
	check(gm.last_result.objectives[1].done and flight._beacon_label.text.contains("Betbunia"), "skip awards and displays beacon")
	flight._process(1.5)
	check(gm.last_result.objectives[2].done and gm.last_result.flight_log.size() == 2, "survival and one beacon log")
	var receipt: Dictionary = gm.finalize_mission(gm.last_result)
	check(receipt.stars == 3 and absf(receipt.score - 92.5) < 0.01 and receipt.science_points == 17 and receipt.funds_millions == 16, "reference build rewards")
	check(gm.is_mission_unlocked(2) and gm.unlocked_tier == 1, "Mission 2 and Tier 1 unlocked")
	flight.queue_free()
	await process_frame
	gm.start_mission(1)
	gm.current_build.installed_components = [data.get_part("pwr_gomspace_p31u"),data.get_part("pwr_gomspace_bp4"),data.get_part("av_gomspace_a3200")]
	gm.last_result = {"mission_number":1,"attempt_id":gm.attempt_id,"launched":true,"objectives":[],"flight_log":[]}
	for o in mission.objectives: gm.last_result.objectives.append({"id":o.id,"name":o.name,"done":o.id == "reach_orbit"})
	flight = load("res://scenes/FlightView.tscn").instantiate()
	root.add_child(flight)
	flight.set_process(false)
	flight.orbit.arg_periapsis_rad = 0.9
	flight.advance_time(period * 2)
	check(not gm.last_result.objectives[1].done, "missing radio prevents beacon in live flight")
	gm.current_build.installed_components.append(data.get_part("com_endurosat_uhf"))
	flight.advance_time(period * 2)
	check(gm.last_result.objectives[1].done and gm.last_result.flight_log.size() == 1, "rotated live orbit awards one beacon")
	flight.advance_time(period * 2)
	check(gm.last_result.flight_log.size() == 1, "beacon is not repeated")
	flight.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.save_path))
	print("Mission 1 failures: ", failures)
	quit(1 if failures else 0)
