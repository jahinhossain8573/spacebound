extends SceneTree

var failures := 0

func _initialize() -> void:
	run_tests.call_deferred()

func check(ok: bool, description: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + description)
	if not ok:
		failures += 1

func run_tests() -> void:
	var manager := root.get_node("GameManager")
	var transfer = load("res://scripts/LunarTransfer.gd")
	manager.save_path = "user://spa22-test-%d.json" % Time.get_ticks_usec()
	manager.new_campaign()
	var original_save := FileAccess.get_file_as_string(manager.save_path)
	check(not original_save.is_empty(), "fresh campaign save exists before Archive flight")
	check(not manager.is_mission_unlocked(5) and not manager.start_mission(5), "Mission 5 is locked on a fresh campaign")

	change_scene_to_file("res://scenes/MissionSelect.tscn")
	await scene_changed
	var board = current_scene
	check(board._mission_buttons[5].disabled and board._future_rows.size() == 2, "Mission 5 is locked and future missions are listed")
	board._set_contract_filter("archives")
	check(board._mission_rows[5].wrap.visible and not board._start_button.disabled and board._start_button.text == "Start test flight", "Archives exposes a playable test flight")
	board._start_button.pressed.emit()
	if not manager.attempt_is_archive:
		check(false, "Archives starts the ready build")
		finish(manager)
		return
	await scene_changed
	var launch = current_scene
	launch.set_process(false)
	check(launch.scene_file_path == "res://scenes/Launch.tscn" and not launch.ignited and manager.initial_orbit == null, "Archive starts at the Earth launch pad")
	launch._start.pressed.emit()
	check(launch.ignited and not launch._ascent.scripted and not launch.can_skip, "Archive uses the normal manual ignition control")
	launch.toggle_scripted_flight()
	launch.advance_ascent(20001.0)
	if not launch.finished or not launch._ascent.target_reached():
		check(false, "Archive Vega-C reaches its parking orbit")
		finish(manager)
		return
	await scene_changed
	var lunar = current_scene
	lunar.set_process(false)
	var build: Dictionary = manager.current_build.duplicate(true)
	var orbit: OrbitState = manager.initial_orbit.copy()
	check(lunar.flight != null and absf(orbit.semi_major_axis_km - 6621.0) < 25.0, "Archive launch hands off the achieved parking orbit")
	var parking_start: Vector3 = lunar.flight.position_km()
	lunar.advance_time(transfer.PARKING_S - 1.0)
	check(not lunar.flight.cruise_started and lunar.flight.position_km().distance_to(parking_start) > 600.0, "spacecraft coasts in its achieved parking orbit")
	lunar.advance_time(1.0)
	check(lunar.flight.cruise_started and lunar.flight.elapsed == 0.0 and lunar.flight.curve.get_point_position(0).is_equal_approx(lunar.flight.position_km()), "lunar injection starts automatically at the parking-orbit departure position")
	lunar.advance_time(10 * 86400.0)
	check(lunar.flight.navigation_open and is_equal_approx(lunar.flight.elapsed, transfer.NAVIGATION_S), "time warp stops at navigation update")
	var before: Vector3 = lunar.flight.position_km()
	lunar._amount.value = 47
	check(lunar._prediction.text.contains("440 km"), "prograde prediction updates to 440 km")
	lunar._direction.select(1)
	lunar._refresh_burn()
	check(lunar._prediction.text.contains("7960 km"), "retrograde increases miss distance")
	lunar._direction.select(0)
	var fuel: float = lunar.flight.fuel_kg
	lunar._burn.pressed.emit()
	check(lunar.flight.closest_km == 440.0 and lunar.flight.fuel_kg < fuel, "correction spends propellant and changes the route")
	check(lunar.flight.position_km().is_equal_approx(before), "correction preserves the current position")
	lunar.resume_cruise()
	lunar.advance_time(transfer.END_S)
	check(lunar.flight.approaching and lunar._warp == 100 and absf(lunar.flight.moon_altitude_km() - 10000.0) < 1.0, "lunar approach automatically reduces warp at 10,000 km")
	lunar.advance_time(transfer.CLOSEST_S - lunar.flight.elapsed)
	check(lunar.flight.corridor_met() and absf(lunar.flight.moon_altitude_km() - 440.0) < 1.0, "closest approach matches the corrected geometry")
	lunar.advance_time(transfer.END_S)
	check(lunar.flight.images == 20 and lunar.flight.elapsed == transfer.RETURN_S and lunar.flight.link_active(), "flyby captures 20 images before Earth approach")
	check(not lunar._hud.skip_mission_button.visible and not lunar.flight.finished, "mission completion is unavailable before reentry")
	lunar.advance_time(transfer.END_S)
	check(lunar.flight.elapsed == transfer.ENTRY_S and lunar._warp == 100 and absf(lunar.flight.position_km().length() - 6491.0) < 0.01, "Earth return reaches the 120 km entry interface and reduces warp")
	lunar.advance_time(transfer.END_S)
	check(lunar.flight.elapsed == transfer.CHUTE_S and lunar._warp == 10 and lunar._parachute.visible, "recovery parachute deploys at 6 km and reduces warp")
	lunar.advance_time(transfer.END_S - lunar.flight.elapsed - 1.0)
	check(not lunar.flight.finished and lunar.flight.position_km().length() > transfer.EARTH_RADIUS_KM, "flight continues until actual surface contact")
	lunar.advance_time(1.0)
	var landing: Vector3 = lunar.flight.position_km()
	check(lunar.flight.splashed_down and lunar._splash.visible and not lunar._parachute.visible and lunar._hud.skip_mission_button.visible, "Pacific splashdown opens debrief")
	check(absf(landing.length() - transfer.EARTH_RADIUS_KM) < 0.01 and absf(rad_to_deg(atan2(-landing.z, landing.x)) + 145.0) < 0.01, "spacecraft reaches the ocean surface at 145° west")
	var path_clear := true
	for i in lunar.flight.curve.point_count:
		path_clear = path_clear and lunar.flight.curve.get_point_position(i).length() >= transfer.EARTH_RADIUS_KM - 0.001
	check(path_clear, "the plotted trajectory stays above the Earth's surface through touchdown")
	lunar._hud.skip_mission_button.pressed.emit()
	await scene_changed
	var test_receipt: Dictionary = manager.finalize_mission(manager.last_result)
	check(test_receipt.outcome == "Success" and test_receipt.funds_millions == 0.0 and test_receipt.science_points == 0, "Archive debrief shows success without payout")
	check(manager.completed_missions.is_empty() and manager.unlocked_tier == 0 and not manager.has_launched_once and manager.last_receipt.is_empty() and FileAccess.get_file_as_string(manager.save_path) == original_save, "archive leaves campaign state and save intact")

	var miss = transfer.new(build, build.stats, orbit)
	miss.advance(transfer.PARKING_S)
	miss.advance(transfer.END_S)
	miss.navigation_open = false
	miss.advance(transfer.END_S)
	miss.advance(transfer.END_S)
	check(miss.closest_passed and not miss.corridor_met() and miss.images == 0 and miss.failure.is_empty(), "uncorrected 4,200 km flyby yields no usable images")
	var impact = transfer.new(build, build.stats, orbit)
	impact.advance(transfer.PARKING_S)
	impact.advance(transfer.END_S)
	check(impact.apply_correction(53.0, false), "an excessive correction can be executed")
	impact.navigation_open = false
	impact.advance(transfer.END_S)
	impact.advance(transfer.END_S)
	check(impact.finished and impact.failure.contains("impacted the Moon") and not impact.corridor_met(), "closest approach under 50 km fails on impact")
	var powerless_stats: Dictionary = build.stats.duplicate()
	powerless_stats.battery_wh = 1.0
	powerless_stats.net_power_w = -61.0
	var powerless = transfer.new(build, powerless_stats, orbit)
	powerless.advance(transfer.PARKING_S)
	powerless.advance(transfer.END_S)
	check(powerless.finished and not powerless.link_active() and powerless.elapsed < transfer.NAVIGATION_S, "battery depletion fails before a later waypoint at high warp")

	manager.completed_missions.assign([1, 2, 3, 4])
	manager.unlocked_tier = 3
	manager.debug_disable_reliability = true
	check(manager.start_mission(5) and not manager.attempt_is_archive and not manager.is_mission_unlocked(7), "campaign unlocks Mission 5 after Mission 4")
	manager.current_build = build
	change_scene_to_file("res://scenes/Launch.tscn")
	await scene_changed
	launch = current_scene
	launch.set_process(false)
	launch.toggle_scripted_flight()
	launch.advance_ascent(20001.0)
	if not launch.finished or not launch._ascent.target_reached():
		check(false, "Vega-C reaches its 250 km parking orbit")
		finish(manager)
		return
	await scene_changed
	lunar = current_scene
	lunar.set_process(false)
	check(lunar.flight != null and absf(manager.initial_orbit.semi_major_axis_km - 6621.0) < 25.0, "campaign launch hands off to lunar operations")
	lunar.advance_time(transfer.PARKING_S)
	lunar.advance_time(transfer.END_S)
	lunar._amount.value = 47.0
	lunar._burn.pressed.emit()
	lunar.resume_cruise()
	lunar.advance_time(transfer.END_S)
	lunar.advance_time(transfer.END_S)
	lunar.advance_time(transfer.END_S)
	lunar.advance_time(transfer.END_S)
	lunar.advance_time(transfer.END_S)
	lunar._hud.skip_mission_button.pressed.emit()
	await scene_changed
	var receipt: Dictionary = manager.last_receipt
	check(receipt.outcome == "Success" and receipt.funds_millions == 105.0 and receipt.science_points >= 80, "campaign debrief pays Mission 5 rewards")
	check(manager.unlocked_tier == 4 and manager.is_mission_unlocked(7), "Mission 5 opens Tier 4 and unlocks Mission 7")
	finish(manager)

func finish(manager) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.save_path))
	print("Lunar flyby failures: ", failures)
	quit(1 if failures else 0)
