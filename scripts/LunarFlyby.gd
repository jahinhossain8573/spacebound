extends Control

const TRANSFER = preload("res://scripts/LunarTransfer.gd")
const HUD = preload("res://scripts/FlightHUD.gd")
const EARTH = preload("res://scripts/EarthVisual.gd")
const UI = preload("res://scripts/UIStyle.gd")
const SPACECRAFT = preload("res://scripts/SpacecraftAssembly.gd")
const MODEL_LIBRARY = preload("res://scripts/ModelLibrary.gd")
const WARP_LEVELS := [1, 10, 100, 1000, 10000]
const SCALE := FlightSim.RENDER_SCALE

var flight: TRANSFER
var _stats: Dictionary
var _hud: Control
var _view: SubViewportContainer
var _camera: Camera3D
var _earth: EARTH
var _trajectory: MeshInstance3D
var _craft: MeshInstance3D
var _probe: Node3D
var _probe_length := 1.0
var _parachute: Node3D
var _splash: MeshInstance3D
var _flash: ColorRect
var _shutter: Tween
var _amount: SpinBox
var _direction: OptionButton
var _prediction: Label
var _burn: Button
var _continue: Button
var _warp_buttons: Dictionary = {}
var _warp := 10
var _overview := false
var _leaving := false
var _launch_elapsed := 0.0

func _ready() -> void:
	var mission: Dictionary = GameManager.current_mission
	var build: Dictionary = GameManager.current_build
	if int(mission.get("missionNumber", 0)) != 5 or build.is_empty() or GameManager.initial_orbit == null or not GameManager.initial_orbit.is_valid() or GameManager.attempt_id.is_empty() or GameManager.last_result.is_empty():
		var back := Button.new()
		back.text = "Return to Mission Select"
		back.pressed.connect(_leave)
		add_child(back)
		set_process(false)
		return
	GameManager.state = GameManager.State.FLIGHT_OPS
	_launch_elapsed = GameManager.flight_elapsed_s
	_stats = preload("res://scripts/BuildStats.gd").new().calculate_stats(build, mission)
	flight = TRANSFER.new(build, _stats, GameManager.initial_orbit)
	_create_world(build)
	_create_hud()
	_view.resized.connect(_update_camera)
	_redraw_path()
	_log("In the 250 km parking orbit. Vega-C upper stage will inject toward the Moon after a 90-second coast.")
	_refresh()

func _create_world(build: Dictionary) -> void:
	_view = SubViewportContainer.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.stretch = true
	add_child(_view)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("050710")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("8c9ab1")
	environment.environment.ambient_light_energy = 0.24
	MODEL_LIBRARY.use_sky_reflections(environment.environment)
	world.add_child(environment)
	_earth = EARTH.new()
	_earth.sun = light
	_earth.scale = Vector3.ONE * TRANSFER.EARTH_RADIUS_KM * SCALE
	world.add_child(_earth)
	var moon := _sphere(TRANSFER.MOON_RADIUS_KM * SCALE, Color("b7b7ba"), false)
	moon.position = Vector3(TRANSFER.MOON_DISTANCE_KM * SCALE, 0.0, 0.0)
	world.add_child(moon)
	_craft = _sphere(0.5, Color("77e9ff"), true)
	world.add_child(_craft)
	_probe = SPACECRAFT.build(build.bus, build.installed_components)
	if _probe:
		world.add_child(_probe)
		SPACECRAFT.show_deployed(_probe)
		var dims := SPACECRAFT.dimensions_of(build.bus)
		_probe_length = maxf(dims.x, maxf(dims.y, dims.z))
	_parachute = Node3D.new()
	_craft.add_child(_parachute)
	var canopy := _sphere(0.8, Color("f5a35d"), false)
	canopy.mesh.is_hemisphere = true
	canopy.position.y = 1.7
	_parachute.add_child(canopy)
	var cords := MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	var cord_material := StandardMaterial3D.new()
	cord_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cord_material.albedo_color = Color("e5ecf4")
	lines.surface_begin(Mesh.PRIMITIVE_LINES, cord_material)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		lines.surface_add_vertex(Vector3(0.8 * cos(angle), 1.7, 0.8 * sin(angle)))
		lines.surface_add_vertex(Vector3(0.0, 0.35, 0.0))
	lines.surface_end()
	cords.mesh = lines
	_parachute.add_child(cords)
	_splash = _sphere(0.5, Color("d8f9ff"), true)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	_splash.mesh = ring
	world.add_child(_splash)
	_trajectory = MeshInstance3D.new()
	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color("5bcdf3")
	path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trajectory.material_override = path_material
	world.add_child(_trajectory)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.near = 0.1
	_camera.far = 10000.0
	_camera.current = true
	world.add_child(_camera)

func _sphere(radius: float, color: Color, unshaded: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	node.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	return node

func _redraw_path() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 24:
		mesh.surface_add_vertex(flight.parking_position_km(TRANSFER.PARKING_S * float(i) / 24.0) * SCALE)
	for i in flight.curve.point_count:
		mesh.surface_add_vertex(flight.curve.get_point_position(i) * SCALE)
	mesh.surface_end()
	_trajectory.mesh = mesh

func _create_hud() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.96, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_hud = HUD.new()
	_hud.setup("orbit")
	_hud.navball.hide()
	_hud.burn_drawer.hide()
	add_child(_hud)
	_hud.back_button.text = "< Archives" if GameManager.attempt_is_archive else "< Mission Select"
	_hud.back_button.pressed.connect(_leave)
	_hud.map_button.pressed.connect(toggle_map_view)
	_hud.reset_cam_button.pressed.connect(func():
		_overview = false
		_update_camera()
	)
	_hud.skip_mission_button.text = "View flight debrief"
	_hud.skip_mission_button.pressed.connect(_finish)
	_hud.set_stage_cards([{"index": 0, "label": "CISLUNAR FLIGHT", "icon": "comms", "active": true}])
	for level: int in WARP_LEVELS:
		var button := Button.new()
		button.text = "%dx" % level
		button.pressed.connect(set_warp.bind(level))
		_hud.warp_box.add_child(button)
		_warp_buttons[level] = button
	var controls := VBoxContainer.new()
	_hud.burn_drawer.add_child(controls)
	var title := Label.new()
	title.text = "MID-COURSE CORRECTION"
	title.add_theme_color_override("font_color", UI.KSP_CYAN)
	controls.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	controls.add_child(row)
	_amount = SpinBox.new()
	_amount.suffix = "m/s"
	_amount.step = 0.01
	_amount.custom_minimum_size.x = 145
	_amount.update_on_text_changed = true
	_amount.value_changed.connect(func(_value: float): _refresh_burn())
	row.add_child(_amount)
	_direction = OptionButton.new()
	_direction.add_item("Prograde")
	_direction.add_item("Retrograde")
	_direction.item_selected.connect(func(_item: int): _refresh_burn())
	row.add_child(_direction)
	_prediction = Label.new()
	_prediction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prediction.add_theme_font_size_override("font_size", 17)
	controls.add_child(_prediction)
	_burn = Button.new()
	_burn.text = "Execute correction"
	UI.style_button(_burn, "amber", 8, 4, 3)
	_burn.pressed.connect(_execute_correction)
	controls.add_child(_burn)
	_continue = Button.new()
	_continue.text = "Resume cruise"
	_continue.pressed.connect(resume_cruise)
	controls.add_child(_continue)
	_refresh_warp()

func resume_cruise() -> void:
	if flight.navigation_open:
		flight.navigation_open = false
		_log("Navigation targeting closed. Predicted closest approach %.0f km." % flight.closest_km)
		_hud.burn_drawer.hide()
		set_warp(10000)
		_refresh()

func _execute_correction() -> void:
	var amount := _amount.value
	if flight.apply_correction(amount, _direction.selected == 1):
		_log("%s correction %.2f m/s. Predicted closest approach %.0f km." % [_direction.get_item_text(_direction.selected), amount, flight.closest_km])
		_amount.set_value_no_signal(0.0)
		_redraw_path()
		_refresh()

func _process(delta: float) -> void:
	advance_time(delta * _warp)

func advance_time(seconds: float) -> void:
	if flight == null or _leaving or flight.finished or flight.navigation_open:
		return
	var was_parked := not flight.cruise_started
	var elapsed_before := flight.elapsed
	var already_approaching := flight.approaching
	var already_passed := flight.closest_passed
	var images_before := flight.images
	flight.advance(seconds)
	if was_parked and flight.cruise_started:
		_set_objective("trans_lunar", true)
		_log("Vega-C upper stage completed trans-lunar injection. Spacecraft separated.")
		_overview = true
		set_warp(10000)
	if flight.navigation_open:
		_warp = 1
		_log("Navigation update. Predicted closest approach 4,200 km. Target 100–500 km.")
		_hud.burn_drawer.show()
		_refresh_warp()
	if not already_approaching and flight.approaching:
		_warp = mini(_warp, 100)
		_overview = false
		_log("Within 10,000 km of the Moon. Time warp reduced.")
		_refresh_warp()
	elif already_approaching and not flight.approaching:
		_overview = true
		set_warp(10000)
	if not already_passed and flight.closest_passed:
		_log("Lunar closest approach %.0f km." % flight.closest_km)
	if flight.images > images_before:
		_flash_shutter()
		if flight.images >= TRANSFER.IMAGE_COUNT:
			_log("LROC captured 20 usable lunar images.")
	if elapsed_before < TRANSFER.RETURN_S and flight.elapsed >= TRANSFER.RETURN_S:
		_log("Approaching Earth. Pacific Ocean recovery zone confirmed.")
	if elapsed_before < TRANSFER.ENTRY_S and flight.elapsed >= TRANSFER.ENTRY_S:
		_overview = false
		set_warp(_warp)
		_log("Atmospheric entry at 120 km above the Pacific.")
	if elapsed_before < TRANSFER.CHUTE_S and flight.elapsed >= TRANSFER.CHUTE_S:
		set_warp(_warp)
		_log("Recovery parachute deployed at 6 km.")
	if flight.splashed_down:
		_warp = 1
		_overview = false
		_refresh_warp()
		_log("Splashdown in the Pacific Ocean. Recovery complete.")
	_refresh()
	if flight.finished and not flight.splashed_down:
		_finish()

func _flash_shutter() -> void:
	if _shutter != null:
		_shutter.kill()
	_flash.color.a = 0.45
	_shutter = create_tween()
	_shutter.tween_property(_flash, "color:a", 0.0, 0.14)

func _refresh_burn() -> void:
	if _prediction == null:
		return
	var available := flight.available_dv()
	var editable := flight.navigation_open and not flight.finished
	if not is_equal_approx(_amount.max_value, available):
		_amount.max_value = available
	_amount.editable = editable
	_direction.disabled = not editable
	_continue.visible = editable
	_burn.disabled = not editable or _amount.value <= 0.0 or _amount.value > available
	var prediction := flight.predict_correction(_amount.value, _direction.selected == 1)
	var verdict := "Impact" if prediction < 50.0 else ("Within target corridor" if prediction >= 100.0 and prediction <= 500.0 else "Outside target corridor")
	_prediction.text = "Predicted closest approach %.0f km\n%s  ·  Target 100–500 km\nFuel %.2f kg  ·  Available Δv %.2f m/s" % [prediction, verdict, flight.fuel_kg, available]

func _refresh() -> void:
	_hud.skip_mission_button.visible = flight.splashed_down
	_hud.sun_badge.text = "ECLIPSE" if flight.in_eclipse() else "SUNLIGHT"
	_hud.battery_bar.max_value = maxf(1.0, _stats.battery_wh)
	_hud.battery_bar.value = flight.battery_wh
	_hud.battery_label.text = "Battery %.1f / %.1f Wh  ·  SDST %s" % [flight.battery_wh, _stats.battery_wh, "online" if flight.link_active() else "offline"]
	var distance := "Moon altitude %.0f km" % maxf(0.0, flight.moon_altitude_km())
	var position := flight.position_km()
	var earth_altitude := maxf(0.0, position.length() - TRANSFER.EARTH_RADIUS_KM)
	if not flight.cruise_started or flight.elapsed >= TRANSFER.RETURN_S:
		distance = "Earth altitude %.1f km" % earth_altitude
	_hud.status_label.text = "%s  ·  %s  ·  %dx" % ["Archives test flight" if GameManager.attempt_is_archive else "Cislunar Pathfinder", distance, _warp]
	_hud.warning_label.text = flight.failure
	if flight.splashed_down:
		_hud.warning_label.text = "Splashdown in the Pacific Ocean"
	elif flight.elapsed >= TRANSFER.CHUTE_S:
		_hud.warning_label.text = "Parachute deployed · Splashdown in %d s" % ceili(TRANSFER.END_S - flight.elapsed)
	elif flight.elapsed >= TRANSFER.ENTRY_S:
		_hud.warning_label.text = "Atmospheric entry · Pacific Ocean recovery zone"
	elif flight.elapsed >= TRANSFER.RETURN_S:
		_hud.warning_label.text = "Earth approach · Reentry in %d min" % ceili((TRANSFER.ENTRY_S - flight.elapsed) / 60.0)
	elif not flight.cruise_started:
		_hud.warning_label.text = "Parking orbit · Automatic lunar injection in %d s" % ceili(TRANSFER.PARKING_S - flight.parking_elapsed)
	elif flight.navigation_open:
		_hud.warning_label.text = "Navigation update. Target closest approach 100–500 km."
	_set_objective("correction", flight.corridor_met())
	_set_objective("images", flight.images >= TRANSFER.IMAGE_COUNT)
	_set_objective("deep_space_link", flight.splashed_down and flight.link_active())
	_set_objective("splashdown", flight.splashed_down)
	var objectives: Array[String] = []
	for objective: Dictionary in GameManager.last_result.objectives:
		objectives.append(("[DONE] " if objective.done else "[PENDING] ") + str(objective.name))
	objectives.append("Lunar images %d / %d" % [flight.images, TRANSFER.IMAGE_COUNT])
	_hud.objective_label.text = "\n".join(objectives)
	_hud.update_telemetry(earth_altitude * 1000.0, 0.0, "Cislunar", 0.0, 0.0, 0.0, flight.battery_wh / maxf(1.0, _stats.battery_wh), 0.0, _mission_elapsed())
	if flight.navigation_open:
		_refresh_burn()
	_craft.position = position * SCALE
	_update_camera()

func _update_camera() -> void:
	var focus := Vector3(TRANSFER.MOON_DISTANCE_KM * SCALE * 0.62, 0.0, 0.0) if _overview else _craft.position
	var aspect := maxf(0.1, _view.size.x / maxf(1.0, _view.size.y))
	var distance := maxf(2440.0, 4100.0 / aspect) if _overview else 125.0
	var close_return := not _overview and flight.elapsed >= TRANSFER.ENTRY_S
	var radial := _craft.position.normalized()
	var altitude := maxf(0.0, _craft.position.length() / SCALE - TRANSFER.EARTH_RADIUS_KM)
	if close_return:
		distance = (altitude * 0.85 + 16.0) * SCALE
		_camera.position = focus + (radial * 0.34 + Vector3.UP * 0.94) * distance
	else:
		_camera.position = focus + Vector3(0.0, distance, distance * 0.06)
	_camera.near = 0.01 if close_return else 0.1
	_camera.far = _earth.visible_distance_from(_camera.position) + 1.0 if close_return else maxf(10000.0, distance + 2000.0)
	_camera.look_at(focus, radial if close_return else Vector3.FORWARD)
	_earth.update_horizon(_camera)
	var ocean_detail := 1.0 - smoothstep(8.0, 22.0, altitude) if close_return else 0.0
	_earth.set_ocean_detail(ocean_detail)
	var marker_pixels := 26.0 if close_return else 12.0
	var marker_size := marker_pixels * 2.0 * distance * tan(deg_to_rad(_camera.fov * 0.5)) / maxf(1.0, _view.size.y)
	_craft.transform.basis = Basis(Quaternion(Vector3.UP, radial)).scaled(Vector3.ONE * marker_size)
	if _probe:
		_probe.visible = not _overview and flight.cruise_started and flight.elapsed < TRANSFER.ENTRY_S
		_craft.visible = not _probe.visible
		_probe.position = _craft.position
		var probe_attitude := Basis.from_euler(Vector3(deg_to_rad(23.0), deg_to_rad(32.0), deg_to_rad(13.0)))
		_probe.basis = probe_attitude.scaled(Vector3.ONE * marker_size * 1.5 / _probe_length)
	_parachute.visible = close_return and flight.elapsed >= TRANSFER.CHUTE_S and not flight.splashed_down
	_splash.visible = close_return and flight.splashed_down
	_splash.position = _craft.position + radial * marker_size * 0.1
	_splash.transform.basis = Basis(Quaternion(Vector3.UP, radial)).scaled(Vector3.ONE * marker_size * 2.5)
	_trajectory.visible = not close_return
	_hud.map_button.text = "Focus" if _overview else "Map"
	_hud.map_button.tooltip_text = "Follow spacecraft (M)" if _overview else "Earth–Moon overview (M)"

func toggle_map_view() -> void:
	if flight != null:
		_overview = not _overview
		_update_camera()

func set_warp(level: int) -> void:
	_warp = 1 if flight.navigation_open or flight.finished else mini(level, _warp_limit())
	_refresh_warp()

func _warp_limit() -> int:
	if not flight.cruise_started or flight.elapsed >= TRANSFER.CHUTE_S:
		return 10
	if flight.approaching or flight.elapsed >= TRANSFER.ENTRY_S:
		return 100
	return 10000

func _refresh_warp() -> void:
	for level: int in _warp_buttons:
		var button: Button = _warp_buttons[level]
		button.disabled = flight.navigation_open or flight.finished or level > _warp_limit()
		UI.style_button(button, "green" if _warp == level else "slate", 7, 3, 3)

func _set_objective(id: String, done: bool) -> void:
	for objective: Dictionary in GameManager.last_result.objectives:
		if objective.id == id:
			objective.done = done

func _log(message: String) -> void:
	var seconds := int(_mission_elapsed())
	GameManager.last_result.flight_log.append("T+%dd %02d:%02d  %s" % [seconds / 86400, seconds / 3600 % 24, seconds / 60 % 60, message])

func _mission_elapsed() -> float:
	return _launch_elapsed + flight.parking_elapsed + flight.elapsed

func _finish() -> void:
	if _leaving or not flight.finished:
		return
	_leaving = true
	GameManager.flight_elapsed_s = _mission_elapsed()
	GameManager.last_result.launched = flight.splashed_down
	GameManager.last_result.images_captured = flight.images
	GameManager.last_result.battery_lowest_pct = 100.0 * flight.lowest_battery_wh / maxf(1.0, _stats.battery_wh)
	_log("Mission complete." if flight.failure.is_empty() else flight.failure)
	get_tree().change_scene_to_file.call_deferred("res://scenes/Debrief.tscn")

func _leave() -> void:
	_leaving = true
	get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_map_view()
