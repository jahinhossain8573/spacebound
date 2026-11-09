extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func resolve(em: Node, choice := "continue") -> void:
	em._popup.choice_selected.emit(choice)
	em._popup.closed.emit()
func run_tests() -> void:
	var gm := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	var sim := root.get_node("FlightSim")
	var em := root.get_node("EventManager")
	gm.save_path = "user://spa18-%d.json" % Time.get_ticks_usec()
	gm.new_campaign()
	gm.completed_missions.assign([1,2])
	gm.start_mission(3)
	var mission: Dictionary = gm.current_mission
	gm.current_build = {"launcher":data.get_launcher(mission.requiredLauncher),"bus":data.get_bus(mission.requiredBus),"installed_components":[data.get_part("pwr_mma_ehawk_s"),data.get_part("pwr_gomspace_p31u"),data.get_part("pwr_gomspace_bp4"),data.get_part("av_gomspace_a3200"),data.get_part("prop_mr103g"),data.get_part("inst_nanocam_c1u")],"propellant_mass_kg":10.0}
	gm.last_result = {"mission_number":3,"attempt_id":gm.attempt_id,"launched":true,"events_fired":[],"flight_log":[],"objectives":[{"name":"Reach starting orbit","done":true},{"name":"Survive mission duration","done":false},{"name":"Mission objective","done":false}]}
	em.random_enabled = false
	var flight = load("res://scenes/FlightView.tscn").instantiate()
	root.add_child(flight)
	flight.set_process(false)
	check(em.events.size() == 6 and em.eligible(em.get_event("E3")), "six catalog events and deployable eligibility")
	gm.owned_tech_nodes.append("L5")
	check(is_equal_approx(em.probability_multiplier(), 0.7), "L5 reduces event probability")
	gm.owned_tech_nodes.append("L6")
	check(is_equal_approx(em.probability_multiplier(), 0.5), "L6 provides stronger probability reduction")
	gm.owned_tech_nodes.erase("L5")
	gm.owned_tech_nodes.erase("L6")
	var original_generation: float = flight.generation_w
	check(em.force_event("E3") and em.blocking, "forced E3 opens modal")
	var elapsed: float = flight.mission_elapsed_s
	flight.advance_time(100)
	check(flight.mission_elapsed_s == elapsed, "time paused while event open")
	resolve(em)
	check(is_equal_approx(flight.generation_w, original_generation - 17.5) and not em.force_event("E3"), "E3 cuts only deployable generation once")
	var previous_fuel: float = flight._burn_panel.fuel_kg
	check(em.force_event("E8") and em._can_avoid(), "E8 avoidance available")
	resolve(em,"avoid")
	check(flight._burn_panel.fuel_kg < previous_fuel and absf(flight._burn_panel.remaining_dv() - (sim.calculate_delta_v(flight._burn_panel.dry_kg, flight._burn_panel.dry_kg + previous_fuel, flight._burn_panel.engine.ispSeconds) - 10.0)) < 0.01, "avoidance spends 10 m/s")
	flight._burn_panel.fuel_kg = 0.0
	check(not em._can_avoid(), "avoidance unavailable without fuel")
	flight._burn_panel.fuel_kg = 10.0
	check(flight._burn_panel.execute_burn(20, false), "prepare E11 burn")
	var nominal: float = flight.orbit.semi_major_axis_km
	var fuel_after: float = flight._burn_panel.fuel_kg
	check(em.force_event("E11"), "force E11")
	resolve(em)
	check(flight.orbit.semi_major_axis_km < nominal and is_equal_approx(flight._burn_panel.fuel_kg, fuel_after), "E11 corrects orbit without refund")
	gm.current_build.installed_components.append(data.get_part("av_bae_rad750"))
	check(em.force_event("E7"), "force E7")
	resolve(em)
	check(not flight.power_failed and gm.last_result.flight_log.back().contains("No damage"), "hardened computer prevents E7 damage")
	check(em.force_event("E9"), "force E9")
	em._remaining_s = 6.0 * 86400.0
	resolve(em)
	check(gm.last_result.optical_objective_blocked, "short cloud blockade blocks imaging")
	check(not em.blocking and gm.last_result.events_fired.size() == 5, "events drain and record once")
	flight._skip_result = {"survived":true}
	flight.battery_lowest_pct = 20.0
	check(not em.eligible(em.get_event("E18")), "extension requires battery above 20 percent")
	flight.battery_lowest_pct = 21.0
	check(em.eligible(em.get_event("E18")) and em.force_event("E18"), "E18 requires survived skip and battery margin")
	resolve(em)
	var extension := {"mission_number":3,"launched":true,"objectives":[{"done":true}],"events_fired":["E18"]}
	var no_extension := extension.duplicate(true)
	no_extension.events_fired = []
	check(gm.compute_score(extension).science_points == gm.compute_score(no_extension).science_points + 17, "E18 adds 20 percent plus its standard bonus")
	extension.is_replay = true
	check(gm.compute_score(extension).science_points == 17, "replay reward remains fixed")
	flight.queue_free()
	await process_frame
	gm.start_mission(3)
	gm.current_build = {"launcher":data.get_launcher(mission.requiredLauncher),"bus":data.get_bus(mission.requiredBus),"installed_components":[data.get_part("pwr_mma_ehawk_s"),data.get_part("pwr_gomspace_bp4"),data.get_part("av_gomspace_a3200"),data.get_part("inst_nanocam_c1u")],"propellant_mass_kg":0.0}
	gm.last_result = {"mission_number":3,"attempt_id":gm.attempt_id,"launched":true,"events_fired":[],"flight_log":[],"objectives":[{"name":"Reach starting orbit","done":true},{"name":"Survive mission duration","done":false},{"name":"Mission objective","done":false}]}
	flight = load("res://scenes/FlightView.tscn").instantiate()
	root.add_child(flight)
	flight.set_process(false)
	em.random_enabled = true
	em.get_event("E7").probability = 0.0
	em.get_event("E8").probability = 0.0
	flight.skip_mission_time()
	check(em.blocking and em._active.id == "E9" and flight._skip_result.is_empty(), "Mission 3 E9 interrupts skip before calculation")
	resolve(em)
	check(not em.blocking and not flight._skip_result.is_empty() and gm.last_result.optical_science_penalty, "skip resumes with cloud penalty")
	em.get_event("E18").probability = 1.0
	flight._process(3.0)
	check(not flight.mission_finished and em.blocking and em._active.id == "E18", "extension opens before settlement after successful skip")
	resolve(em)
	check(flight.mission_finished, "skip completes after event")
	var receipt: Dictionary = gm.finalize_mission(gm.last_result)
	check("E9" in receipt.events_fired and not receipt.flight_log.is_empty(), "settlement preserves historical event IDs")
	var with_penalty: Dictionary = gm.last_result.duplicate(true)
	var without_penalty := with_penalty.duplicate(true)
	without_penalty.erase("optical_science_penalty")
	check(gm.compute_score(with_penalty).score == gm.compute_score(without_penalty).score and gm.compute_score(with_penalty).funds_millions == gm.compute_score(without_penalty).funds_millions, "cloud penalty affects bonus SP only")
	var saved_build: Dictionary = gm.current_build.duplicate(true)
	check(gm.save_campaign() == OK and gm.load_campaign() == OK and "E9" in gm.last_receipt.events_fired and "E18" in gm.last_receipt.events_fired, "event precedents survive save and reload")
	flight.queue_free()
	await process_frame
	em.random_enabled = false
	gm.start_mission(3)
	gm.current_build = saved_build.duplicate(true)
	gm.last_result = {"mission_number":3,"attempt_id":gm.attempt_id,"launched":true,"events_fired":[],"flight_log":[],"objectives":[{"name":"Reach starting orbit","done":true},{"name":"Survive mission duration","done":false}]}
	flight = load("res://scenes/FlightView.tscn").instantiate()
	root.add_child(flight)
	flight.set_process(false)
	var loss_seed := 0
	while true:
		em.rng.seed = loss_seed
		if em.rng.randf() < 0.4: break
		loss_seed += 1
	em.rng.seed = loss_seed
	check(em.force_event("E7"), "force non-hardened E7")
	resolve(em)
	check(flight.power_failed and flight._failure_delay == 3.0, "non-hardened computer can be lost")
	flight.queue_free()
	await process_frame
	gm.start_mission(3)
	gm.current_build = saved_build.duplicate(true)
	gm.last_result = {"mission_number":3,"attempt_id":gm.attempt_id,"launched":true,"events_fired":[],"flight_log":[],"objectives":[{"name":"Reach starting orbit","done":true},{"name":"Survive mission duration","done":false}]}
	flight = load("res://scenes/FlightView.tscn").instantiate()
	root.add_child(flight)
	flight.set_process(false)
	check(em.force_event("E8"), "force debris event without engine")
	check(em._popup._body.get_child(2).disabled, "avoidance button disabled without propulsion")
	var collision_seed := 0
	while true:
		em.rng.seed = collision_seed
		if em.rng.randf() < 0.05: break
		collision_seed += 1
	em.rng.seed = collision_seed
	resolve(em,"risk")
	check(flight.power_failed, "accepted debris risk can cause loss")
	flight.queue_free()
	await process_frame
	em.get_event("E18").probability = 0.10
	em.get_event("E7").probability = 0.12
	em.get_event("E8").probability = 0.08
	em.random_enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gm.save_path))
	print("Event failures: ",failures)
	quit(1 if failures else 0)
