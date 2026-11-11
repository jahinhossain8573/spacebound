extends SceneTree
const OBJECTIVES = preload("res://scripts/MissionObjectives.gd")
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func run_tests() -> void:
	var gm := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	var em := root.get_node("EventManager")
	gm.save_path = "user://spa20-%d.json" % Time.get_ticks_usec()
	gm.new_campaign()
	gm.completed_missions.assign([1, 2])
	check(gm.start_mission(3), "Mission 3 unlocks after Mission 2")
	var m: Dictionary = gm.current_mission
	var parts: Array = []
	for id in ["pwr_spectrolab_m", "pwr_abs_slc_m", "av_gomspace_a3200", "adcs_rw003", "inst_hyperscout2", "com_syrlinks_ewc30"]: parts.append(data.get_part(id))
	var build := {"launcher": data.get_launcher(m.requiredLauncher), "bus": data.get_bus(m.requiredBus), "installed_components": parts, "propellant_mass_kg": 0.0}
	var helper = load("res://scripts/BuildStats.gd").new()
	var stats: Dictionary = helper.calculate_stats(build, m)
	var failed := false
	for row in helper.run_readiness_review(build, m):
		if row.status == "FAIL":
			print("Readiness: ", row)
			failed = true
	check(not failed and is_equal_approx(stats.launcher_capacity_kg, 210.0), "Reference build passes at 210 kg SSO capacity")
	var overloaded: Dictionary = build.duplicate(true)
	overloaded.bus.dryMassKg = 220.0
	var mass_failed := false
	for row in helper.run_readiness_review(overloaded, m):
		if row.check == "Mass budget" and row.status == "FAIL": mass_failed = true
	check(mass_failed, "Over 210 kg fails readiness")
	check(OBJECTIVES.optical_installed(parts) and not OBJECTIVES.optical_installed([data.get_part("com_syrlinks_ewc30")]), "Optical instrument required")
	check(OBJECTIVES.downlink(parts, 50000) and not OBJECTIVES.downlink([data.get_part("com_syrlinks_ewc27")], 50000), "X-band data rate required")
	check(OBJECTIVES.clear_observation_seconds(15, 15 + 14 * 86400, 15, 15 + 7 * 86400) == 7 * 86400, "Seven cloudy days leave seven clear days")
	build["stats"] = stats
	gm.current_build = build
	gm.debug_disable_reliability = true
	em.random_enabled = true
	for event in em.events:
		if event.id != "E9": event.probability = 0.0
	var launch = load("res://scenes/Launch.tscn").instantiate()
	root.add_child(launch)
	launch.set_process(false)
	launch.ignite()
	launch.advance_ascent(launch.ascent_duration)
	var flight = launch._flight
	flight.set_process(false)
	check(em.blocking and em._active.id == "E9", "Cloud event occurs on live arrival without skipping")
	check(flight._mission_end_s() - flight.mission_elapsed_s == 14.0 * 86400.0, "Mission duration starts at insertion")
	em._popup.choice_selected.emit("continue")
	em._popup.closed.emit()
	check(gm.last_result.optical_science_penalty and gm.last_result.optical_blocked_until_s - gm.last_result.optical_blocked_from_s == 7.0 * 86400.0, "Clouds last seven days and reduce bonus science")
	check(gm.last_result.objectives[0].done and gm.last_result.objectives[2].done and not gm.last_result.objectives[1].done, "Orbit and downlink tracked separately from clear days")
	flight.advance_time(86400.0)
	check(gm.last_result.clear_observation_s == 0.0, "Live flight respects the cloud interval")
	flight.skip_mission_time()
	flight._process(1.5)
	check(not gm.last_result.objectives[1].done, "Cloudy interval does not satisfy objective")
	flight._process(1.5)
	check(flight.mission_finished and gm.last_result.objectives[1].done and gm.last_result.objectives[3].done, "Skip completes seven clear days and survival")
	var receipt: Dictionary = gm.finalize_mission(gm.last_result)
	check(receipt.outcome == "Success" and receipt.funds_millions == 52.0 and gm.is_mission_unlocked(4), "Success pays $52M and unlocks Mission 4")
	var without_cloud_penalty: Dictionary = gm.last_result.duplicate(true)
	without_cloud_penalty.erase("optical_science_penalty")
	check(gm.compute_score(without_cloud_penalty).science_points > receipt.science_points, "Clouds reduce bonus science")
	check("L11" in gm.owned_tech_nodes and "launcher_falcon_9" in gm.unlocked_part_ids, "Success grants Falcon 9 and L11")
	check(gm.finalize_mission(gm.last_result) == receipt and gm.funds_millions == 52.0, "Settlement occurs once")
	check(ResourceLoader.exists("res://assets/images/nasa/bangladesh_flood.jpg"), "Bundled NASA image available")
	launch.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.save_path))
	print("Mission 3 failures: ", failures)
	quit(1 if failures else 0)
