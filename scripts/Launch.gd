extends Control

const MISSION_OBJECTIVES = preload("res://scripts/MissionObjectives.gd")
const MODEL_LIBRARY = preload("res://scripts/ModelLibrary.gd")
const SPACECRAFT = preload("res://scripts/SpacecraftAssembly.gd")
const ASCENT = preload("res://scripts/AscentSim.gd")
## Playback seconds for each part of the simulated flight: powered ascent, the fast-forwarded
## coast to apogee, and the final burn and payload separation (at a fixed slow-motion rate).
const POWERED_PLAYBACK := 30.0
const COAST_PLAYBACK := 4.0
const FINAL_PLAYBACK_RATE := 2.0
const EVENT_LOG := {"max_q": "Max-Q.", "meco": "Main engine cutoff.", "stage_separation": "Stage separation.", "upper_ignition": "Second stage ignition.", "fairing": "Fairing separation.", "cutoff": "Second stage cutoff.", "circularization": "Circularization burn at apogee.", "circularization_cutoff": "Orbit circularized.", "payload_separation": "Payload separation."}
## Total playback length of the ascent, set from the simulated flight.
var ascent_duration := 40.0
var rng := RandomNumberGenerator.new()
var countdown := 10.0
var elapsed := 0.0
var ignited := false
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
var _upper_flame: MeshInstance3D
var _payload: Node3D
var _camera: Camera3D
var _flash: MeshInstance3D
var _status: Label
var _skip: Button
var _start: Button
var _warning: Label
var _save_retry: Button
var _failure_timer := 0.0
var _camera_yaw := 0.44
var _camera_pitch := 0.13
var _camera_distance := 1.9
var _camera_dragging := false
var _launch_view: SubViewportContainer
var _station: Node3D
var _flight: Control
var _trajectory: Dictionary
var _segments: Array[Dictionary] = []
var _events_done: Dictionary = {}
var _debris: Array[Dictionary] = []
var _sim_time := 0.0
var _model: Node3D
var _payload_view_distance := 4.0
## Floating origin: the rocket stays at the render origin and _anchor, which holds Earth, the pad
## and the map view, moves the other way. Single-precision positions 6,000 km from the origin
## round to half a metre, which would shake a close-up camera.
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
		set_process(false)
		return
	var validator = preload("res://scripts/BuildStats.gd").new()
	for item in validator.run_readiness_review(build, mission):
		if item.status == "FAIL":
			_status.text = "Build is not flight ready. Return to Mission Select."
			_start.disabled = true
			set_process(false)
			return
	build.stats = validator.calculate_stats(build, mission)
	if mission.get("targetOrbit", "") not in ["LEO", "SSO", "GEO", "GTO"]:
		_status.text = "This mission requires its dedicated lunar flight destination."
		_start.disabled = true
		set_process(false)
		return
	can_skip = GameManager.has_launched_once
	rocket_height = {"launcher_electron":18.0, "launcher_vega_c":35.0, "launcher_falcon_9":70.0}.get(build.launcher.id, 18.0)
	focus_height = rocket_height * 0.5
	_upper_focus = rocket_height * 0.75
	_simulate_ascent(build, mission)
	rng.randomize()
	_create_world()

## Simulates the whole flight once and lays out its playback timeline.
func _simulate_ascent(build: Dictionary, mission: Dictionary) -> void:
	var ascent: Dictionary = build.launcher.ascent
	_trajectory = ASCENT.simulate(ascent, float(build.stats.get("wet_mass_kg", 0.0)), ASCENT.target_for(mission, ascent))
	var events: Dictionary = _trajectory.events
	var powered_end: float = events.cutoff + 3.0
	_segments = [{"sim": Vector2(0.0, powered_end), "play": POWERED_PLAYBACK}]
	var final_start := powered_end
	if events.has("circularization"):
		final_start = maxf(powered_end, events.circularization - 3.0)
		_segments.append({"sim": Vector2(powered_end, final_start), "play": COAST_PLAYBACK})
	_segments.append({"sim": Vector2(final_start, events.end), "play": (events.end - final_start) / FINAL_PLAYBACK_RATE})
	ascent_duration = 0.0
	for segment in _segments:
		ascent_duration += segment.play

func sim_time_at(playback: float) -> float:
	var start := 0.0
	for segment in _segments:
		if playback <= start + segment.play:
			return lerpf(segment.sim.x, segment.sim.y, clampf((playback - start) / segment.play, 0.0, 1.0))
		start += segment.play
	return _segments.back().sim.y

## Playback second at which a simulated event happens, or -1 if the flight has no such event.
func event_time(event: String) -> float:
	if not _trajectory.events.has(event):
		return -1.0
	var t: float = _trajectory.events[event]
	var start := 0.0
	for segment in _segments:
		if t <= segment.sim.y:
			return start + segment.play * (t - segment.sim.x) / maxf(0.001, segment.sim.y - segment.sim.x)
		start += segment.play
	return ascent_duration

func _create_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var bar := HBoxContainer.new()
	layout.add_child(bar)
	var back := Button.new()
	back.text = "< Mission Select"
	back.pressed.connect(func():
		if not ignited: get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")
	)
	bar.add_child(back)
	_start = Button.new()
	_start.text = "Launch now (Space)"
	_start.pressed.connect(ignite)
	bar.add_child(_start)
	_skip = Button.new()
	_skip.text = "Skip ascent"
	_skip.visible = false
	_skip.pressed.connect(skip_ascent)
	bar.add_child(_skip)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("279af1"))
	layout.add_child(_status)
	_warning = Label.new()
	_warning.add_theme_color_override("font_color", Color("ff8811"))
	layout.add_child(_warning)
	_save_retry = Button.new()
	_save_retry.text = "Retry campaign save"
	_save_retry.visible = false
	_save_retry.pressed.connect(_retry_save)
	layout.add_child(_save_retry)
	var container := SubViewportContainer.new()
	_launch_view = container
	container.focus_mode = Control.FOCUS_ALL
	container.gui_input.connect(_camera_input)
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_root3d = Node3D.new()
	viewport.add_child(_root3d)

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
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("0b0e14")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8192a8")
	env.environment.ambient_light_energy = 0.7
	MODEL_LIBRARY.use_sky_reflections(env.environment)
	_root3d.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-25,0)
	_root3d.add_child(light)
	_anchor = Node3D.new()
	_anchor.name = "EarthAnchor"
	_root3d.add_child(_anchor)
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = EARTH_RADIUS_M
	sphere.height = EARTH_RADIUS_M * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	planet.mesh = sphere
	planet.position.y = -EARTH_RADIUS_M - 2.0
	planet.material_override = _material(Color("2462b3"))
	_anchor.add_child(planet)
	_station = Node3D.new()
	_station.name = "LaunchStation"
	_anchor.add_child(_station)
	_box(_station, Vector3(35, 1, 35), Vector3(0,-0.5,0), Color("454f5b"))
	_box(_station, Vector3(2, rocket_height*0.85, 2), Vector3(-rocket_height*0.16,rocket_height*0.425,0), Color("596675"))
	_rocket = Node3D.new()
	_root3d.add_child(_rocket)
	var build: Dictionary = GameManager.current_build
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
	_add_flame(_stage, _stage.find_child("exhaust_stage_1", true, false) as Node3D).name = "Flame"
	var upper := model.find_child("exhaust_stage_2", true, false) as Node3D
	if upper:
		_upper_flame = _add_flame(upper.get_parent() as Node3D, upper, 0.35)
	var mount := model.find_child("payload_mount", true, false) as Node3D
	_payload = SPACECRAFT.build(build.bus, build.installed_components)
	if mount and _payload:
		_payload.name = "Payload"
		mount.add_child(_payload)
		var dims := SPACECRAFT.dimensions_of(build.bus)
		# Front end up, so end-mounted antennas deploy clear of the payload adapter.
		_payload.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, dims.z / 2.0, 0))
		_payload_view_distance = maxf(dims.x, maxf(dims.y, dims.z)) * 6.0

func _add_flame(parent: Node3D, exhaust: Node3D, size := 1.0) -> MeshInstance3D:
	var height := rocket_height * 0.12 * size
	var flame := _cylinder(parent, rocket_height * 0.027 * size, height, 0.0, Color("ffb300"), true)
	flame.position = parent.to_local(exhaust.global_position) + Vector3(0, -height / 2.0, 0)
	flame.rotation.z = PI
	flame.material_override = _material(Color("ffb300"), true)
	flame.visible = false
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
	var flame := _cylinder(_stage, radius*0.6, rocket_height*0.12, -rocket_height*0.12, Color("ffb300"), true)
	flame.rotation.z = PI
	flame.material_override = _material(Color("ffb300"), true)
	flame.name = "Flame"
	flame.visible = false
	var upper_exhaust := Node3D.new()
	upper_exhaust.position.y = rocket_height * 0.5
	_rocket.add_child(upper_exhaust)
	_upper_flame = _add_flame(_rocket, upper_exhaust, 0.35)

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
	failure_at = rng.randf_range(0.1, 0.9) * ascent_duration if failed else 0.0
	GameManager.has_launched_once = true
	if GameManager.save_campaign() != OK:
		_warning.text = "Could not save launch history. Retry before launch."
		_save_retry.visible = true
		_start.disabled = true
		return
	_begin_ascent()

func _retry_save() -> void:
	if GameManager.save_campaign() != OK: return
	_warning.text = ""
	_save_retry.visible = false
	_start.disabled = false
	_begin_ascent()

func _begin_ascent() -> void:
	if ignited: return
	ignited = true
	_start.disabled = true
	_skip.visible = can_skip
	_skip.disabled = failed
	var m: Dictionary = GameManager.current_mission
	var stats: Dictionary = GameManager.current_build.stats
	GameManager.last_result = {"mission_number":int(m.missionNumber), "attempt_id":GameManager.attempt_id, "launched":false, "objectives":[{"name":"Reach starting orbit", "done":false}, {"name":"Survive mission duration", "done":false}, {"name":"Mission objective", "done":false}], "total_cost_m":stats.get("cost_millions",0.0), "mass_margin_pct":stats.get("mass_margin_pct",0.0), "events_fired":[], "flight_log":[]}
	if m.has("objectives"):
		GameManager.last_result.objectives = []
		for definition in m.objectives:
			GameManager.last_result.objectives.append({"id":definition.id, "name":definition.name, "done":false})
	_log("Liftoff aboard %s (reliability %.0f%%)." % [GameManager.current_build.launcher.name, reliability*100], 0.0)
	_apply_sample(ASCENT.sample_at(_trajectory.samples, 0.0))

func _process(delta: float) -> void:
	if finished: return
	if _save_retry.visible: return
	if not ignited:
		countdown -= delta
		_status.text = "T-%.0f seconds" % ceil(maxf(0.0,countdown))
		if countdown <= 0.0: ignite()
		return
	if failed and _failure_timer > 0.0:
		_failure_timer -= delta
		_flash.scale = Vector3.ONE * (1.0 + (3.0-_failure_timer)*2.0)
		if _failure_timer <= 0.0: _finish_failure()
		return
	advance_ascent(delta)

func advance_ascent(delta: float) -> void:
	if not ignited or finished or _failure_timer > 0.0: return
	var next := minf(ascent_duration, elapsed + maxf(0.0,delta))
	if failed and next >= failure_at:
		next = failure_at
	elapsed = next
	_sim_time = sim_time_at(elapsed)
	_process_milestones(_sim_time)
	_update_debris(_sim_time)
	var sample := ASCENT.sample_at(_trajectory.samples, _sim_time)
	_apply_sample(sample)
	if failed and elapsed >= failure_at:
		_explode()
		return
	var speed: float = sample.velocity.length() / 1000.0
	var altitude: float = (sample.position.length() - EARTH_RADIUS_M) / 1000.0
	var coasting: bool = _events_done.has("cutoff") and not _events_done.has("circularization") and _trajectory.events.has("circularization")
	_status.text = "T+%s   ALT %.0f km   %.2f km/s   STAGE %d%s" % [_clock(_sim_time), altitude, speed, sample.stage + 1, "   COASTING TO APOGEE" if coasting else ""]
	_update_camera()
	if elapsed >= ascent_duration: _finish_success()

## Places the rocket at a simulated state: position on the orbital plane, nose along the thrust
## direction, and flames on whichever stage is firing.
func _apply_sample(sample: Dictionary) -> void:
	var position: Vector2 = sample.position
	var up := position.normalized()
	var axis := Vector2(up.y, -up.x) * cos(sample.pitch) + up * sin(sample.pitch)
	place_craft(position.x, position.y)
	_rocket.rotation.z = atan2(-axis.x, axis.y)
	_station.visible = position.length() - EARTH_RADIUS_M < 5000.0
	if is_instance_valid(_stage) and _stage.has_node("Flame"):
		_stage.get_node("Flame").visible = _firing("liftoff", "meco")
	if _upper_flame:
		_upper_flame.visible = _firing("upper_ignition", "cutoff") or _firing("circularization", "circularization_cutoff")

func _firing(start: String, stop: String) -> bool:
	var events: Dictionary = _trajectory.events
	return ignited and events.has(start) and _sim_time >= events[start] and _sim_time < events.get(stop, INF)

func _process_milestones(sim_time: float) -> void:
	var events: Dictionary = _trajectory.events
	for event in ["max_q", "meco", "stage_separation", "upper_ignition", "fairing", "cutoff", "circularization", "circularization_cutoff", "payload_separation"]:
		if _events_done.has(event) or not events.has(event) or events[event] > sim_time:
			continue
		_events_done[event] = true
		_log(EVENT_LOG[event], events[event])
		if event in ["stage_separation", "fairing"]:
			_apply_sample(ASCENT.sample_at(_trajectory.samples, events[event]))
		match event:
			"stage_separation": _separate_stage(events[event])
			"fairing": _separate_fairings(events[event])
			"cutoff": _clear_debris()
			"payload_separation": _separate_payload()

func _separate_stage(at: float) -> void:
	stage_separated = true
	_add_debris(_stage, at, Vector2(0.0, -2.0), 0.15)
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

## Separated hardware coasts on its own trajectory under gravity, starting from the rocket's state
## plus a separation push given in the rocket's frame (x across, y along the nose).
func _add_debris(node: Node3D, at: float, push: Vector2, spin: float) -> void:
	node.reparent(_root3d, true)
	var sample := ASCENT.sample_at(_trajectory.samples, at)
	var basis := _rocket.global_transform.basis
	var velocity: Vector2 = sample.velocity + Vector2(basis.x.x, basis.x.y) * push.x + Vector2(basis.y.x, basis.y.y) * push.y
	_debris.append({"node": node, "position": Vector2(node.global_position.x + _craft_x, node.global_position.y + _craft_y), "velocity": velocity, "spin": spin, "t": at})

## Advances each piece from its own clock to the current simulated time.
func _update_debris(sim_time: float) -> void:
	for piece in _debris:
		var remaining: float = sim_time - piece.t
		piece.t = sim_time
		var node: Node3D = piece.node
		node.rotation.z += piece.spin * remaining
		while remaining > 0.0:
			var step := minf(remaining, 0.5)
			var position: Vector2 = piece.position
			piece.velocity -= position * ASCENT.MU / pow(position.length(), 3.0) * step
			piece.position = position + piece.velocity * step
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
	advance_ascent(ascent_duration - elapsed)

func _explode() -> void:
	_status.text = "LAUNCH FAILURE"
	_status.add_theme_color_override("font_color", Color("ff8811"))
	_flash.position = _rocket.position
	_flash.visible = true
	_rocket.visible = false
	_skip.disabled = true
	_failure_timer = 3.0
	_log("Launch vehicle failure.")

func _finish_failure() -> void:
	if finished: return
	finished = true
	GameManager.flight_elapsed_s = elapsed
	GameManager.last_result.launched = false
	get_tree().change_scene_to_file("res://scenes/Debrief.tscn")

func _finish_success() -> void:
	if finished: return
	finished = true
	_log("Orbital insertion nominal.")
	GameManager.last_result.launched = true
	for objective in GameManager.last_result.objectives:
		if objective.get("id", "") == "reach_orbit" or objective.get("name", "") == "Reach starting orbit": objective.done = MISSION_OBJECTIVES.reach_orbit(true)
	GameManager.flight_elapsed_s = elapsed
	var mission: Dictionary = GameManager.current_mission
	var initial := OrbitState.new()
	if mission.targetOrbit in ["GEO", "GTO"]:
		initial.semi_major_axis_km = (6621.0 + 42164.0) / 2.0
		initial.eccentricity = (42164.0 - 6621.0) / (42164.0 + 6621.0)
	else:
		initial.semi_major_axis_km = FlightSim.R_EARTH_KM + float(mission.targetAltitudeKm)
	var final_position: Vector2 = _trajectory.final.position
	initial.arg_periapsis_rad = atan2(final_position.x, final_position.y)
	GameManager.initial_orbit = initial
	var start_radius := initial.semi_major_axis_km * (1.0 - initial.eccentricity) * 1000.0
	place_craft(start_radius * sin(initial.arg_periapsis_rad), start_radius * cos(initial.arg_periapsis_rad))
	_station.visible = false
	if _upper_flame: _upper_flame.visible = false
	_clear_debris()
	_update_camera()
	_handoff_to_flight()

func _handoff_to_flight() -> void:
	# Retain the viewport, its World3D, rocket and current camera across insertion.
	var previous_camera := _camera.global_transform
	_flight = load("res://scenes/FlightView.tscn").instantiate()
	_flight.set("shared_launch", self)
	add_child(_flight)
	_flight.activate_shared_world(_launch_view, _anchor, _rocket, _camera, previous_camera, _camera_yaw, _camera_pitch, _camera_distance * rocket_height)
	for child in get_children():
		if child != _flight: child.visible = false
	_launch_view.visible = true
	_flight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## at is the simulated flight time; it defaults to now.
func _log(message: String, at: float = -1.0) -> void:
	GameManager.last_result.flight_log.append("T+%s %s" % [_clock(_sim_time if at < 0 else at), message])

func focus_point() -> Vector3:
	return _rocket.transform * Vector3(0, focus_height, 0)

## Moves the craft to a position in metres from Earth's centre (launch site on +Y). The subtraction
## happens in double precision before anything is converted to a single-precision Vector3.
func place_craft(x: float, y: float) -> void:
	_craft_x = x
	_craft_y = y
	_rocket.position = Vector3.ZERO
	_anchor.position = Vector3(-x, EARTH_RADIUS_M - y, 0.0)
	for piece in _debris:
		piece.node.position = Vector3(piece.position.x - x, piece.position.y - y, 0.0)

## The craft's position in the anchor's frame (launch site at the origin, Earth's centre below).
func craft_world_position() -> Vector3:
	return Vector3(_craft_x, _craft_y - EARTH_RADIUS_M, 0.0)

## The local horizon frame at the rocket: Y away from Earth's centre, X downrange.
func local_frame() -> Basis:
	return Basis(Vector3.BACK, -atan2(_craft_x, _craft_y))

## Camera position relative to the focus point, orbiting in the local horizon frame so Earth
## stays below the rocket as it travels around the planet.
func camera_offset(distance: float, yaw: float, pitch: float) -> Vector3:
	return local_frame() * (Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance)

## A close spacecraft view once the payload has separated, otherwise the whole rocket.
func spacecraft_view_distance() -> float:
	return _payload_view_distance if payload_separated() else rocket_height * 1.9

func payload_separated() -> bool:
	return _events_done.has("payload_separation") and _payload != null

## Size of what is flying: the separated spacecraft, or the whole rocket.
func spacecraft_size() -> float:
	return _payload_view_distance / 6.0 if payload_separated() else rocket_height

func _update_camera() -> void:
	var target := focus_point()
	_camera.position = target + camera_offset(rocket_height * _camera_distance, _camera_yaw, _camera_pitch)
	_camera.look_at(target, local_frame().y)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE: ignite()

func _camera_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed: _launch_view.grab_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT: _camera_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: _camera_distance = maxf(0.35, _camera_distance * 0.9)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _camera_distance = minf(8.0, _camera_distance * 1.1)
	elif event is InputEventMouseMotion and _camera_dragging:
		_camera_yaw -= event.relative.x * 0.01
		_camera_pitch = clampf(_camera_pitch + event.relative.y * 0.01, -1.4, 1.4)
	if _camera != null: _update_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed: _camera_dragging = false
