extends Control

const MISSION_OBJECTIVES = preload("res://scripts/MissionObjectives.gd")
const MODEL_LIBRARY = preload("res://scripts/ModelLibrary.gd")
const SPACECRAFT = preload("res://scripts/SpacecraftAssembly.gd")
const ASCENT = preload("res://scripts/AscentSim.gd")
const EARTH_VISUAL = preload("res://scripts/EarthVisual.gd")
const SPACE_CENTER = preload("res://scripts/SpaceCenterWorld.gd")
const FLIGHT_HUD = preload("res://scripts/FlightHUD.gd")
const LIVE_ASCENT = preload("res://scripts/LiveAscent.gd")
const ORBIT_PLOTTER = preload("res://scripts/OrbitPlotter.gd")
const FLIGHT_PREFERENCES = preload("res://scripts/FlightPreferences.gd")
const UI = preload("res://scripts/UIStyle.gd")

const LAUNCH_WARP_LEVELS := [1, 2, 5, 10, 50, 250]
const EVENT_LOG := {
	"clamp_release": "Hold-down clamps released. Liftoff!",
	"max_q": "Max-Q (maximum aerodynamic pressure).",
	"meco": "Main engine cutoff.",
	"stage_separation": "Stage separation.",
	"upper_ignition": "Second stage ignition.",
	"fairing": "Fairing separation.",
	"cutoff": "Second stage cutoff.",
	"circularization": "Circularization burn at apogee.",
	"circularization_cutoff": "Circularization burn cutoff.",
	"upper_restart": "Upper stage restarted.",
	"payload_separation": "Payload separation."
}

var launch_warp: int = 1
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var ignited := false
var clamps_released := false
var failed := false
var finished := false
var failure_at := 0.0
var stage_separated := false
var fairing_separated := false
var can_skip := false
var reliability := 0.0
var rocket_height := 18.0
## Height above the rocket's base that the camera looks at; it rises to the upper stack at staging.
var focus_height := 9.0
var _upper_focus := 13.5
var _root3d: Node3D
var _rocket: Node3D
var _stage: Node3D
var _fairing_left: Node3D
var _fairing_right: Node3D
var _stage1_flame: MeshInstance3D
var _stage1_core: MeshInstance3D
var _upper_flame: MeshInstance3D
var _payload: Node3D
var _camera: Camera3D
var _flash: MeshInstance3D
var _status: Label
var _skip: Button
var _start: Button
var _warning: Label
var _save_retry: Button
var _warp_buttons: Dictionary = {}
var _warp_display := Vector2i.ZERO
var _failure_timer := 0.0
var _camera_yaw := 0.05
var _camera_pitch := 0.34
var _camera_distance := 2.25
var _camera_dragging := false
var _launch_view: SubViewportContainer
var _hud_overlay: Control
var _env_data: Dictionary = {}
var _pad_rig: Dictionary = {}
var _station: Node3D
var _earth_spin: Node3D
var _earth: EARTH_VISUAL
var _flight: Control
var _ascent: LIVE_ASCENT
var _step_budget := 0.0
var _guidance_enabled := true
var _map_view := false
var _map_plot: MeshInstance3D
var _map_marker: MeshInstance3D
var _map_yaw := 0.12
var _map_pitch := 0.18
var _map_distance := 19000000.0
var _map_pan := Vector3.ZERO
var _map_refresh := 0.0
const MAP_SCALE := 1000.0 / FlightSim.RENDER_SCALE
var _events_done: Dictionary = {}
var _debris: Array[Dictionary] = []
var _sim_time := 0.0
var _ground_speed := 0.0
var _model: Node3D
var _payload_view_distance := 4.0
## Floating origin: the rocket stays at the render origin and _anchor, which holds Earth, the pad
## and the map view, moves the other way. Double-precision subtraction happens in GDScript before
## anything becomes a 32-bit Vector3, eliminating jitter at 6,371 km!
var _anchor: Node3D
var _craft_x := 0.0
var _craft_y := EARTH_RADIUS_M
const EARTH_RADIUS_M := 6371000.0

func _ready() -> void:
	GameManager.state = GameManager.State.LAUNCH
	_create_ui()
	var mission: Dictionary = GameManager.current_mission
	var build: Dictionary = GameManager.current_build
	if mission.is_empty() or build.is_empty() or GameManager.attempt_id.is_empty() or not build.has("launcher") or not build.has("bus") or not build.has("installed_components") or not build.has("propellant_mass_kg") or not build.has("stats") or build.launcher.get("id", "") != mission.get("requiredLauncher", "") or build.bus.get("id", "") != mission.get("requiredBus", ""):
		_status.text = "No approved build or active mission. Return to Mission Select."
		_start.disabled = true
		_hud_overlay.sync_banners()
		set_process(false)
		return
	var validator = preload("res://scripts/BuildStats.gd").new()
	for item in validator.run_readiness_review(build, mission):
		if item.status == "FAIL":
			_status.text = "Build is not flight ready. Return to Mission Select."
			_start.disabled = true
			_hud_overlay.sync_banners()
			set_process(false)
			return
	build.stats = validator.calculate_stats(build, mission)
	if mission.get("targetOrbit", "") not in ["LEO", "SSO", "GEO", "GTO"]:
		_status.text = "This mission requires its dedicated lunar flight destination."
		_start.disabled = true
		_hud_overlay.sync_banners()
		set_process(false)
		return
	can_skip = GameManager.has_launched_once
	rocket_height = {"launcher_electron":18.0, "launcher_vega_c":35.0, "launcher_falcon_9":70.0}.get(build.launcher.id, 18.0)
	focus_height = rocket_height * 0.44
	_upper_focus = rocket_height * 0.75
	_ascent = LIVE_ASCENT.new(build.launcher.ascent, float(build.stats.wet_mass_kg), mission)
	_ground_speed = _ascent.ground_speed
	_guidance_enabled = FLIGHT_PREFERENCES.guidance_enabled()
	_hud_overlay.guidance_panel.visible = _guidance_enabled
	rng.randomize()
	_create_world()
	_refresh_stage_hud()
	_hud_overlay.update_telemetry(rocket_height, 0.0, "Surface", PI * 0.5, 90.0, 0.0, 1.0, 0.0, 0.0)
	_hud_overlay.update_aero_readout(0.0, 0.0, 0.0, 1.0, true)
	_status.text = "%s ready on the pad" % build.launcher.name
	_refresh_flight_controls()

func set_launch_warp(level: int) -> void:
	if level not in LAUNCH_WARP_LEVELS:
		return
	var max_allowed := _max_safe_warp()
	launch_warp = mini(level, max_allowed)
	_refresh_warp_buttons()

func _max_safe_warp() -> int:
	return _ascent.warp_limit() if ignited else 1

func _refresh_warp_buttons() -> void:
	var max_allowed := _max_safe_warp()
	if launch_warp > max_allowed:
		launch_warp = max_allowed
	var display := Vector2i(launch_warp, max_allowed)
	if display == _warp_display:
		return
	_warp_display = display
	for lvl: int in _warp_buttons:
		var btn: Button = _warp_buttons[lvl]
		btn.disabled = lvl > max_allowed
		UI.style_button(btn, "green" if lvl == launch_warp else "slate", 7, 3, 3)

func _create_ui() -> void:
	var container := SubViewportContainer.new()
	_launch_view = container
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.focus_mode = Control.FOCUS_ALL
	container.gui_input.connect(_camera_input)
	container.stretch = true
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_root3d = Node3D.new()
	viewport.add_child(_root3d)

	_hud_overlay = FLIGHT_HUD.new()
	_hud_overlay.setup("launch")
	add_child(_hud_overlay)

	for level: int in LAUNCH_WARP_LEVELS:
		var wb := Button.new()
		wb.text = "%dx" % level
		wb.tooltip_text = "Time Warp %dx (Keys 1-6 or . / ,)" % level
		wb.add_theme_font_size_override("font_size", 12)
		UI.style_button(wb, "green" if level == 1 else "slate", 7, 3, 3)
		wb.pressed.connect(set_launch_warp.bind(level))
		_hud_overlay.warp_box.add_child(wb)
		_warp_buttons[level] = wb
	_refresh_warp_buttons()

	_hud_overlay.back_button.pressed.connect(func():
		if not ignited: get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")
	)
	_hud_overlay.reset_cam_button.pressed.connect(_reset_camera_view)
	_hud_overlay.map_button.pressed.connect(toggle_map_view)
	_hud_overlay.guidance_hold.toggled.connect(func(enabled: bool):
		if _ascent != null:
			_ascent.hold = enabled and _guidance_enabled and not _ascent.scripted
			_refresh_flight_controls()
	)
	_start = _hud_overlay.start_button
	_start.pressed.connect(_next_stage)
	_skip = _hud_overlay.skip_ascent_button
	_skip.pressed.connect(skip_ascent)
	_status = _hud_overlay.status_label
	_warning = _hud_overlay.warning_label
	_save_retry = _hud_overlay.save_retry_button
	_save_retry.pressed.connect(_retry_save)

func _reset_camera_view() -> void:
	if _map_view:
		_map_yaw = 0.12
		_map_pitch = 0.18
		_map_distance = maxf(19000000.0, _ascent.altitude * 2.0)
		_map_pan = Vector3.ZERO
		_update_camera()
		_update_map()
		return
	_camera_yaw = 0.05
	_camera_pitch = 0.34
	_camera_distance = 2.25
	if _camera != null:
		_update_camera()

func _refresh_stage_hud(s1_fuel := 1.0, s2_fuel := 1.0) -> void:
	var cards: Array = []
	cards.append({"index": 0, "icon": "comms", "label": "PAYLOAD", "active": payload_separated()})
	if not fairing_separated:
		cards.append({"index": 1, "icon": "all", "label": "FAIRING", "active": false})
	cards.append({"index": 1 if fairing_separated else 2, "icon": "propulsion", "label": "STAGE 2", "active": stage_separated and not payload_separated(), "fuel": s2_fuel, "key": "s2"})
	if not stage_separated:
		cards.append({"index": 3, "icon": "propulsion", "label": "STAGE 1", "active": ignited, "fuel": s1_fuel, "key": "s1"})
	_hud_overlay.set_stage_cards(cards)
	_hud_overlay.stage_num_label.text = "%03d" % (0 if payload_separated() else (1 if stage_separated else 2))

func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _cylinder(parent: Node3D, radius: float, height: float, y: float, color: Color, cone := false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0 if cone else radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position.y = y
	item.material_override = _material(color)
	parent.add_child(item)
	return item

func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> void:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = position
	item.material_override = _material(color)
	parent.add_child(item)

func _create_world() -> void:
	var env := WorldEnvironment.new()
	_env_data = SPACE_CENTER.create_environment()
	env.environment = _env_data.environment
	_root3d.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -28, 0)
	light.light_energy = 1.15
	_root3d.add_child(light)
	_anchor = Node3D.new()
	_anchor.name = "EarthAnchor"
	_root3d.add_child(_anchor)

	# _earth_spin sits at Earth's center (0, -R_EARTH, 0) inside _anchor so Earth's ocean & continents
	# rotate smoothly with Earth's spin, while _station sits directly under _root3d so its offset
	# from the rocket at (0,0,0) is computed in 64-bit precision without 6,371 km float32 rounding!
	_earth_spin = Node3D.new()
	_earth_spin.name = "EarthSpin"
	_earth_spin.position = Vector3(0.0, -EARTH_RADIUS_M, 0.0)
	_anchor.add_child(_earth_spin)

	_earth = EARTH_VISUAL.new()
	_earth.name = "Earth"
	_earth.basis = EARTH_VISUAL.kennedy_basis().scaled(Vector3.ONE * EARTH_RADIUS_M)
	_earth_spin.add_child(_earth)

	_station = Node3D.new()
	_station.name = "LaunchStation"
	_root3d.add_child(_station)

	var build: Dictionary = GameManager.current_build
	var diameter: float = float(build.launcher.ascent.get("diameterMeters", 1.2))
	_pad_rig = SPACE_CENTER.populate_space_center(_station, rocket_height, diameter * 0.5)

	_rocket = Node3D.new()
	_root3d.add_child(_rocket)
	var model := MODEL_LIBRARY.instantiate("launchers", build.launcher.id)
	if model:
		_assemble_model_rocket(model, build)
	else:
		_assemble_primitive_rocket()
	_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = rocket_height * 0.045
	flash_mesh.height = rocket_height * 0.09
	_flash.mesh = flash_mesh
	_flash.material_override = _material(Color("ffb300"), true)
	_flash.visible = false
	_root3d.add_child(_flash)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.near = 0.5
	_camera.far = 2000000.0
	_root3d.add_child(_camera)
	_map_plot = ORBIT_PLOTTER.new()
	_map_plot.transform = Transform3D(Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT).scaled(Vector3.ONE * MAP_SCALE), _earth_spin.position)
	_map_plot.hide()
	_anchor.add_child(_map_plot)
	_map_marker = MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.5
	marker_mesh.height = 1.0
	_map_marker.mesh = marker_mesh
	_map_marker.material_override = _material(Color("58e7ff"), true)
	_map_marker.hide()
	_root3d.add_child(_map_marker)
	place_craft(0.0, EARTH_RADIUS_M)
	_update_camera()

## Separable sections come from the launcher model; the first stage and interstage fall away
## together, and the player's spacecraft rides on payload_mount.
func _assemble_model_rocket(model: Node3D, build: Dictionary) -> void:
	_model = model
	_rocket.add_child(model)
	_stage = Node3D.new()
	_rocket.add_child(_stage)
	for section in ["stage_1", "interstage"]:
		var node := model.get_node_or_null(section)
		if node:
			node.reparent(_stage)
	_fairing_left = model.get_node("fairing_left")
	_fairing_right = model.get_node("fairing_right")
	var upper_stage := model.get_node_or_null("stage_2") as Node3D
	if upper_stage:
		_upper_focus = (upper_stage.position.y + rocket_height) / 2.0
	_stage1_flame = _add_flame(_stage, _stage.find_child("exhaust_stage_1", true, false) as Node3D, 1.25)
	_stage1_flame.name = "Flame"
	var upper := model.find_child("exhaust_stage_2", true, false) as Node3D
	if upper:
		_upper_flame = _add_flame(upper.get_parent() as Node3D, upper, 0.55)
	var mount := model.find_child("payload_mount", true, false) as Node3D
	_payload = SPACECRAFT.build(build.bus, build.installed_components)
	if mount and _payload:
		_payload.name = "Payload"
		mount.add_child(_payload)
		var dims := SPACECRAFT.dimensions_of(build.bus)
		_payload.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, dims.z / 2.0, 0))
		_payload_view_distance = maxf(dims.x, maxf(dims.y, dims.z)) * 6.0

func _add_flame(parent: Node3D, exhaust: Node3D, size := 1.0) -> MeshInstance3D:
	var height := rocket_height * 0.16 * size
	var radius := rocket_height * 0.028 * size
	var flame := MeshInstance3D.new()
	var outer_mesh := CylinderMesh.new()
	outer_mesh.top_radius = 0.0
	outer_mesh.bottom_radius = radius
	outer_mesh.height = height
	flame.mesh = outer_mesh
	var outer_mat := StandardMaterial3D.new()
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.albedo_color = Color(1.0, 0.58, 0.12, 0.88)
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = outer_mat
	flame.position = parent.to_local(exhaust.global_position) + Vector3(0, -height / 2.0, 0)
	flame.rotation.z = PI
	flame.set_meta("nozzle_local", parent.to_local(exhaust.global_position))
	flame.set_meta("base_height", height)

	# Bright white-yellow Mach shock core inside the exhaust plume
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.0
	core_mesh.bottom_radius = radius * 0.52
	core_mesh.height = height * 0.58
	core.mesh = core_mesh
	core.position.y = -height * 0.20
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.96, 0.82, 1.0)
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = core_mat
	flame.add_child(core)

	flame.visible = false
	parent.add_child(flame)
	return flame

func _assemble_primitive_rocket() -> void:
	var radius := rocket_height * 0.045
	_stage = Node3D.new()
	_rocket.add_child(_stage)
	_cylinder(_stage, radius, rocket_height*0.5, rocket_height*0.25, Color("d5dce3"))
	_cylinder(_stage, radius*1.02, rocket_height*0.025, rocket_height*0.48, Color("1a2029"))
	_cylinder(_stage, radius*0.65, rocket_height*0.07, -rocket_height*0.025, Color("59636e"))
	_cylinder(_rocket, radius*0.85, rocket_height*0.3, rocket_height*0.65, Color("d5dce3"))
	_cylinder(_rocket, radius*0.88, rocket_height*0.025, rocket_height*0.55, Color("1a2029"))
	_fairing_left = Node3D.new()
	_fairing_right = Node3D.new()
	_rocket.add_child(_fairing_left)
	_rocket.add_child(_fairing_right)
	for fairing in [_fairing_left, _fairing_right]:
		var side := -1.0 if fairing == _fairing_left else 1.0
		_box(fairing, Vector3(radius*0.85,rocket_height*0.13,radius*1.5), Vector3(side*radius*0.43,rocket_height*0.865,0), Color("cbd5df"))
		var tip := _cylinder(fairing, radius*0.7, rocket_height*0.14, rocket_height*0.985, Color("cbd5df"), true)
		tip.position.x = side*radius*0.25
	var s1_exhaust := Node3D.new()
	s1_exhaust.position.y = -rocket_height * 0.05
	_stage.add_child(s1_exhaust)
	_stage1_flame = _add_flame(_stage, s1_exhaust, 1.25)
	_stage1_flame.name = "Flame"
	var upper_exhaust := Node3D.new()
	upper_exhaust.position.y = rocket_height * 0.5
	_rocket.add_child(upper_exhaust)
	_upper_flame = _add_flame(_rocket, upper_exhaust, 0.55)

func calculate_reliability(base: float, nodes: Array) -> float:
	var result := base
	for id in ["L7", "L8", "L9"]:
		if id in nodes: result += 0.02
	return clampf(result, 0.0, 0.99)

func ignite() -> void:
	if ignited or finished or _start.disabled: return
	reliability = calculate_reliability(float(GameManager.current_build.launcher.baseReliability), GameManager.owned_tech_nodes)
	var roll := rng.randf()
	failed = roll > reliability
	if OS.is_debug_build():
		if GameManager.debug_disable_reliability: failed = false
		if GameManager.debug_force_launch_failure: failed = true
	var powered_cutoff := 0.0
	for stage: Dictionary in _ascent.stages:
		powered_cutoff += float(stage.propellantKg) / ASCENT.propellant_flow(stage)
	failure_at = rng.randf_range(6.0, maxf(12.0, powered_cutoff * 0.92)) if failed else 0.0
	GameManager.has_launched_once = true
	if GameManager.save_campaign() != OK:
		_warning.text = "Could not save launch history. Retry before launch."
		_save_retry.visible = true
		_start.disabled = true
		_hud_overlay.sync_banners()
		return
	_begin_ascent()

func _retry_save() -> void:
	if GameManager.save_campaign() != OK: return
	_warning.text = ""
	_save_retry.visible = false
	_start.disabled = false
	_hud_overlay.sync_banners()
	_begin_ascent()

func _begin_ascent() -> void:
	if ignited: return
	ignited = true
	launch_warp = 1
	_skip.visible = can_skip
	_skip.disabled = failed
	_hud_overlay.sun_badge.text = "IGNITION"
	var m: Dictionary = GameManager.current_mission
	var stats: Dictionary = GameManager.current_build.stats
	GameManager.last_result = {"mission_number":int(m.missionNumber), "attempt_id":GameManager.attempt_id, "launched":false, "objectives":[{"name":"Reach starting orbit", "done":false}, {"name":"Survive mission duration", "done":false}, {"name":"Mission objective", "done":false}], "total_cost_m":stats.get("cost_millions",0.0), "mass_margin_pct":stats.get("mass_margin_pct",0.0), "events_fired":[], "flight_log":[]}
	if m.has("objectives"):
		GameManager.last_result.objectives = []
		for definition in m.objectives:
			GameManager.last_result.objectives.append({"id":definition.id, "name":definition.name, "done":false})
	_log("Main engine ignition aboard %s (reliability %.0f%%)." % [GameManager.current_build.launcher.name, reliability*100], 0.0)
	_refresh_stage_hud(1.0, 1.0)
	_refresh_warp_buttons()
	_refresh_flight_controls()

func _release_pad_clamps() -> void:
	if clamps_released:
		return
	clamps_released = true
	_hud_overlay.sun_badge.text = "LIFTOFF"
	if _pad_rig.has("clamps"):
		for jaw: Node3D in _pad_rig.clamps:
			if is_instance_valid(jaw):
				create_tween().tween_property(jaw, "rotation:z", -deg_to_rad(58.0), 0.35)

func _process(delta: float) -> void:
	if finished or _save_retry.visible:
		return
	if _failure_timer > 0.0:
		_failure_timer -= delta
		_flash.scale = Vector3.ONE * (1.0 + (3.0 - _failure_timer) * 2.0)
		if _failure_timer <= 0.0:
			_finish_failure()
		return
	if ignited:
		_refresh_warp_buttons()
		advance_ascent(delta * float(launch_warp), true)

func _next_stage() -> void:
	if not ignited:
		ignite()
	elif not finished and _failure_timer <= 0.0 and not _ascent.scripted and _ascent.next_stage():
		launch_warp = 1
		_step_budget = 0.0
		_process_milestones()
		_refresh_flight_controls()

func toggle_scripted_flight() -> void:
	if _ascent == null or finished or _failure_timer > 0.0 or _save_retry.visible:
		return
	_ascent.scripted = not _ascent.scripted
	_ascent.hold = false
	launch_warp = 1
	_step_budget = 0.0
	if not ignited and _ascent.scripted:
		ignite()
	_refresh_flight_controls()

func _steering_input() -> Vector2:
	var x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var y := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	return Vector2(x, y)

func _steering_turn(input: Vector2, camera_basis: Basis) -> float:
	var tangent := Vector3(-sin(_ascent.pitch), cos(_ascent.pitch), 0.0)
	if _map_view:
		var frame := Basis(Vector3.BACK, -atan2(_ascent.px, _ascent.py))
		tangent = frame * tangent
	var screen := Vector2(tangent.dot(camera_basis.x), tangent.dot(camera_basis.y))
	return clampf(input.dot(screen.normalized()), -1.0, 1.0)

func advance_ascent(delta: float, player_frame := false) -> void:
	if not ignited or finished or _failure_timer > 0.0:
		return
	var steering := Vector2.ZERO
	var steering_basis := Basis.IDENTITY
	var throttle_rate := 0.0
	if player_frame and not _ascent.scripted:
		steering = _steering_input()
		if steering != Vector2.ZERO:
			_ascent.hold = false
			steering_basis = _camera.global_basis if _map_view else local_frame().inverse() * _camera.global_basis
		throttle_rate = 0.45 * (float(Input.is_physical_key_pressed(KEY_SHIFT)) - float(Input.is_physical_key_pressed(KEY_CTRL)))
	_step_budget += maxf(0.0, delta)
	while not finished:
		var step := _ascent.step_size()
		if _step_budget + 0.000000001 < step:
			break
		_step_budget = maxf(0.0, _step_budget - step)
		var turn := _steering_turn(steering, steering_basis) if steering != Vector2.ZERO else 0.0
		_ascent.advance(step, turn, throttle_rate)
		elapsed = _ascent.elapsed
		_sim_time = elapsed
		if not _ascent.events.is_empty():
			_update_debris(_sim_time)
			_apply_ascent_state()
			_process_milestones()
		if finished:
			return
		if not _ascent.failure.is_empty() or (failed and elapsed >= failure_at):
			_apply_ascent_state()
			_explode(_ascent.failure)
			return
		if player_frame and launch_warp > _max_safe_warp():
			_step_budget = 0.0
			_refresh_warp_buttons()
			break

	_update_debris(_sim_time)
	_apply_ascent_state()
	_update_telemetry()
	_refresh_flight_controls()
	_update_camera()
	if _map_view:
		_map_refresh -= delta / float(maxi(1, launch_warp))
		_update_map()

func _update_telemetry() -> void:
	var surface := _ascent.altitude < 36000.0
	var speed := _ascent.airspeed if surface else sqrt(_ascent.vx * _ascent.vx + _ascent.vy * _ascent.vy)
	var phase := "HOLD-DOWN SPOOL" if _ascent.clamped else ("COASTING" if _ascent.applied_throttle == 0.0 else "POWERED FLIGHT")
	_status.text = "T+%s  ·  STAGE %d  ·  %s" % [_clock(elapsed), _ascent.stage + 1, phase]
	_hud_overlay.update_stage_fuel("s1", _ascent.fuel / float(_ascent.stages[0].propellantKg) if _ascent.stage == 0 else 0.0)
	_hud_overlay.update_stage_fuel("s2", _ascent.fuel / float(_ascent.stages[1].propellantKg) if _ascent.stage == 1 else 1.0)
	_hud_overlay.update_aero_readout(_ascent.thrust / (_ascent.mass * ASCENT.G0), _ascent.mach, _ascent.pressure, _ascent.g_load, _ascent.clamped)
	_hud_overlay.navball.target_pitch_rad = _ascent.target_pitch() if _guidance_enabled else NAN
	_hud_overlay.update_telemetry(
		_ascent.altitude + rocket_height, speed, "Surface" if surface else "Orbit", _ascent.pitch,
		90.0, _ascent.applied_throttle, clampf(_ascent.g_load / 4.5, 0.08, 1.0), _ascent.radial_speed,
		elapsed, false, _ascent.air_path if surface else _ascent.orbit_path
	)

func _refresh_flight_controls() -> void:
	if _ascent == null or _save_retry.visible:
		return
	if ignited:
		var lockout := _ascent.stage_lockout()
		_start.text = _ascent.stage_action()
		_start.disabled = _ascent.scripted or not lockout.is_empty()
		_hud_overlay.set_stage_hint("Scripted guidance has control." if _ascent.scripted else lockout)
	else:
		_hud_overlay.set_stage_hint("WASD  Steer\nShift/Ctrl  Throttle\nZ / X  Full / Cutoff\nM  Map")
	_hud_overlay.navball.steering_hold_active = _ascent.hold or _ascent.scripted
	_hud_overlay.navball.queue_redraw()
	_hud_overlay.guidance_hold.disabled = not ignited or _ascent.scripted
	_hud_overlay.guidance_hold.set_pressed_no_signal(_ascent.hold)
	if _guidance_enabled:
		var cue := _ascent.guidance() if ignited else "Ignite from the staging panel, then climb vertically to clear the tower."
		if ignited and not _ascent.clamped:
			cue += "\nTarget pitch %+.0f°  ·  Δv remaining %.0f m/s" % [rad_to_deg(_ascent.target_pitch()), _ascent.remaining_dv()]
		_hud_overlay.guidance_label.text = cue

func _apply_ascent_state() -> void:
	place_craft(_ascent.px, _ascent.py)
	var axis := local_frame() * Vector3(cos(_ascent.pitch), sin(_ascent.pitch), 0.0)
	_rocket.rotation.z = atan2(-axis.x, axis.y)
	SPACE_CENTER.update_atmosphere(_env_data, 100000.0 if _map_view else _ascent.altitude)

	var s1_firing := _ascent.stage == 0 and _ascent.applied_throttle > 0.0
	var s2_firing := _ascent.stage == 1 and _ascent.applied_throttle > 0.0
	if is_instance_valid(_pad_rig.get("pad_smoke")):
		_pad_rig.pad_smoke.emitting = s1_firing and _ascent.altitude < 140.0
	if is_instance_valid(_stage) and _stage.has_node("Flame"):
		var flame := _stage.get_node("Flame") as Node3D
		flame.visible = s1_firing
		if s1_firing:
			_animate_plume(flame, _ascent.applied_throttle, _ascent.altitude)
	if _upper_flame:
		_upper_flame.visible = s2_firing
		if s2_firing:
			_animate_plume(_upper_flame, _ascent.applied_throttle, _ascent.altitude)

func _animate_plume(flame: Node3D, throttle: float, alt_m: float) -> void:
	var vac_expand := lerpf(1.0, 2.35, clampf(alt_m / 55000.0, 0.0, 1.0))
	var flicker := 0.94 + 0.12 * absf(sin(_sim_time * 37.0))
	var len_scale := maxf(0.25, throttle) * lerpf(1.0, 1.65, clampf(alt_m / 55000.0, 0.0, 1.0)) * flicker
	var rad_scale := sqrt(maxf(0.25, throttle)) * vac_expand * (0.96 + 0.08 * cos(_sim_time * 43.0))
	flame.scale = Vector3(rad_scale, len_scale, rad_scale)
	if flame.has_meta("nozzle_local") and flame.has_meta("base_height"):
		var nl: Vector3 = flame.get_meta("nozzle_local")
		var bh: float = float(flame.get_meta("base_height"))
		flame.position = nl + Vector3(0.0, -bh * len_scale * 0.5, 0.0)

func _process_milestones() -> void:
	for event in _ascent.events:
		var id: String = event.id
		var at: float = event.t
		_events_done[id] = true
		_log(EVENT_LOG[id], at)
		match id:
			"clamp_release":
				_release_pad_clamps()
			"stage_separation":
				_separate_stage(at)
				_refresh_stage_hud(0.0, 1.0)
			"fairing":
				_separate_fairings(at)
				_refresh_stage_hud(0.0, _ascent.fuel / float(_ascent.stages[1].propellantKg))
			"payload_separation":
				_separate_payload()
				_finish_success()
	_ascent.events.clear()

func _separate_stage(at: float) -> void:
	stage_separated = true
	_add_debris(_stage, at, Vector2(0.0, -2.5), 0.15)
	create_tween().tween_property(self, "focus_height", _upper_focus, 2.0)

func _separate_fairings(at: float) -> void:
	fairing_separated = true
	_add_debris(_fairing_left, at, Vector2(-4.0, 0.0), 0.6)
	_add_debris(_fairing_right, at, Vector2(4.0, 0.0), -0.6)

## The satellite leaves the upper stage, which backs away and tumbles slowly; the camera moves in.
func _separate_payload() -> void:
	if not _payload or not _model:
		return
	_payload.reparent(_rocket)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "focus_height", _payload.position.y, 3.0)
	tween.tween_property(self, "_camera_distance", _payload_view_distance / rocket_height, 3.0)
	tween.tween_property(_model, "position:y", _model.position.y - 40.0, 60.0)
	tween.tween_property(_model, "rotation:z", 0.4, 60.0)
	get_tree().create_timer(2.0).timeout.connect(_deploy_payload)

func _deploy_payload() -> void:
	if not is_instance_valid(_payload):
		return
	for player: AnimationPlayer in _payload.find_children("*", "AnimationPlayer", true, false):
		if player.has_animation("deploy"): player.play("deploy")

## Separated hardware coasts on its own 64-bit trajectory under gravity.
func _add_debris(node: Node3D, at: float, push: Vector2, spin: float) -> void:
	node.reparent(_root3d, true)
	var basis := _rocket.global_transform.basis
	var vx: float = _ascent.vx + basis.x.x * push.x + basis.y.x * push.y
	var vy: float = _ascent.vy + basis.x.y * push.x + basis.y.y * push.y
	_debris.append({
		"node": node,
		"px": float(node.global_position.x) + _craft_x,
		"py": float(node.global_position.y) + _craft_y,
		"vx": vx,
		"vy": vy,
		"spin": spin,
		"t": at
	})

## Advances each separated stage/fairing from its own clock to the current simulated time.
func _update_debris(sim_time: float) -> void:
	for piece in _debris:
		var remaining: float = sim_time - float(piece.t)
		piece.t = sim_time
		var node: Node3D = piece.node
		node.rotation.z += float(piece.spin) * remaining
		while remaining > 0.0:
			var step := minf(remaining, 0.5)
			var dpx: float = float(piece.px)
			var dpy: float = float(piece.py)
			var r: float = sqrt(dpx * dpx + dpy * dpy)
			var g_fac: float = -ASCENT.MU / (r * r * r)
			piece.vx = float(piece.vx) + dpx * g_fac * step
			piece.vy = float(piece.vy) + dpy * g_fac * step
			piece.px = dpx + float(piece.vx) * step
			piece.py = dpy + float(piece.vy) * step
			remaining -= step

func _clear_debris() -> void:
	for piece in _debris:
		piece.node.visible = false
	_debris.clear()

func _clock(seconds: float) -> String:
	var whole := int(seconds)
	return "%02d:%02d" % [whole / 60, whole % 60]

func skip_ascent() -> void:
	if not ignited or failed or not can_skip or finished: return
	_ascent.scripted = true
	advance_ascent(LIVE_ASCENT.MAX_FLIGHT_S + 1.0)

func _explode(reason := "") -> void:
	_status.text = "LAUNCH FAILURE"
	_warning.text = reason
	_hud_overlay.sync_banners()
	_start.disabled = true
	_status.add_theme_color_override("font_color", Color("ff8811"))
	_flash.position = _rocket.position
	_flash.visible = true
	_rocket.visible = false
	_skip.disabled = true
	_failure_timer = 3.0
	_log("Launch vehicle failure." if reason.is_empty() else reason)

func _finish_failure() -> void:
	if finished: return
	finished = true
	GameManager.flight_elapsed_s = elapsed
	GameManager.last_result.launched = false
	get_tree().change_scene_to_file("res://scenes/Debrief.tscn")

func _finish_success() -> void:
	if finished:
		return
	var orbit := ASCENT.orbit_from_coast(_ascent.coast)
	var met_target := _ascent.target_reached()
	finished = true
	_log("Orbital insertion nominal." if met_target else "Payload deployed in a safe orbit outside the mission target.")
	GameManager.last_result.launched = true
	for objective in GameManager.last_result.objectives:
		if objective.get("id", "") == "reach_orbit" or objective.get("name", "") == "Reach starting orbit":
			objective.done = MISSION_OBJECTIVES.reach_orbit(met_target)
	GameManager.flight_elapsed_s = elapsed
	GameManager.initial_orbit = orbit
	SPACE_CENTER.update_atmosphere(_env_data, 100000.0)
	if _upper_flame:
		_upper_flame.hide()
	_clear_debris()
	var was_map := _map_view
	if was_map:
		toggle_map_view()
	_handoff_to_flight()
	if not met_target:
		_flight._flight_hud.warning_label.text = "Safe orbit achieved outside the mission target."
		_flight._flight_hud.sync_banners()
	_flight._map_camera = Vector3(_map_yaw, _map_pitch, _map_distance)
	_flight._map_pan = _map_pan
	if was_map:
		_flight.toggle_map_view()

func _handoff_to_flight() -> void:
	var previous_camera := _camera.global_transform
	_flight = load("res://scenes/FlightView.tscn").instantiate()
	_flight.set("shared_launch", self)
	add_child(_flight)
	_flight.activate_shared_world(_launch_view, _anchor, _rocket, _camera, previous_camera, _camera_yaw, _camera_pitch, _camera_distance * rocket_height)
	for child in get_children():
		if child != _flight: child.visible = false
	_launch_view.visible = true
	_flight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _log(message: String, at: float = -1.0) -> void:
	GameManager.last_result.flight_log.append("T+%s %s" % [_clock(_sim_time if at < 0 else at), message])

func focus_point() -> Vector3:
	return _rocket.transform * Vector3(0, focus_height, 0)

## Moves the craft to a position in metres from Earth's centre (launch site starts on +Y) and
## co-rotates _station and _earth_spin by Earth's surface rotation in 64-bit precision!
func place_craft(x: float, y: float) -> void:
	_craft_x = x
	_craft_y = y
	_rocket.position = Vector3.ZERO
	_anchor.position = Vector3(-x, EARTH_RADIUS_M - y, 0.0)

	# Co-rotate launch pad & Earth surface at _sim_time so the pad moves with the rocket's initial tangential speed!
	var pad_state := ASCENT.pad_eci_at(_ground_speed, _sim_time if ignited else 0.0)
	var pad_x: float = pad_state[0]
	var pad_y: float = pad_state[1]
	var pad_angle: float = pad_state[2]
	if is_instance_valid(_station):
		# Direct 64-bit subtraction (pad_x - x, pad_y - y) gives sub-millimetre precision near the pad!
		_station.position = Vector3(pad_x - x, pad_y - y, 0.0)
		_station.rotation.z = -pad_angle
	if is_instance_valid(_earth_spin):
		_earth_spin.rotation.z = -pad_angle

	for piece in _debris:
		piece.node.position = Vector3(float(piece.px) - x, float(piece.py) - y, 0.0)

func craft_world_position() -> Vector3:
	return Vector3(_craft_x, _craft_y - EARTH_RADIUS_M, 0.0)

func local_frame() -> Basis:
	return Basis(Vector3.BACK, -atan2(_craft_x, _craft_y))

func camera_offset(distance: float, yaw: float, pitch: float) -> Vector3:
	return local_frame() * (Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance)

func spacecraft_view_distance() -> float:
	return _payload_view_distance if payload_separated() else rocket_height * 1.9

func payload_separated() -> bool:
	return _events_done.has("payload_separation") and _payload != null

func spacecraft_size() -> float:
	return _payload_view_distance / 6.0 if payload_separated() else rocket_height

func toggle_map_view() -> void:
	if _ascent == null or not is_instance_valid(_camera):
		return
	_map_view = not _map_view
	_map_plot.visible = _map_view
	_map_marker.visible = _map_view
	SPACE_CENTER.update_atmosphere(_env_data, 100000.0 if _map_view else _ascent.altitude)
	_hud_overlay.map_button.text = "Ship" if _map_view else "Map"
	_map_refresh = 0.0
	_update_camera()
	_update_map()

func _update_map() -> void:
	if not _map_view:
		_hud_overlay.set_map_readout("")
		_hud_overlay.update_map_markers(_camera, [])
		return
	var c: Dictionary = _ascent.coast
	if _map_refresh <= 0.0:
		_map_plot.redraw_coast(c)
		_map_refresh = 0.12
	var diameter := 14.0 * _camera.position.length() * tan(deg_to_rad(_camera.fov) * 0.5) / maxf(1.0, _launch_view.size.y)
	_map_marker.scale = Vector3.ONE * diameter
	var pe := float(c.periapsis)
	var ap := float(c.apoapsis)
	var period := float(c.period)
	var to_periapsis := fposmod(-float(c.phase), period) if period > 0.0 else INF
	var to_apoapsis := float(c.to_apoapsis)
	var marks: Array = [[Vector3.ZERO, "Spacecraft"]]
	var earth_center := _earth_spin.global_position
	var periapsis_axis := Vector3(sin(float(c.arg)), cos(float(c.arg)), 0.0)
	if pe > EARTH_RADIUS_M:
		marks.append([earth_center + periapsis_axis * pe, "Pe"])
	if is_finite(ap) and ap > EARTH_RADIUS_M and (_ascent.radial_speed > 0.0 or pe > EARTH_RADIUS_M):
		marks.append([earth_center - periapsis_axis * ap, "Ap"])
	_hud_overlay.update_map_markers(_camera, marks)
	var readout := "Ballistic coast prediction\n"
	if is_finite(ap):
		readout += "Ap %.1f km  ·  Pe %.1f km" % [(ap - EARTH_RADIUS_M) / 1000.0, (pe - EARTH_RADIUS_M) / 1000.0]
		if pe >= EARTH_RADIUS_M:
			if pe < EARTH_RADIUS_M + LIVE_ASCENT.ATMOSPHERE_M:
				readout += "\nAtmosphere crossing if coasting"
			readout += "\nNext %s in %s" % ["Ap" if to_apoapsis < to_periapsis else "Pe", LIVE_ASCENT.format_time(minf(to_apoapsis, to_periapsis))]
		elif ignited and not _ascent.clamped:
			readout += "\nEarth impact if coasting"
			if _ascent.radial_speed > 0.0:
				readout += "  ·  Ap in %s" % LIVE_ASCENT.format_time(to_apoapsis)
	else:
		readout += "Escape trajectory"
	_hud_overlay.set_map_readout(readout)

func _update_camera() -> void:
	if _map_view:
		var center := _earth_spin.global_position + _map_pan
		_camera.near = 1000.0
		_camera.position = center + Vector3(sin(_map_yaw) * cos(_map_pitch), sin(_map_pitch), cos(_map_yaw) * cos(_map_pitch)) * _map_distance
		_camera.look_at(center, Vector3.UP)
		update_world_visibility(200000000.0)
		return
	var target := focus_point()
	_camera.position = target + camera_offset(rocket_height * _camera_distance, _camera_yaw, _camera_pitch)
	_camera.look_at(target, local_frame().y)
	_camera.near = clampf(_camera.position.distance_to(target) * 0.15, 0.5, 8.0)
	update_world_visibility()

func update_world_visibility(minimum_far := 2000000.0) -> void:
	var pad_distance := _camera.global_position.distance_to(_station.global_position)
	_earth.set_local_detail(SPACE_CENTER.update_visibility(_station, _pad_rig, pad_distance))
	_camera.far = maxf(minimum_far, _earth.visible_distance_from(_camera.global_position))
	_earth.update_horizon(_camera)

func _unhandled_key_input(event: InputEvent) -> void:
	if finished or _ascent == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_M: toggle_map_view()
		KEY_G: toggle_scripted_flight()
		KEY_Z, KEY_X:
			if ignited and not _ascent.scripted and _failure_timer <= 0.0:
				_ascent.set_throttle(1.0 if event.keycode == KEY_Z else 0.0)
				_refresh_warp_buttons()
				_process_milestones()
				_apply_ascent_state()
				_update_telemetry()
				_refresh_flight_controls()
		KEY_1: set_launch_warp(1)
		KEY_2: set_launch_warp(2)
		KEY_3: set_launch_warp(5)
		KEY_4: set_launch_warp(10)
		KEY_5: set_launch_warp(50)
		KEY_6: set_launch_warp(250)
		KEY_PERIOD, KEY_GREATER:
			var idx := LAUNCH_WARP_LEVELS.find(launch_warp)
			if idx >= 0 and idx + 1 < LAUNCH_WARP_LEVELS.size():
				set_launch_warp(LAUNCH_WARP_LEVELS[idx + 1])
		KEY_COMMA, KEY_LESS:
			var idx := LAUNCH_WARP_LEVELS.find(launch_warp)
			if idx > 0:
				set_launch_warp(LAUNCH_WARP_LEVELS[idx - 1])

func _camera_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			_launch_view.grab_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_camera_dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
			if _map_view:
				_map_distance = clampf(_map_distance * factor, 7000000.0, 120000000.0)
			else:
				_camera_distance = clampf(_camera_distance * factor, 0.35, 8.0)
	elif event is InputEventMouseMotion:
		if _map_view and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			_map_pan += _camera.project_position(-event.relative, _map_distance) - _camera.project_position(Vector2.ZERO, _map_distance)
		elif _camera_dragging and _map_view:
			_map_yaw -= event.relative.x * 0.01
			_map_pitch = clampf(_map_pitch + event.relative.y * 0.01, -1.4, 1.4)
		elif _camera_dragging:
			_camera_yaw -= event.relative.x * 0.01
			_camera_pitch = clampf(_camera_pitch + event.relative.y * 0.01, -1.4, 1.4)
	if _camera != null:
		_update_camera()
		if _map_view:
			_update_map()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed: _camera_dragging = false
