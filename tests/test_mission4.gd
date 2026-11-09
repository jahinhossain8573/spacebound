extends SceneTree
const OBJECTIVES = preload("res://scripts/MissionObjectives.gd")
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func has_failure(review: Array, check_name: String, text := "") -> bool:
	for row in review:
		if row.check == check_name and row.status == "FAIL" and (text.is_empty() or text in row.message): return true
	return false
func run_tests() -> void:
	var gm := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	var em := root.get_node("EventManager")
	var sim := root.get_node("FlightSim")
	gm.save_path = "user://spa21-%d.json" % Time.get_ticks_usec()
	gm.new_campaign()
	gm.completed_missions.assign([1, 2, 3])
	gm.unlocked_tier = 2
	gm.owned_tech_nodes.append("L11")
	gm.unlocked_part_ids.append("launcher_falcon_9")
	check(gm.start_mission(4), "Mission 4 follows Mission 3")
	var mission: Dictionary = gm.current_mission
	var parts: Array = []
	for id in ["pwr_airbus_l", "pwr_eaglepicher_l", "av_bae_rad750", "prop_aerojet_r4d15", "inst_kuka_transponder_suite"]: parts.append(data.get_part(id))
	var build := {"launcher":data.get_launcher(mission.requiredLauncher), "bus":data.get_bus(mission.requiredBus), "installed_components":parts, "propellant_mass_kg":400.0}
	var helper = load("res://scripts/BuildStats.gd").new()
	var stats: Dictionary = helper.calculate_stats(build, mission)
	var review: Array = helper.run_readiness_review(build, mission)
	var failed := false
	for row in review:
		if row.status == "FAIL":
			failed = true
			print(row)
	check(not failed and stats.launcher_capacity_kg == 5500 and stats.delta_v_mps >= 1650, "Reference build passes GTO mass and delta-v checks")
	check(stats.generation_w == 1300 and stats.draw_w == 1215 and stats.eclipse_minutes == 72, "Reference power and GEO eclipse")
	var no_rad: Dictionary = build.duplicate(true)
	no_rad.installed_components[2] = data.get_part("av_gomspace_a3200")
	check(has_failure(helper.run_readiness_review(no_rad, mission), "Radiation", "research A5"), "Missing RAD750 advises research A5")
	var no_fuel: Dictionary = build.duplicate(true)
	no_fuel.propellant_mass_kg = 10.0
	check(has_failure(helper.run_readiness_review(no_fuel, mission), "Delta-v"), "Insufficient fuel fails review")
	check(mission.historyNote.contains("Spacebus 4000B2") and mission.historyNote.contains("119.1°"), "Historical satellite note included")
	em.random_enabled = false
	build["stats"] = stats
	gm.current_build = build
	var launch = load("res://scenes/Launch.tscn").instantiate()
	root.add_child(launch)
	launch.set_process(false)
	launch.rng.seed = 1
	launch.ignite()
	check(not launch.failed, "Seeded Falcon 9 launch succeeds without debug override")
	launch.advance_ascent(15)
	var flight = launch._flight
	flight.set_process(false)
	check(absf(flight.orbit.semi_major_axis_km * (1-flight.orbit.eccentricity) - 6621.0) < 0.1 and absf(flight.orbit.semi_major_axis_km * (1+flight.orbit.eccentricity) - 42164.0) < 0.1, "Launch inserts exact GTO apsides")
	check(gm.last_result.objectives[0].done and not gm.last_result.objectives[1].done and gm.last_result.objectives[2].done and not flight.can_skip_mission(), "GTO, transponders and skip gate tracked")
	flight.generation_w = 1200
	flight._update_mission_objectives()
	check(not gm.last_result.objectives[2].done, "Underpowered transponder objective fails")
	flight.generation_w = 1300
	flight._update_mission_objectives()
	flight.wait_for_apsis(true)
	flight.advance_time(sim.orbital_period_s(flight.orbit.semi_major_axis_km))
	check(not flight.power_failed and flight._wait_target < 0, "Wait reaches apoapsis with power")
	var panel = flight._burn_panel
	var duration: float = sim.burn_duration_s(panel.dry_kg + panel.fuel_kg, 1470, panel.engine.ispSeconds, panel.engine.thrustNewtons)
	check(duration > 2000 and duration < 2500, "Apogee burn estimated near 36 minutes")
	check(panel.execute_burn(1470, false), "Execute apogee burn")
	check(em.force_event("E11"), "Force E11 underperformance")
	em._popup.choice_selected.emit("continue")
	em._popup.closed.emit()
	flight._update_mission_objectives()
	check(not gm.last_result.objectives[1].done and not flight.can_skip_mission(), "Underperformance leaves GEO unachieved")
	check(panel.execute_burn(147, false), "Top-up burn")
	flight._update_mission_objectives()
	check(gm.last_result.objectives[1].done and flight.can_skip_mission() and flight._beacon_label.text == "Geostationary orbit achieved", "GEO achievement enables skip")
	check(em.force_event("E7"), "Force radiation event")
	em._popup.choice_selected.emit("continue")
	check(not flight.power_failed and gm.last_result.flight_log.back().contains("No damage"), "RAD750 prevents E7 damage")
	em._popup.closed.emit()
	flight.skip_mission_time()
	flight._process(3.0)
	check(flight.mission_finished and gm.last_result.objectives[3].done, "365-day GEO operations survive")
	var receipt: Dictionary = gm.finalize_mission(gm.last_result)
	check(receipt.outcome == "Success" and receipt.funds_millions == 175 and gm.unlocked_tier == 3, "Success pays and unlocks Tier 3")
	check(gm.finalize_mission(gm.last_result) == receipt, "Settlement cannot pay twice")
	launch.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.save_path))
	print("Mission 4 failures: ", failures)
	quit(1 if failures else 0)
