extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func run_tests() -> void:
	root.get_node("EventManager").random_enabled = false
	var manager := root.get_node("GameManager")
	var data := root.get_node("GlobalData")
	manager.save_path = "user://spa13-test-%d.json" % Time.get_ticks_usec()
	manager.new_campaign()
	var scene: PackedScene = load("res://scenes/Launch.tscn")
	manager.start_mission(1)
	manager.current_build = make_build(manager, data, ["com_endurosat_uhf", "pwr_gomspace_p31u", "av_gomspace_a3200", "pwr_gomspace_bp4"], 0.0)
	var launch = scene.instantiate()
	root.add_child(launch)
	launch.set_process(false)
	check(launch._payload != null and launch._payload.get_parent().name == "payload_mount", "spacecraft rides on the Electron payload mount")
	check(launch._stage.get_node_or_null("stage_1") != null and launch._stage.get_node_or_null("interstage") != null and launch._fairing_left.name == "fairing_left", "model sections drive staging")
	check(is_equal_approx(launch.calculate_reliability(0.95,["L7","L8","L9"]),0.99), "reliability capped")
	check(is_equal_approx(launch.calculate_reliability(0.88,["L7","L9"]),0.92), "owned reliability nodes")
	manager.debug_disable_reliability = true
	launch.ignite()
	var id: String = manager.attempt_id
	check(launch.ignited and not launch.failed and manager.has_launched_once and not launch._skip.visible, "first liftoff cannot skip")
	launch.ignite()
	check(manager.last_result.flight_log.size() == 1 and manager.attempt_id == id, "duplicate ignition ignored")
	launch.advance_ascent(6.0)
	check(launch.stage_separated and not launch.fairing_separated, "stage at 40 percent")
	launch.advance_ascent(3.0)
	check(launch.fairing_separated and manager.last_result.flight_log.size() == 3, "fairing at 60 percent")
	check(not launch._station.visible, "station disappears during ascent")
	launch.advance_ascent(6.0)
	check(launch.finished and manager.last_result.launched and manager.last_result.objectives[0].done and manager.initial_orbit.semi_major_axis_km == 6771.0 and manager.flight_elapsed_s == 15.0, "successful LEO handoff")
	var antenna := launch._payload.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(antenna.is_playing() and antenna.current_animation == "deploy", "antenna deploys at orbit insertion")
	var shared = launch._flight
	var rocket = launch._rocket
	var camera = launch._camera
	var position: Vector3 = rocket.position
	var expected := Vector3(6771000.0 * sin(0.02), 6771000.0 * cos(0.02) - 6371000.0, 0)
	check(position.distance_to(expected) < 2.0, "insertion matches ascent endpoint")
	var target: Vector3 = launch.focus_point()
	var camera_offset: Vector3 = Vector3(sin(launch._camera_yaw)*cos(launch._camera_pitch),sin(launch._camera_pitch),cos(launch._camera_yaw)*cos(launch._camera_pitch)) * launch.rocket_height * launch._camera_distance
	check(camera.position.distance_to(target + camera_offset) < 2.0, "camera retains ascent framing")
	check(shared != null and shared._view == launch._launch_view and shared._camera == camera and shared._shared_rocket == rocket, "orbit reuses launch world, spacecraft and camera")
	shared.advance_time(0.0)
	check(rocket.position.distance_to(position) < 2.0, "insertion has no position jump")
	await process_frame
	check(is_instance_valid(shared._marker) and is_instance_valid(shared._camera), "shared world survives view replacement")
	shared.toggle_map_view()
	check(shared._map_view, "shared-world map view available")
	shared.toggle_map_view()
	check(not shared._map_view, "shared-world third person restored")
	launch.queue_free()
	await process_frame
	check(manager.load_campaign() == OK and manager.has_launched_once, "first launch flag persisted")
	manager.start_mission(1)
	manager.current_build = make_build(manager, data, ["com_endurosat_uhf", "pwr_gomspace_p31u", "av_gomspace_a3200", "pwr_gomspace_bp4"], 0.0)
	launch = scene.instantiate()
	root.add_child(launch)
	launch.set_process(false)
	manager.debug_disable_reliability = false
	manager.debug_force_launch_failure = true
	launch.ignite()
	check(launch.failed and launch.can_skip and launch._skip.disabled, "failure unskippable")
	launch.skip_ascent()
	check(launch.elapsed == 0.0 and not launch.finished, "skip cannot bypass failure")
	launch.advance_ascent(15.0)
	check(launch._failure_timer > 0 and not manager.last_result.launched, "failure effect and result")
	var debrief = load("res://scenes/Debrief.tscn").instantiate()
	root.add_child(debrief)
	var receipt: Dictionary = manager.last_receipt
	check(receipt.outcome == "Mission Loss" and receipt.science_points == 7, "failure bonus and debrief settlement")
	debrief.queue_free()
	launch.queue_free()
	await process_frame
	manager.debug_force_launch_failure = false
	manager.debug_disable_reliability = false
	manager.start_mission(1)
	manager.current_build = make_build(manager, data, ["com_endurosat_uhf", "pwr_gomspace_p31u", "av_gomspace_a3200", "pwr_gomspace_bp4"], 0.0)
	launch = scene.instantiate()
	root.add_child(launch)
	launch.set_process(false)
	launch.rng.seed = 1357
	launch.ignite()
	var seeded_failure: bool = launch.failed
	var seeded_point: float = launch.failure_at
	launch.queue_free()
	await process_frame
	launch = scene.instantiate()
	root.add_child(launch)
	launch.set_process(false)
	launch.rng.seed = 1357
	launch.ignite()
	check(launch.failed == seeded_failure and launch.failure_at == seeded_point, "seeded reliability outcome reproducible")
	launch.queue_free()
	await process_frame
	manager.debug_disable_reliability = true
	manager.debug_unlock_missions = true
	manager.start_mission(4)
	manager.current_build = make_build(manager, data, ["inst_kuka_transponder_suite", "prop_aerojet_r4d15", "av_bae_rad750", "pwr_airbus_l", "pwr_eaglepicher_l"], 400.0)
	launch = scene.instantiate()
	root.add_child(launch)
	launch.set_process(false)
	launch.ignite()
	check(launch.rocket_height == 70.0 and launch._skip.visible and not launch._skip.disabled, "subsequent Falcon launch skippable")
	launch.skip_ascent()
	check(launch.finished and absf(manager.initial_orbit.semi_major_axis_km - 24392.5) < 0.001 and manager.last_result.flight_log.size() == 4, "skip preserves milestones and GTO")
	launch.queue_free()
	await process_frame
	var f := FileAccess.open(manager.save_path,FileAccess.READ)
	var old: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	old.erase("has_launched_once")
	f = FileAccess.open(manager.save_path,FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	check(manager.load_campaign() == OK and not manager.has_launched_once, "old save defaults launch flag")
	manager.new_campaign()
	check(not manager.has_launched_once, "new campaign resets launch flag")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.save_path))
	print("Launch failures: ",failures)
	quit(1 if failures else 0)

func make_build(manager: Node, data: Node, ids: Array, fuel: float) -> Dictionary:
	var parts: Array = []
	for id in ids: parts.append(data.get_part(id))
	var m: Dictionary = manager.current_mission
	return {"launcher":data.get_launcher(m.requiredLauncher), "bus":data.get_bus(m.requiredBus), "installed_components":parts, "propellant_mass_kg":fuel, "stats":{}}
