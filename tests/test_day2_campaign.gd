extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func run_tests() -> void:
	var gm := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	var events := root.get_node("EventManager")
	gm.save_path = "user://spa21-flow-%d.json" % Time.get_ticks_usec()
	gm.new_campaign()
	events.random_enabled = true
	for event in events.events:
		if event.id != "E9": event.probability = 0.0
	var designs := {
		1:["pwr_gomspace_p31u", "pwr_gomspace_bp4", "av_gomspace_a3200", "com_endurosat_uhf"],
		2:["pwr_mma_ehawk_s", "pwr_gomspace_bp4", "av_gomspace_a3200", "inst_nanocam_c1u", "com_syrlinks_ewc27", "adcs_rw003"],
		3:["pwr_spectrolab_m", "pwr_abs_slc_m", "av_gomspace_a3200", "adcs_rw003", "inst_hyperscout2", "com_syrlinks_ewc30"],
		4:["pwr_airbus_l", "pwr_eaglepicher_l", "av_bae_rad750", "prop_aerojet_r4d15", "inst_kuka_transponder_suite"]}
	for number in [1, 2, 3, 4]:
		if number == 2: check(gm.research_node("A1") == OK, "Mission 2 wheels researched with earned SP")
		if number == 3:
			for id in ["L1", "I2", "C1", "P1"]: check(gm.research_node(id) == OK, "Mission 3 research " + id)
		if number == 4:
			print("Science available before Mission 4 research: ", gm.science_points)
			for id in ["L3", "L4", "P2", "A5", "I5", "A8"]: check(gm.research_node(id) == OK, "Mission 4 research " + id)
		check(gm.start_mission(number), "Start Mission %d" % number)
		var mission: Dictionary = gm.current_mission
		var parts: Array = []
		for id in designs[number]:
			check(gm.is_part_unlocked(id), "Part available: " + id)
			parts.append(data.get_part(id))
		var build := {"launcher":data.get_launcher(mission.requiredLauncher),"bus":data.get_bus(mission.requiredBus),"installed_components":parts,"propellant_mass_kg":400.0 if number == 4 else 0.0}
		var helper = load("res://scripts/BuildStats.gd").new()
		var failed := false
		for row in helper.run_readiness_review(build, mission):
			if row.status == "FAIL": failed = true
		check(not failed, "Mission %d build passes readiness" % number)
		build["stats"] = helper.calculate_stats(build,mission)
		gm.current_build = build
		var launch = load("res://scenes/Launch.tscn").instantiate()
		root.add_child(launch)
		launch.set_process(false)
		launch.rng.seed = 1
		launch.toggle_scripted_flight()
		check(not launch.failed, "Seeded Mission %d launch succeeds" % number)
		launch.advance_ascent(20001.0)
		var flight = launch._flight
		flight.set_process(false)
		while events.blocking:
			events._popup.choice_selected.emit("continue")
			events._popup.closed.emit()
		if number == 4:
			flight.wait_for_apsis(true)
			flight.advance_time(root.get_node("FlightSim").orbital_period_s(flight.orbit.semi_major_axis_km))
			check(flight._burn_panel.execute_burn(1470, false), "Campaign apogee burn")
		flight.skip_mission_time()
		while events.blocking:
			events._popup.choice_selected.emit("continue")
			events._popup.closed.emit()
		flight._process(3.0)
		while events.blocking:
			events._popup.choice_selected.emit("continue")
			events._popup.closed.emit()
		var receipt: Dictionary = gm.finalize_mission(gm.last_result)
		check(receipt.get("outcome") == "Success", "Mission %d completes successfully" % number)
		print("Mission %d payout: %s SP; campaign balance: %s SP, $%sM" % [number, receipt.get("science_points"), gm.science_points, gm.funds_millions])
		launch.queue_free()
		await process_frame
	check(gm.unlocked_tier == 3 and gm.completed_missions == [1,2,3,4], "Fresh campaign reaches Tier 3 without debug tools")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.save_path))
	print("Day 2 campaign failures: ", failures)
	quit(1 if failures else 0)
