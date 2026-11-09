extends Control

const MISSION_OBJECTIVES = preload("res://scripts/MissionObjectives.gd")
const WARP_LEVELS := [1, 10, 100, 1000]
var orbit: OrbitState
var mission: Dictionary = {}
var mission_elapsed_s: float = 0.0
var _observation_start_s := 0.0
var warp: int = 1
var position_km := Vector2.ZERO
var altitude_km := 0.0
var speed_kms := 0.0
var in_eclipse := false
var _plotter
var _marker: MeshInstance3D
var _camera: Camera3D
var _view: SubViewportContainer
var _hud: Label
var _error: Label
var _yaw := 0.55
var _pitch := 0.65
var _distance := 190.0
var _camera_mode := "Spacecraft"
var _map_view := false
var _ship_camera := Vector3(0.55, 0.65, 0.18)
var _map_camera := Vector3(0.55, 0.65, 190.0)
var _craft_visual: Node3D
var _map_button: Button
var _dragging := false
var battery_capacity_wh := 0.0
var battery_charge_wh := 0.0
var battery_lowest_pct := 100.0
var generation_w := 0.0
var draw_w := 0.0
var power_active := false
var power_failed := false
var mission_finished := false
var _battery_bar: ProgressBar
var _battery_label: Label
var _skip_button: Button
var _skip_result: Dictionary = {}
var _skip_pending := false
var _skip_animation := 0.0
var _skip_start := 0.0
var _skip_remaining := 0.0
var _failure_delay := 0.0
var _flash_clock := 0.0
var _sunlit_pass_started := false
var _objective_label: Label
var _beacon_label: Label
var _skip_beacon_at := -1.0
var images_captured := 0
var _images_label: Label
var _skip_image_first_s := -1.0
var _skip_image_period_s := 0.0
var _skip_image_base := 0
var _extension_checked := false
var _wait_target := -1.0
var _burn_panel: VBoxContainer
var remaining_propellant_kg := 0.0
var shared_launch: Control
var _shared_rocket: Node3D
var _shared_center := Vector3(0, -6371000.0, 0)
const SHARED_SCALE := 1000.0 / FlightSim.RENDER_SCALE

func _ready() -> void:
	GameManager.state = GameManager.State.FLIGHT_OPS
	mission_elapsed_s = GameManager.flight_elapsed_s
	_observation_start_s = mission_elapsed_s
	mission = GameManager.current_mission if not GameManager.current_mission.is_empty() else GlobalData.get_mission(1)
	_build_scene()
	if mission.get("targetOrbit", "") not in ["LEO", "SSO", "GEO", "GTO"]:
		_error.text = "This mission needs its own lunar flight scene. Use Back to return."
		return
	if GameManager.initial_orbit != null:
		set_orbit(GameManager.initial_orbit)
	else:
		var initial := OrbitState.new()
		match mission.get("targetOrbit", ""):
			"LEO", "SSO": initial.semi_major_axis_km = FlightSim.R_EARTH_KM + float(mission.targetAltitudeKm)
			"GEO", "GTO":
				initial.semi_major_axis_km = (6621.0 + 42164.0) / 2.0
				initial.eccentricity = (42164.0 - 6621.0) / (42164.0 + 6621.0)
			_:
				_error.text = "This mission needs its own lunar flight scene. Use Back to return."
				return
		set_orbit(initial)
	_initialize_power()
	_update_mission_objectives()
	_burn_panel = load("res://scenes/ui/BurnPanel.tscn").instantiate()
	_view.get_parent().add_child(_burn_panel)
	_view.get_parent().move_child(_burn_panel, _view.get_index())
	_burn_panel.setup(self)
	EventManager.register_flight(self)
	if power_active:
		EventManager.roll_trigger("arrival")
		EventManager.trigger_mission_event()
	if shared_launch == null and GameManager.initial_orbit != null and GameManager.flight_elapsed_s > 0:
		var fade := ColorRect.new()
		fade.color = Color.BLACK
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fade)
		var tween := create_tween()
		tween.tween_property(fade, "modulate:a", 0.0, 1.0)
		tween.tween_callback(fade.queue_free)

func _build_scene() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	_add_button(buttons, "< Back", func(): get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn"))
	for level in WARP_LEVELS:
		_add_button(buttons, "%dx" % level, set_warp.bind(level))
	_map_button = Button.new()
	_map_button.text = "Map view (M)"
	_map_button.pressed.connect(toggle_map_view)
	buttons.add_child(_map_button)
	_add_button(buttons, "Reset view", _reset_view)
	_hud = Label.new()
	_hud.add_theme_color_override("font_color", Color("00e5ff"))
	layout.add_child(_hud)
	_objective_label = Label.new()
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_objective_label)
	_images_label = Label.new()
	_images_label.visible = false
	layout.add_child(_images_label)
	_beacon_label = Label.new()
	_beacon_label.add_theme_color_override("font_color", Color("00e5ff"))
	layout.add_child(_beacon_label)
	_battery_label = Label.new()
	layout.add_child(_battery_label)
	_battery_bar = ProgressBar.new()
	_battery_bar.custom_minimum_size.y = 22
	layout.add_child(_battery_bar)
	_skip_button = Button.new()
	_skip_button.text = "Skip mission time"
	_skip_button.pressed.connect(skip_mission_time)
	layout.add_child(_skip_button)
	_error = Label.new()
	_error.add_theme_color_override("font_color", Color("ff4d4d"))
	layout.add_child(_error)
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.focus_mode = Control.FOCUS_ALL
	_view.gui_input.connect(_view_input)
	layout.add_child(_view)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0b0e14")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("1a2640")
	environment.environment.ambient_light_energy = 0.5
	world.add_child(environment)
	var earth := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 50.0
	sphere.height = 100.0
	sphere.rings = 32
	earth.mesh = sphere
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color("2462b3")
	blue.roughness = 0.8
	earth.material_override = blue
	world.add_child(earth)
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.look_at(Vector3.LEFT, Vector3.UP)
	_plotter = preload("res://scripts/OrbitPlotter.gd").new()
	world.add_child(_plotter)
	_plotter.visible = false
	_marker = MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.5
	marker_mesh.height = 1.0
	_marker.mesh = marker_mesh
	var cyan := StandardMaterial3D.new()
	cyan.albedo_color = Color("00e5ff")
	cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = cyan
	_marker.visible = false
	world.add_child(_marker)
	_craft_visual = Node3D.new()
	world.add_child(_craft_visual)
	var craft := MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(0.03, 0.03, 0.03)
	craft.mesh = body
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("d7e2ed")
	craft.material_override = white
	_craft_visual.add_child(craft)
	for side in [-1, 1]:
		var wing := MeshInstance3D.new()
		var panel := BoxMesh.new()
		panel.size = Vector3(0.04, 0.018, 0.002)
		wing.mesh = panel
		wing.position.x = side * 0.035
		var solar := StandardMaterial3D.new()
		solar.albedo_color = Color("235899")
		wing.material_override = solar
		_craft_visual.add_child(wing)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 10000.0
	world.add_child(_camera)

func _add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func set_orbit(value: OrbitState) -> bool:
	if value == null or not value.is_valid():
		orbit = null
		_marker.visible = false
		_plotter.redraw(null)
		_error.text = "Invalid orbit: use a finite, bound ellipse with positive radius and gravitational parameter."
		return false
	var period: float = FlightSim.orbital_period_s(value.semi_major_axis_km, value.mu)
	if not is_finite(period) or period <= 0.0:
		_error.text = "Invalid orbital period."
		orbit = null
		_marker.visible = false
		_plotter.redraw(null)
		return false
	var initial_orbit := orbit == null
	orbit = value.copy()
	orbit.time_since_periapsis_s = fposmod(orbit.time_since_periapsis_s, period)
	_error.text = ""
	_marker.visible = true
	_plotter.redraw(orbit)
	_update_position()
	if initial_orbit: set_camera_preset(_camera_mode)
	else: _update_camera()
	return true

func set_warp(value: int) -> void:
	if EventManager.blocking: return
	if value in WARP_LEVELS: warp = value

func _mission_end_s() -> float:
	return float(mission.durationDays) * 86400.0 + (_observation_start_s if mission.get("durationStartsAtOrbit", false) else 0.0)

func advance_time(real_delta_s: float) -> void:
	if EventManager.blocking or mission_finished or power_failed or not _skip_result.is_empty() or orbit == null or not is_finite(real_delta_s) or real_delta_s < 0.0: return
	var elapsed := real_delta_s * warp
	if _wait_target >= 0.0:
		var wait_period: float = FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu)
		var until := fposmod(_wait_target - orbit.time_since_periapsis_s, wait_period)
		if elapsed >= until:
			elapsed = until
			_wait_target = -1.0
			warp = 1
	if power_active:
		var remaining := minf(elapsed, maxf(0.0, _mission_end_s() - mission_elapsed_s))
		var period_s: float = FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu)
		var fraction := _eclipse_fraction()
		var result: Dictionary = FlightSim.simulate_mission_skip(remaining, period_s, fraction, generation_w, draw_w, battery_capacity_wh, battery_charge_wh, _sun_phase(period_s, fraction), _sunlit_pass_started)
		var before := mission_elapsed_s
		mission_elapsed_s += result.elapsed_s
		orbit.time_since_periapsis_s = fposmod(orbit.time_since_periapsis_s + result.elapsed_s, period_s)
		battery_charge_wh = result.end_wh
		_sunlit_pass_started = result.pass_started
		battery_lowest_pct = minf(battery_lowest_pct, result.lowest_wh / battery_capacity_wh * 100.0 if battery_capacity_wh > 0 else 0.0)
		GameManager.last_result["battery_lowest_pct"] = battery_lowest_pct
		if result.sunlit_pass_completed_s >= 0.0:
			_award_beacon(before + result.sunlit_pass_completed_s)
			_apply_image_passes(images_captured, before + result.sunlit_pass_completed_s, mission_elapsed_s, period_s)
		if not result.survived: _power_failure("POWER FAILURE")
		_update_position()
		_update_mission_objectives()
		if not power_failed and mission_elapsed_s >= _mission_end_s(): _complete_duration()
		return
	mission_elapsed_s += elapsed
	var period: float = FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu)
	orbit.time_since_periapsis_s = fposmod(orbit.time_since_periapsis_s + elapsed, period)
	_update_position()

func _process(delta: float) -> void:
	if EventManager.blocking: return
	_flash_clock += delta
	if _failure_delay > 0.0:
		_failure_delay -= delta
		if _failure_delay <= 0.0: _open_debrief()
	elif not _skip_result.is_empty():
		_skip_animation += delta
		mission_elapsed_s = _skip_start + _skip_result.elapsed_s * minf(1.0, _skip_animation / 3.0)
		if _skip_image_first_s >= 0.0:
			_apply_image_passes(_skip_image_base, _skip_image_first_s, mission_elapsed_s, _skip_image_period_s)
		if _skip_beacon_at >= 0.0 and mission_elapsed_s >= _skip_beacon_at:
			_award_beacon(_skip_beacon_at)
			_skip_beacon_at = -1.0
		_update_position()
		if _skip_animation >= 3.0:
			battery_charge_wh = _skip_result.end_wh
			if _skip_result.survived: _complete_duration()
			else: _power_failure("Battery depleted on orbit %d" % _skip_result.failed_orbit)
	else:
		advance_time(delta)
	_update_battery_hud()
	_update_mission_objectives()
	_update_objectives()
	if is_instance_valid(_burn_panel): _burn_panel.refresh()
	if orbit != null:
		_update_camera()
		var pixels := maxf(1.0, float(_view.size.y))
		var diameter := 8.0 * 2.0 * _camera.global_position.distance_to(_marker.global_position) * tan(deg_to_rad(_camera.fov) * 0.5) / pixels
		_marker.scale = Vector3.ONE * maxf(0.5, diameter) if _map_view else Vector3.ONE
		_marker.visible = _map_view
		_craft_visual.visible = not _map_view and shared_launch == null
		_craft_visual.position = _marker.position

func _update_position() -> void:
	var pos: Vector2 = FlightSim.position_on_orbit_km(orbit.semi_major_axis_km, orbit.eccentricity, orbit.time_since_periapsis_s, orbit.mu)
	position_km = pos.rotated(orbit.arg_periapsis_rad)
	_marker.position = Vector3(position_km.x, 0.0, position_km.y) * FlightSim.RENDER_SCALE
	if is_instance_valid(_shared_rocket):
		_marker.position = Vector3(position_km.y * 1000.0, position_km.x * 1000.0 - 6371000.0, 0)
		_shared_rocket.position = _marker.position
	var radius := float(position_km.length())
	altitude_km = radius - FlightSim.R_EARTH_KM
	speed_kms = FlightSim.speed_at_radius_kms(radius, orbit.semi_major_axis_km, orbit.mu)
	in_eclipse = is_in_eclipse(position_km)
	var periapsis := orbit.semi_major_axis_km * (1.0 - orbit.eccentricity) - FlightSim.R_EARTH_KM
	var apoapsis := orbit.semi_major_axis_km * (1.0 + orbit.eccentricity) - FlightSim.R_EARTH_KM
	var name: String = "Sun-synchronous, 98° inclination (planar simulation)" if mission.get("targetOrbit", "") == "SSO" else str(mission.get("title", "Orbit preview"))
	_hud.text = "%s\nElapsed %.1f s  |  Altitude %.1f km  |  Speed %.3f km/s\nPeriapsis %.1f km  |  Apoapsis %.1f km  |  Period %.1f s  |  %dx  |  %s" % [name, mission_elapsed_s, altitude_km, speed_kms, periapsis, apoapsis, FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu), warp, "ECLIPSE" if in_eclipse else "SUNLIGHT"]

func is_in_eclipse(pos_km: Vector2) -> bool:
	return pos_km.x < 0.0 and absf(pos_km.y) < FlightSim.R_EARTH_KM

func toggle_map_view() -> void:
	if orbit == null: return
	if _map_view:
		_map_camera = Vector3(_yaw, _pitch, _distance)
		_yaw = _ship_camera.x
		_pitch = _ship_camera.y
		_distance = _ship_camera.z
		_camera_mode = "Spacecraft"
	else:
		_ship_camera = Vector3(_yaw, _pitch, _distance)
		_yaw = _map_camera.x
		_pitch = _map_camera.y
		_distance = _map_camera.z
		_camera_mode = "Earth"
	_map_view = not _map_view
	_plotter.visible = _map_view
	_map_button.text = "Flight view (M)" if _map_view else "Map view (M)"
	_update_camera()

func set_camera_preset(value: String) -> void:
	if orbit == null: return
	_camera_mode = value
	_distance = (shared_launch.rocket_height * 1.9 if is_instance_valid(shared_launch) else 0.18) if value == "Spacecraft" else (190.0 * SHARED_SCALE if is_instance_valid(shared_launch) else 190.0)
	if value == "Wide":
		_distance = maxf(190.0, orbit.semi_major_axis_km * (1.0 + orbit.eccentricity) * FlightSim.RENDER_SCALE * 3.2)
	_update_camera()

func _update_camera() -> void:
	if is_instance_valid(_shared_rocket):
		_camera.near = 1000.0 if _map_view else 0.5
		_camera.far = 100000000.0 if _map_view else 2000000.0
	var target := _marker.position if _camera_mode == "Spacecraft" else Vector3.ZERO
	if is_instance_valid(_shared_rocket):
		target = _shared_rocket.position + Vector3(0, shared_launch.rocket_height * 0.5, 0) if _camera_mode == "Spacecraft" else _shared_center
	_camera.position = target + Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch)) * _distance
	_camera.look_at(target, Vector3.UP)

func _reset_view() -> void:
	_yaw = 0.55
	_pitch = 0.65
	set_camera_preset(_camera_mode)

func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed: _view.grab_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT: _dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 5.0 if shared_launch != null else 0.06, 100000000.0 if shared_launch != null else 5000.0)
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch + event.relative.y * 0.01, -1.4, 1.4)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: _yaw -= 0.1
			KEY_RIGHT: _yaw += 0.1
			KEY_UP: _pitch = maxf(-1.4, _pitch - 0.1)
			KEY_DOWN: _pitch = minf(1.4, _pitch + 0.1)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: _distance = maxf(0.06, _distance * 0.9)
			KEY_MINUS, KEY_KP_SUBTRACT: _distance = minf(5000.0, _distance * 1.1)

func _input(event: InputEvent) -> void:
	if EventManager.blocking: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M: toggle_map_view()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed: _dragging = false

func _initialize_power() -> void:
	power_active = orbit != null and not GameManager.current_build.is_empty() and not GameManager.attempt_id.is_empty() and not GameManager.last_result.is_empty()
	if power_active:
		var stats: Dictionary = preload("res://scripts/BuildStats.gd").new().calculate_stats(GameManager.current_build, mission)
		generation_w = stats.generation_w
		draw_w = stats.draw_w
		battery_capacity_wh = stats.battery_wh
		battery_charge_wh = battery_capacity_wh
	_update_battery_hud()

func _track_battery() -> void:
	var pct := battery_charge_wh / battery_capacity_wh * 100.0 if battery_capacity_wh > 0.0 else 0.0
	battery_lowest_pct = minf(battery_lowest_pct, pct)
	GameManager.last_result["battery_lowest_pct"] = battery_lowest_pct

func can_skip_mission() -> bool:
	if not power_active or power_failed or mission_finished or orbit == null or _skip_pending or not _skip_result.is_empty(): return false
	if mission.get("targetOrbit", "") in ["GEO", "GTO"]:
		return MISSION_OBJECTIVES.circularize(orbit, 42164.0)
	return mission.get("targetOrbit", "") in ["LEO", "SSO"]

func skip_mission_time() -> void:
	if not can_skip_mission(): return
	_skip_pending = true
	_skip_start = mission_elapsed_s
	_skip_remaining = maxf(0.0, _mission_end_s() - mission_elapsed_s)
	# Notify event listeners before reading power totals and computing the result.
	GameManager.mission_skip_started.emit(_skip_remaining)
	if EventManager.blocking:
		EventManager.queue_finished.connect(_continue_skip, CONNECT_ONE_SHOT)
		return
	_continue_skip()

func _continue_skip() -> void:
	if power_failed or mission_finished: return
	var period: float = FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu)
	var fraction := _eclipse_fraction()
	_skip_result = FlightSim.simulate_mission_skip(_skip_remaining, period, fraction, generation_w, draw_w, battery_capacity_wh, battery_charge_wh, _sun_phase(period, fraction), _sunlit_pass_started)
	if _skip_result.sunlit_pass_completed_s >= 0.0:
		_skip_beacon_at = _skip_start + _skip_result.sunlit_pass_completed_s
		_skip_image_first_s = _skip_beacon_at
		_skip_image_period_s = period
		_skip_image_base = images_captured
	battery_lowest_pct = minf(battery_lowest_pct, _skip_result.lowest_wh / battery_capacity_wh * 100.0 if battery_capacity_wh > 0 else 0.0)
	GameManager.last_result["battery_lowest_pct"] = battery_lowest_pct
	_skip_animation = 0.0

func _update_battery_hud() -> void:
	if _battery_bar == null: return
	var pct := battery_charge_wh / battery_capacity_wh * 100.0 if battery_capacity_wh > 0 else 0.0
	if not _skip_result.is_empty(): pct = battery_lowest_pct
	_battery_bar.value = pct
	var low := pct < 15.0
	_battery_bar.modulate = Color("ff4d4d") if low and fmod(_flash_clock, 0.7) < 0.35 else Color.WHITE
	_battery_label.text = ("LOW BATTERY  " if low and power_active else "") + ("Battery %.1f%% (%.1f / %.1f Wh)" % [pct, battery_charge_wh, battery_capacity_wh] if power_active else "Battery unavailable in orbit preview")
	if not _skip_result.is_empty():
		_battery_label.text = "Simulated minimum battery: %.1f%%" % battery_lowest_pct
	_skip_button.disabled = not can_skip_mission()
	_skip_button.tooltip_text = "Reach circular GEO before skipping." if mission.get("targetOrbit", "") in ["GEO", "GTO"] else "Complete the mission duration using the current battery charge."

func _power_failure(message: String) -> void:
	if power_failed or mission_finished: return
	power_failed = true
	_error.text = message
	_failure_delay = 3.0
	_set_objective("Survive mission duration", false)
	GameManager.last_result.flight_log.append("T+%.1fs %s" % [mission_elapsed_s, message])

func _set_objective(name: String, done: bool) -> void:
	for objective in GameManager.last_result.get("objectives", []):
		if objective.get("name", "") == name: objective.done = done

func _complete_duration() -> void:
	if mission_finished: return
	if not _extension_checked:
		_extension_checked = true
		EventManager.roll_extension()
		if EventManager.blocking:
			EventManager.queue_finished.connect(_complete_duration, CONNECT_ONE_SHOT)
			return
	mission_finished = true
	_set_objective("Survive mission duration", MISSION_OBJECTIVES.survive(true))
	if not GameManager.last_result.get("optical_objective_blocked", false): _set_objective("Mission objective", true)
	_update_mission_objectives()
	GameManager.last_result.flight_log.append("T+%.1fs Mission duration completed" % mission_elapsed_s)
	_open_debrief()

func _open_debrief() -> void:
	set_process(false)
	if not DisplayServer.get_name() == "headless":
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Debrief.tscn")

func activate_shared_world(view: SubViewportContainer, world: Node3D, rocket: Node3D, camera: Camera3D, camera_transform: Transform3D, yaw: float, pitch: float, distance: float) -> void:
	var old_view := _view
	var parent := old_view.get_parent()
	var index := old_view.get_index()
	_view = view
	view.reparent(parent)
	parent.move_child(view, index)
	old_view.queue_free()
	_camera = camera
	_shared_rocket = rocket
	_yaw = yaw
	_pitch = pitch
	_distance = distance
	_ship_camera = Vector3(yaw, pitch, distance)
	_map_camera = Vector3(yaw, pitch, 190.0 * SHARED_SCALE)
	view.gui_input.disconnect(shared_launch._camera_input)
	view.gui_input.connect(_view_input)
	_marker.reparent(world)
	_craft_visual.reparent(world)
	_plotter.reparent(world)
	_plotter.transform = Transform3D(Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT).scaled(Vector3.ONE * SHARED_SCALE), _shared_center)
	_update_position()
	_camera.global_transform = camera_transform

func _eclipse_fraction() -> float:
	return 72.0 / 1436.0 if mission.get("targetOrbit", "") in ["GEO", "GTO"] else FlightSim.eclipse_fraction(orbit.semi_major_axis_km)

func _sun_phase(period: float, fraction: float) -> float:
	return fposmod(orbit.time_since_periapsis_s + orbit.arg_periapsis_rad / TAU * period - period * (0.5 + fraction * 0.5), period)

func _award_beacon(at: float) -> void:
	for definition in mission.get("objectives", []):
		if definition.trigger != "sunlit_pass": continue
		var found := false
		for part in GameManager.current_build.get("installed_components", []):
			if part.get("id", "") == definition.requiredPartId: found = true
		if not found: continue
		for objective in GameManager.last_result.get("objectives", []):
			if objective.get("id", "") == definition.id and not objective.done:
				objective.done = true
				_beacon_label.text = definition.message
				GameManager.last_result.flight_log.append("T+%.1fs %s" % [at, definition.message])

func _update_objectives() -> void:
	if _objective_label == null: return
	var lines: Array[String] = []
	for objective in GameManager.last_result.get("objectives", []):
		lines.append(("[DONE] " if objective.get("done", false) else "[PENDING] ") + str(objective.get("name", "")))
	_objective_label.text = "  |  ".join(lines)

func wait_for_apsis(apoapsis: bool) -> void:
	if orbit == null or orbit.eccentricity < 0.001 or power_failed or mission_finished or not _skip_result.is_empty(): return
	var period: float = FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu)
	_wait_target = period * 0.5 if apoapsis else 0.0
	warp = 1000

func _exit_tree() -> void:
	EventManager.unregister_flight(self)

func _update_mission_objectives() -> void:
	if not power_active: return
	var parts: Array = GameManager.current_build.get("installed_components", [])
	for definition in mission.get("objectives", []):
		for objective in GameManager.last_result.get("objectives", []):
			if objective.get("id", "") != definition.id: continue
			match definition.trigger:
				"circularize":
					var achieved: bool = MISSION_OBJECTIVES.circularize(orbit, float(definition.targetRadiusKm))
					if achieved and not objective.done:
						_beacon_label.text = "Geostationary orbit achieved"
						GameManager.last_result.flight_log.append("T+%.1fs Geostationary orbit achieved" % mission_elapsed_s)
					objective.done = achieved
				"powered_part":
					var installed := false
					for part in parts:
						if part.get("id", "") == definition.requiredPartId: installed = true
					objective.done = GameManager.last_result.get("launched", false) and installed and generation_w >= draw_w
				"downlink":
					objective.done = MISSION_OBJECTIVES.reach_orbit(GameManager.last_result.get("launched", false)) and MISSION_OBJECTIVES.downlink(parts, float(definition.minimumDataRateKbps))
				"imaging":
					if not GameManager.last_result.has("images_captured"): GameManager.last_result["images_captured"] = images_captured
					_images_label.visible = true
					_images_label.text = "Images captured: %d / %d" % [images_captured, int(definition.targetImages)]
					objective.done = MISSION_OBJECTIVES.imaging(parts) and images_captured >= int(definition.targetImages) and not GameManager.last_result.get("optical_objective_blocked", false)
				"clear_days":
					var clear_s: float = MISSION_OBJECTIVES.clear_observation_seconds(_observation_start_s, mission_elapsed_s, float(GameManager.last_result.get("optical_blocked_from_s", 0.0)), float(GameManager.last_result.get("optical_blocked_until_s", 0.0)))
					GameManager.last_result["clear_observation_s"] = clear_s
					_images_label.visible = true
					_images_label.text = "Clear observation: %.1f / %.0f days" % [clear_s / 86400.0, float(definition.minimumClearDays)]
					objective.done = MISSION_OBJECTIVES.optical_installed(parts) and clear_s >= float(definition.minimumClearDays) * 86400.0 and not GameManager.last_result.get("optical_objective_blocked", false)

func _apply_image_passes(base: int, first_s: float, until_s: float, period_s: float) -> void:
	var has_imaging := false
	for definition in mission.get("objectives", []):
		if definition.trigger == "imaging": has_imaging = true
	if not has_imaging or not MISSION_OBJECTIVES.imaging(GameManager.current_build.get("installed_components", [])): return
	var blocked_until := float(GameManager.last_result.get("optical_blocked_until_s", 0.0))
	images_captured = base + MISSION_OBJECTIVES.count_passes(first_s, period_s, until_s, blocked_until)
	GameManager.last_result["images_captured"] = images_captured
	_update_mission_objectives()
