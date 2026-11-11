extends SceneTree
const OBJECTIVES = preload("res://scripts/MissionObjectives.gd")
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func run_tests() -> void:
	var gm := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	var sim := root.get_node("FlightSim")
	root.get_node("EventManager").random_enabled = false
	gm.save_path = "user://spa19-%d.json" % Time.get_ticks_usec()
	gm.new_campaign()
	check(not gm.is_mission_unlocked(2), "Mission 2 initially locked")
	gm.start_mission(1)
	gm.finalize_mission({"mission_number":1,"launched":true,"objectives":[{"done":true}],"battery_lowest_pct":80,"total_cost_m":9.3,"mass_margin_pct":90})
	check(gm.is_mission_unlocked(2), "Mission 1 success unlocks Mission 2")
	var m: Dictionary = data.get_mission(2)
	var helper = load("res://scripts/BuildStats.gd").new()
	var parts: Array = [data.get_part("pwr_mma_ehawk_s"),data.get_part("pwr_gomspace_bp4"),data.get_part("av_gomspace_a3200"),data.get_part("inst_nanocam_c1u"),data.get_part("com_syrlinks_ewc27")]
	var build := {"launcher":data.get_launcher(m.requiredLauncher),"bus":data.get_bus(m.requiredBus),"installed_components":parts,"propellant_mass_kg":0.0}
	var missing := false
	for row in helper.run_readiness_review(build,m):
		if row.status == "FAIL" and row.message.contains("RW-0.03") and row.message.contains("research A1"): missing = true
	check(missing and not gm.is_part_unlocked("adcs_rw003"), "missing wheels advise A1 research")
	check(gm.research_node("A1") == OK and gm.is_part_unlocked("adcs_rw003"), "A1 unlocks wheels")
	parts.append(data.get_part("adcs_rw003"))
	var review: Array = helper.run_readiness_review(build,m)
	var failed := false
	for row in review:
		if row.status == "FAIL": failed = true
	var stats: Dictionary = helper.calculate_stats(build,m)
	check(not failed and absf(stats.cost_millions-12.05)<0.001 and absf(stats.draw_w-15.5)<0.001, "reference build passes and matches data")
	var body: Dictionary = build.duplicate(true)
	body.installed_components[0] = data.get_part("pwr_gomspace_p31u")
	var power_fail := false
	for row in helper.run_readiness_review(body,m):
		if row.check == "Daylight power" and row.status == "FAIL": power_fail = true
	check(power_fail, "body panels alone fail power review")
	var without_battery: Dictionary = build.duplicate(true)
	without_battery.installed_components.remove_at(1)
	var battery_fail := false
	for row in helper.run_readiness_review(without_battery,m):
		if row.check == "Eclipse endurance" and row.status == "FAIL": battery_fail = true
	check(battery_fail, "battery required by readiness")
	check(not OBJECTIVES.imaging([data.get_part("inst_nanocam_c1u"),data.get_part("adcs_fine_sun_sensor")]) and OBJECTIVES.imaging(parts), "imaging requires camera and active pointing")
	check(not OBJECTIVES.downlink([data.get_part("com_endurosat_uhf")],1000) and OBJECTIVES.downlink(parts,1000), "downlink requires fast radio")
	check(OBJECTIVES.count_passes(10,100,510,0) == 6 and OBJECTIVES.count_passes(10,100,510,210) == 4 and OBJECTIVES.count_passes(10,100,510,610) == 0, "sunlit passes respect cloud window")
	var simulated: Dictionary = sim.simulate_mission_skip(370, 100, 0.2, 2, 1, 100, 100, 10, false)
	check(simulated.sunlit_passes == 3 and absf(simulated.sunlit_pass_completed_s - 170.0) < 0.01, "power simulation counts complete sunlit passes")
	var depleted: Dictionary = sim.simulate_mission_skip(1000, 100, 0.2, 0, 100, 20, 20, 0, true)
	check(not depleted.survived and depleted.sunlit_passes == 7 and absf(depleted.elapsed_s - 720.0) < 0.01, "capture stops at battery depletion")
	gm.start_mission(2)
	build["stats"] = stats
	gm.current_build = build
	gm.debug_disable_reliability = true
	var launch = load("res://scenes/Launch.tscn").instantiate()
	root.add_child(launch)
	launch.set_process(false)
	launch.ignite()
	launch.advance_ascent(launch.ascent_duration)
	var flight = launch._flight
	flight.set_process(false)
	check(gm.last_result.objectives.size() == 4 and gm.last_result.objectives[0].done and gm.last_result.objectives[2].done, "launch and downlink objectives")
	var original_parts: Array = gm.current_build.installed_components.duplicate()
	gm.current_build.installed_components.erase(data.get_part("com_syrlinks_ewc27"))
	flight._update_mission_objectives()
	check(not gm.last_result.objectives[2].done, "downlink fails without fast radio")
	gm.current_build.installed_components = original_parts.duplicate()
	flight._update_mission_objectives()
	check(gm.last_result.objectives[2].done, "downlink recovers with fast radio")
	var em := root.get_node("EventManager")
	check(em.force_event("E9"), "force optical cloud event")
	em._remaining_s = 6.0 * 86400.0
	em._popup.choice_selected.emit("continue")
	em._popup.closed.emit()
	flight.images_captured = 101
	flight._update_mission_objectives()
	check(not gm.last_result.objectives[1].done, "short remaining mission cannot complete blocked imaging")
	flight.images_captured = 0
	gm.last_result.erase("optical_objective_blocked")
	gm.last_result.erase("optical_blocked_until_s")
	gm.last_result.events_fired.clear()
	gm.last_result.flight_log.clear()
	gm.current_build.installed_components.erase(data.get_part("adcs_rw003"))
	flight._apply_image_passes(0, 10, 1000, 100)
	check(flight.images_captured == 0, "no images without active pointing")
	gm.current_build.installed_components = original_parts
	gm.last_result["optical_blocked_until_s"] = 1000.0
	flight._apply_image_passes(0, 10, 900, 100)
	check(flight.images_captured == 0, "cloud blockade prevents image capture")
	gm.last_result.erase("optical_blocked_until_s")
	var period: float = sim.orbital_period_s(flight.orbit.semi_major_axis_km)
	flight.advance_time(period * 2)
	check(flight.images_captured >= 1 and flight._images_label.text.contains("Images captured"), "images captured during live flight")
	flight.skip_mission_time()
	flight._process(1.5)
	var midway: int = flight.images_captured
	flight._process(1.5)
	check(midway > 0 and flight.images_captured >= 100 and gm.last_result.objectives[1].done and gm.last_result.objectives[3].done, "skip adds images and completes objectives")
	var receipt: Dictionary = gm.finalize_mission(gm.last_result)
	check(receipt.outcome == "Success" and receipt.images_captured == flight.images_captured and gm.is_mission_unlocked(3), "image count reaches debrief and unlocks Mission 3")
	check(gm.save_campaign() == OK and gm.load_campaign() == OK and gm.last_receipt.images_captured == receipt.images_captured, "image count survives save reload")
	launch.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.save_path))
	print("Mission 2 failures: ",failures)
	quit(1 if failures else 0)
