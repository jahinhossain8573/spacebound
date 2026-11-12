extends SceneTree

const PHYSICS = preload("res://scripts/AscentSim.gd")
const SETTINGS = preload("res://scripts/FlightPreferences.gd")
const LIVE_ASCENT = preload("res://scripts/LiveAscent.gd")

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
	var launch_origin := launch._station.find_child("launch_origin", true, false) as Node3D
	check(launch_origin != null and launch_origin.global_position.is_equal_approx(launch._rocket.global_position), "rocket starts on the LC-39A launch marker")
	var patches: Array[MeshInstance3D] = launch._earth._patches
	check(patches.size() == 20 and patches.any(func(patch: MeshInstance3D) -> bool: return not patch.visible), "pad camera culls far-side Earth patches")
	var pad_camera: Transform3D = launch._camera.global_transform
	var ground_material: ShaderMaterial = launch._pad_rig.ground_material
	check(is_equal_approx(float(ground_material.get_shader_parameter("local_detail")), 1.0), "pad shows full local ground detail")
	launch._camera.position = Vector3(0.0, 7000.0, 0.0)
	launch.update_world_visibility()
	var detail := float(ground_material.get_shader_parameter("local_detail"))
	var globe_material: ShaderMaterial = patches[0].material_override
	check(launch._pad_rig.ground.visible and detail > 0.0 and detail < 1.0
		and is_equal_approx(detail, float(globe_material.get_shader_parameter("local_detail"))),
		"ground and globe share the same detail blend")
	launch._camera.position = Vector3(0.0, 9400.0, 0.0)
	launch.update_world_visibility()
	check(not launch._pad_rig.ground.visible and float(globe_material.get_shader_parameter("local_detail")) > 0.0,
		"local texture stays on the globe after the ground mesh disappears")
	launch._camera.position = Vector3(0.0, 20000.0, 0.0)
	launch.update_world_visibility()
	check(not launch._station.visible, "camera distance hides Kennedy scenery")
	launch._camera.global_transform = pad_camera
	launch.update_world_visibility()
	check(launch._station.visible, "Kennedy scenery returns when the camera moves closer")
	check(launch._payload != null and launch._payload.get_parent().name == "payload_mount", "spacecraft rides on the Electron payload mount")
	check(launch._payload.get_node("mount_front").global_position.y > launch._payload.global_position.y + 0.1, "spacecraft front end faces away from the adapter")
	check(launch._stage.get_node_or_null("stage_1") != null and launch._stage.get_node_or_null("interstage") != null and launch._fairing_left.name == "fairing_left", "model sections drive staging")
	check(is_equal_approx(launch.calculate_reliability(0.95,["L7","L8","L9"]),0.99), "reliability capped")
	check(is_equal_approx(launch.calculate_reliability(0.88,["L7","L9"]),0.92), "owned reliability nodes")
	manager.debug_disable_reliability = true
	var pad_transform: Transform3D = launch._camera.global_transform
	key(launch, KEY_M)
	check(launch._map_view and launch._map_marker.visible and launch._hud_overlay.map_readout.text.contains("Ap"), "M opens the launch map from the pad")
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	drag.relative = Vector2(64, -32)
	var earth_center: Vector3 = launch._earth_spin.global_position
	var before_pan: Vector2 = launch._camera.unproject_position(earth_center)
	launch._camera_input(drag)
	var map_pan: Vector3 = launch._map_pan
	var after_pan: Vector2 = launch._camera.unproject_position(earth_center)
	var map_view_size := Vector2(launch._launch_view.viewport.size)
	var control_delta: Vector2 = (after_pan - before_pan) * launch._launch_view.size / map_view_size
	check(control_delta.distance_to(drag.relative) < 1.0, "middle-drag pans the launch map in screen space")
	key(launch, KEY_M)
	check(not launch._map_view and launch._camera.global_transform.is_equal_approx(pad_transform), "M restores the flight camera")
	launch._start.pressed.emit()
	var id: String = manager.attempt_id
	check(launch.ignited and not launch._ascent.scripted and not launch.failed and manager.has_launched_once and not launch._skip.visible, "first launch uses manual controls")
	launch.ignite()
	check(manager.last_result.flight_log.size() == 1 and manager.attempt_id == id, "duplicate ignition ignored")
	launch.advance_ascent(4.0)
	launch._guidance_enabled = true
	var prior_pitch: float = launch._ascent.pitch
	var prior_fuel: float = launch._ascent.fuel
	key(launch, KEY_D, true)
	launch.advance_ascent(0.5, true)
	key(launch, KEY_D, true, false)
	check(launch._ascent.pitch < prior_pitch and launch._ascent.fuel < prior_fuel, "camera-right steering changes powered attitude and fuel")
	launch._hud_overlay.guidance_hold.button_pressed = true
	check(launch._ascent.hold, "steering hold follows the HUD target when enabled")
	key(launch, KEY_A, true)
	launch.advance_ascent(0.25, true)
	key(launch, KEY_A, true, false)
	check(not launch._ascent.hold and not launch._hud_overlay.guidance_hold.button_pressed, "manual steering releases hold")
	launch._hud_overlay.guidance_hold.button_pressed = true
	var flame: Node3D = launch._stage.get_node("Flame")
	fly_until(launch, func(): return launch._events_done.has("max_q"), 100.0)
	var rocket_axis: Vector3 = launch._rocket.global_transform.basis.y
	check(flame.visible and rocket_axis.angle_to(launch.local_frame().y) > deg_to_rad(5.0) and launch.craft_world_position().y > 5000.0 and launch._rocket.position == Vector3.ZERO, "gravity turn at Max-Q retains the floating origin")
	fly_until(launch, func(): return not launch._start.disabled, 110.0)
	check(not launch.stage_separated and not flame.visible and launch._start.text == "Separate booster", "fuel exhaustion stops thrust and leaves staging manual")
	launch._start.pressed.emit()
	check(launch.stage_separated and not launch.fairing_separated and launch._stage.get_parent() == launch._root3d, "lower-left button separates the booster")
	fly_until(launch, func(): return not launch._start.disabled, 10.0)
	launch._start.pressed.emit()
	launch.advance_ascent(0.2)
	check(launch._upper_flame.visible, "lower-left button ignites the upper stage")
	fly_until(launch, func(): return not launch._start.disabled, 120.0)
	launch._start.pressed.emit()
	check(launch.fairing_separated and not launch._station.visible, "lower-left button jettisons fairings above the atmosphere")
	key(launch, KEY_M)
	fly_until(launch, func(): return launch._ascent.guidance().begins_with("Cut thrust and coast"), 550.0, 0.05)
	key(launch, KEY_X)
	launch.advance_ascent(0.2)
	check(not launch._upper_flame.visible and launch._status.text.contains("COASTING"), "X cuts thrust from map view at the apoapsis cue")
	fly_until(launch, func(): return launch._ascent.guidance().begins_with("Burn prograde"), 3000.0, 1.0)
	launch.advance_ascent(6.0)
	check(launch._ascent.radial_speed < 0.0 and launch._hud_overlay.guidance_label.text.begins_with("Burn prograde"),
		"the live burn cue stays available just after apoapsis")
	key(launch, KEY_Z)
	fly_until(launch, func(): return launch._ascent.target_reached(), 15.0, 0.05)
	key(launch, KEY_X)
	fly_until(launch, func(): return not launch._start.disabled, 10.0)
	launch._start.pressed.emit()
	check(launch._payload.get_parent() == launch._rocket and launch.payload_separated(), "lower-left button deploys the payload from map view")
	check(launch.finished and manager.last_result.launched and manager.last_result.objectives[0].done and absf(manager.initial_orbit.semi_major_axis_km - 6771.0) < 25.0 and manager.flight_elapsed_s == launch.elapsed, "successful manual 400 km LEO handoff")
	var log_text := "\n".join(manager.last_result.flight_log)
	check(log_text.contains("Max-Q") and log_text.contains("Circularization burn at apogee") and log_text.contains("Payload separation"), "flight log follows the real sequence")
	var shared = launch._flight
	var rocket = launch._rocket
	var camera = launch._camera
	var position: Vector3 = launch.craft_world_position()
	var expected := Vector3(launch._ascent.px, launch._ascent.py - PHYSICS.R_EARTH, 0.0)
	check(position.distance_to(expected) < 2.0, "insertion matches the live ascent endpoint")
	check(shared._map_view and shared._map_pan == map_pan, "map stays open and keeps its pan after manual deployment")
	shared.toggle_map_view()
	shared._update_camera()
	var target: Vector3 = launch.focus_point()
	check(camera.position.distance_to(target + launch.camera_offset(shared._distance, shared._yaw, shared._pitch)) < 0.01, "orbit camera keeps the local horizon framing")
	check(shared != null and shared._view == launch._launch_view and shared._camera == camera and shared._shared_rocket == rocket, "orbit reuses launch world, spacecraft and camera")
	shared.advance_time(0.0)
	check(launch.craft_world_position().distance_to(position) < 2.0 and rocket.position == Vector3.ZERO, "insertion has no position jump")
	await create_timer(2.2).timeout
	var antenna := launch._payload.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(antenna.is_playing() and antenna.current_animation == "deploy", "antenna deploys after separation")
	check(is_instance_valid(shared._marker) and is_instance_valid(shared._camera), "shared world survives view replacement")
	shared.toggle_map_view()
	check(shared._map_view and patches.any(func(patch: MeshInstance3D) -> bool: return patch.visible) and patches.any(func(patch: MeshInstance3D) -> bool: return not patch.visible), "shared-world map keeps near Earth patches and culls the far side")
	shared.toggle_map_view()
	check(not shared._map_view, "shared-world third person restored")
	for altitude_km in [1656.0, 9168.0]:
		var high_orbit := OrbitState.new()
		high_orbit.semi_major_axis_km = PHYSICS.R_EARTH / 1000.0 + altitude_km
		shared.set_orbit(high_orbit)
		var center_distance: float = camera.global_position.distance_to(launch._earth.global_position)
		var limb_distance := sqrt(center_distance * center_distance - PHYSICS.R_EARTH * PHYSICS.R_EARTH)
		check(camera.far > limb_distance and camera.near <= 0.5, "ship camera covers Earth's limb at %.0f km altitude" % altitude_km)
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
	launch.advance_ascent(20001.0)
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
	var skipped_log := "\n".join(manager.last_result.flight_log)
	check(launch.finished and absf(manager.initial_orbit.semi_major_axis_km - 24392.5) < 10.0 and skipped_log.contains("Fairing separation") and skipped_log.contains("Payload separation") and not skipped_log.contains("Circularization"), "skip preserves milestones and GTO")
	launch.queue_free()
	await process_frame
	manager.start_mission(1)
	manager.current_build = make_build(manager, data, ["com_endurosat_uhf", "pwr_gomspace_p31u", "av_gomspace_a3200", "pwr_gomspace_bp4"], 0.0)
	launch = scene.instantiate()
	root.add_child(launch)
	launch.set_process(false)
	launch._start.pressed.emit()
	launch.advance_ascent(32.0)
	var before := state_at(launch)
	key(launch, KEY_G)
	check(launch._ascent.scripted and state_at(launch) == before, "G takes over a vertical ascent without resetting flight state")
	fly_until(launch, func(): return launch.stage_separated, 200.0, PHYSICS.STEP)
	check(launch.stage_separated and launch._stage.global_position.distance_to(launch._rocket.global_position) < 0.01,
		"scripted separation starts the booster at its attached position")
	launch.advance_ascent(PHYSICS.STEP)
	check((launch._stage.global_position - launch._rocket.global_position).dot(launch._rocket.global_basis.y) < 0.0,
		"the detached booster moves aft on the next physics step")
	fly_until(launch, func(): return launch._ascent.stage == 1 and launch._ascent.throttle == 0.0, 800.0)
	before = state_at(launch)
	key(launch, KEY_G)
	key(launch, KEY_G)
	check(launch._ascent.scripted and state_at(launch) == before, "G takeover during coast retains position, velocity, fuel and stage")
	launch.advance_ascent(20001.0)
	check(launch.finished and manager.last_result.objectives[0].done, "scripted recovery reaches the mission orbit")
	launch.queue_free()
	await process_frame

	var impacts: Array[Array] = []
	for warp in [1, 10]:
		manager.start_mission(1)
		manager.current_build = make_build(manager, data, ["com_endurosat_uhf", "pwr_gomspace_p31u", "av_gomspace_a3200", "pwr_gomspace_bp4"], 0.0)
		launch = scene.instantiate()
		root.add_child(launch)
		launch.set_process(false)
		launch._start.pressed.emit()
		launch.set_launch_warp(warp)
		key(launch, KEY_D, true)
		key(launch, KEY_S, true)
		while launch._failure_timer <= 0.0 and launch.elapsed < 150.0:
			launch._process(0.05)
		key(launch, KEY_D, true, false)
		key(launch, KEY_S, true, false)
		check(launch._ascent.failure.contains("impacted Earth") and launch._ascent.fuel > 0.0, "manual steering can drive the powered rocket into the ground at %dx" % warp)
		impacts.append(state_at(launch))
		launch.queue_free()
		await process_frame
	var same_impact := true
	for i in impacts[0].size():
		same_impact = same_impact and absf(float(impacts[0][i]) - float(impacts[1][i])) < 0.01
	check(same_impact, "1x and 10x steering reach the same impact state and simulated time")

	var mission: Dictionary = data.get_mission(1)
	var depleted := LIVE_ASCENT.new(data.get_launcher(mission.requiredLauncher).ascent, 50.0, mission)
	depleted.stage = 1
	depleted.clamped = false
	depleted.py += 10000.0
	depleted.vy = -1000.0
	depleted.fuel = 0.0
	depleted.scripted = true
	depleted.advance(PHYSICS.STEP, 0.0, 0.0)
	depleted.set_throttle(0.0)
	while depleted.failure.is_empty() and depleted.elapsed < 60.0:
		depleted.advance(PHYSICS.STEP, 0.0, 0.0)
	check(not depleted.deployed and depleted.fuel == 0.0 and depleted.failure.contains("impacted Earth"), "unrecoverable G takeover neither refuels nor grants insertion")

	var settings_path := "user://test-flight-settings-%d.cfg" % Time.get_ticks_usec()
	check(SETTINGS.guidance_enabled(settings_path), "flight guidance defaults on")
	check(SETTINGS.save_guidance(false, settings_path) == OK and not SETTINGS.guidance_enabled(settings_path), "flight guidance preference persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))

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

func key(launch, code: Key, physical := false, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	if physical:
		event.physical_keycode = code
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	else:
		launch._unhandled_key_input(event)

func fly_until(launch, condition: Callable, timeout: float, step := 0.25) -> void:
	var time_limit: float = launch.elapsed + timeout
	while not condition.call() and not launch.finished and launch._failure_timer <= 0.0 and launch.elapsed < time_limit:
		launch.advance_ascent(step)

func state_at(launch) -> Array:
	var sim = launch._ascent
	return [sim.elapsed, sim.px, sim.py, sim.vx, sim.vy, sim.fuel, sim.stage, sim.pitch]

func make_build(manager: Node, data: Node, ids: Array, fuel: float) -> Dictionary:
	var parts: Array = []
	for id in ids: parts.append(data.get_part(id))
	var m: Dictionary = manager.current_mission
	return {"launcher":data.get_launcher(m.requiredLauncher), "bus":data.get_bus(m.requiredBus), "installed_components":parts, "propellant_mass_kg":fuel, "stats":{}}
