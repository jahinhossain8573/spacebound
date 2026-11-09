extends Control

const WARP_LEVELS := [1, 10, 100, 1000]
var orbit: OrbitState
var mission: Dictionary = {}
var mission_elapsed_s: float = 0.0
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

func _ready() -> void:
	GameManager.state = GameManager.State.FLIGHT_OPS
	mission_elapsed_s = GameManager.flight_elapsed_s
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
	if GameManager.initial_orbit != null and GameManager.flight_elapsed_s > 0:
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
	orbit = value.copy()
	orbit.time_since_periapsis_s = fposmod(orbit.time_since_periapsis_s, period)
	_error.text = ""
	_marker.visible = true
	_plotter.redraw(orbit)
	_update_position()
	set_camera_preset(_camera_mode)
	return true

func set_warp(value: int) -> void:
	if value in WARP_LEVELS: warp = value

func advance_time(real_delta_s: float) -> void:
	if mission_finished or power_failed or not _skip_result.is_empty() or orbit == null or not is_finite(real_delta_s) or real_delta_s < 0.0: return
	var elapsed := real_delta_s * warp
	if power_active:
		var remaining := minf(elapsed, maxf(0.0, float(mission.durationDays) * 86400.0 - mission_elapsed_s))
		while remaining > 0.000001 and not power_failed:
			var step := minf(5.0, remaining)
			var period_s: float = FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu)
			orbit.time_since_periapsis_s = fposmod(orbit.time_since_periapsis_s + step * 0.5, period_s)
			_update_position()
			var rate := -draw_w if in_eclipse else generation_w - draw_w
			battery_charge_wh = clampf(battery_charge_wh + rate * step / 3600.0, 0.0, battery_capacity_wh)
			_track_battery()
			mission_elapsed_s += step
			orbit.time_since_periapsis_s = fposmod(orbit.time_since_periapsis_s + step * 0.5, period_s)
			remaining -= step
			if battery_charge_wh <= 0.0 and rate < 0.0: _power_failure("POWER FAILURE")
		_update_position()
		if not power_failed and mission_elapsed_s >= float(mission.durationDays) * 86400.0: _complete_duration()
		return
	mission_elapsed_s += elapsed
	var period: float = FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu)
	orbit.time_since_periapsis_s = fposmod(orbit.time_since_periapsis_s + elapsed, period)
	_update_position()

func _process(delta: float) -> void:
	_flash_clock += delta
	if _failure_delay > 0.0:
		_failure_delay -= delta
		if _failure_delay <= 0.0: _open_debrief()
	elif not _skip_result.is_empty():
		_skip_animation += delta
		mission_elapsed_s = _skip_start + _skip_remaining * minf(1.0, _skip_animation / 3.0)
		_update_position()
		if _skip_animation >= 3.0:
			battery_charge_wh = _skip_result.end_wh
			if _skip_result.survived: _complete_duration()
			else: _power_failure("Battery depleted on orbit %d" % _skip_result.failed_orbit)
	else:
		advance_time(delta)
	_update_battery_hud()
	if orbit != null:
		_update_camera()
		var pixels := maxf(1.0, float(_view.size.y))
		var diameter := 8.0 * 2.0 * _camera.global_position.distance_to(_marker.global_position) * tan(deg_to_rad(_camera.fov) * 0.5) / pixels
		_marker.scale = Vector3.ONE * maxf(0.5, diameter) if _map_view else Vector3.ONE
		_marker.visible = _map_view
		_craft_visual.visible = not _map_view
		_craft_visual.position = _marker.position

func _update_position() -> void:
	var pos: Vector2 = FlightSim.position_on_orbit_km(orbit.semi_major_axis_km, orbit.eccentricity, orbit.time_since_periapsis_s, orbit.mu)
	position_km = pos.rotated(orbit.arg_periapsis_rad)
	_marker.position = Vector3(position_km.x, 0.0, position_km.y) * FlightSim.RENDER_SCALE
	var radius := float(position_km.length())
	altitude_km = radius - FlightSim.R_EARTH_KM
	speed_kms = FlightSim.speed_at_radius_kms(radius, orbit.semi_major_axis_km, orbit.mu)
	in_eclipse = is_in_eclipse(position_km)
	var periapsis := orbit.semi_major_axis_km * (1.0 - orbit.eccentricity) - FlightSim.R_EARTH_KM
	var apoapsis := orbit.semi_major_axis_km * (1.0 + orbit.eccentricity) - FlightSim.R_EARTH_KM
	var name: String = "Sun-synchronous" if mission.get("targetOrbit", "") == "SSO" else str(mission.get("title", "Orbit preview"))
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
	_map_button.text = "Flight view (M)" if _map_view else "Map view (M)"
	_update_camera()

func set_camera_preset(value: String) -> void:
	if orbit == null: return
	_camera_mode = value
	_distance = 0.18 if value == "Spacecraft" else 190.0
	if value == "Wide":
		_distance = maxf(190.0, orbit.semi_major_axis_km * (1.0 + orbit.eccentricity) * FlightSim.RENDER_SCALE * 3.2)
	_update_camera()

func _update_camera() -> void:
	var target := _marker.position if _camera_mode == "Spacecraft" else Vector3.ZERO
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
			_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.06, 5000.0)
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
		return orbit.eccentricity < 0.01 and absf(orbit.semi_major_axis_km - 42164.0) < 422.0
	return mission.get("targetOrbit", "") in ["LEO", "SSO"]

func skip_mission_time() -> void:
	if not can_skip_mission(): return
	_skip_pending = true
	_skip_start = mission_elapsed_s
	_skip_remaining = maxf(0.0, float(mission.durationDays) * 86400.0 - mission_elapsed_s)
	# Notify event listeners before reading power totals and computing the result.
	GameManager.mission_skip_started.emit(_skip_remaining)
	var period: float = FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu)
	var fraction: float = 72.0 / 1436.0 if mission.get("targetOrbit", "") in ["GEO", "GTO"] else FlightSim.eclipse_fraction(orbit.semi_major_axis_km)
	# The skip helper's cycle starts at eclipse exit, with sunlight first.
	var phase := fposmod(orbit.time_since_periapsis_s + orbit.arg_periapsis_rad / TAU * period - period * (0.5 + fraction * 0.5), period)
	_skip_result = FlightSim.simulate_mission_skip(_skip_remaining, period, fraction, generation_w, draw_w, battery_capacity_wh, battery_charge_wh, phase)
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
	mission_finished = true
	_set_objective("Survive mission duration", true)
	_set_objective("Mission objective", true)
	GameManager.last_result.flight_log.append("T+%.1fs Mission duration completed" % mission_elapsed_s)
	_open_debrief()

func _open_debrief() -> void:
	set_process(false)
	if not DisplayServer.get_name() == "headless":
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Debrief.tscn")
