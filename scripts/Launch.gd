extends Control

const ASCENT_SECONDS := 15.0
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
var _root3d: Node3D
var _rocket: Node3D
var _stage: Node3D
var _fairing_left: Node3D
var _fairing_right: Node3D
var _camera: Camera3D
var _flash: MeshInstance3D
var _status: Label
var _skip: Button
var _start: Button
var _warning: Label
var _save_retry: Button
var _failure_timer := 0.0

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
	rng.randomize()
	_create_world()

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
	_status.add_theme_color_override("font_color", Color("00e5ff"))
	layout.add_child(_status)
	_warning = Label.new()
	_warning.add_theme_color_override("font_color", Color("ffb300"))
	layout.add_child(_warning)
	_save_retry = Button.new()
	_save_retry.text = "Retry campaign save"
	_save_retry.visible = false
	_save_retry.pressed.connect(_retry_save)
	layout.add_child(_save_retry)
	var container := SubViewportContainer.new()
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
	_root3d.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-25,0)
	_root3d.add_child(light)
	_box(_root3d, Vector3(35, 1, 35), Vector3(0,-1,0), Color("454f5b"))
	_box(_root3d, Vector3(2, rocket_height*0.85, 2), Vector3(-rocket_height*0.16,rocket_height*0.425,0), Color("596675"))
	_rocket = Node3D.new()
	_root3d.add_child(_rocket)
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
	_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = radius
	flash_mesh.height = radius*2
	_flash.mesh = flash_mesh
	_flash.material_override = _material(Color("ffb300"), true)
	_flash.visible = false
	_root3d.add_child(_flash)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 5000
	_root3d.add_child(_camera)
	_update_camera()

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
	failure_at = rng.randf_range(0.1, 0.9) * ASCENT_SECONDS if failed else 0.0
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
	_stage.get_node("Flame").visible = true
	var m: Dictionary = GameManager.current_mission
	var stats: Dictionary = GameManager.current_build.stats
	GameManager.last_result = {"mission_number":int(m.missionNumber), "attempt_id":GameManager.attempt_id, "launched":false, "objectives":[{"name":"Reach starting orbit", "done":false}, {"name":"Survive mission duration", "done":false}, {"name":"Mission objective", "done":false}], "total_cost_m":stats.get("cost_millions",0.0), "mass_margin_pct":stats.get("mass_margin_pct",0.0), "events_fired":[], "flight_log":[]}
	_log("Liftoff aboard %s (reliability %.0f%%)." % [GameManager.current_build.launcher.name, reliability*100])

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
	var next := minf(ASCENT_SECONDS, elapsed + maxf(0.0,delta))
	if failed and next >= failure_at:
		_process_milestones(failure_at)
		elapsed = failure_at
		_explode()
		return
	_process_milestones(next)
	elapsed = next
	var progress := elapsed / ASCENT_SECONDS
	_rocket.position = Vector3(rocket_height*2.0*progress*progress,rocket_height*5.0*progress,0)
	_rocket.rotation.z = -progress*0.8
	_status.text = "ASCENT  T+%.1f s" % elapsed
	_update_camera()
	if elapsed >= ASCENT_SECONDS: _finish_success()

func _process_milestones(time: float) -> void:
	if not stage_separated and time >= 0.4*ASCENT_SECONDS:
		stage_separated = true
		_stage.reparent(_root3d, true)
		_stage.get_node("Flame").visible = false
		create_tween().tween_property(_stage,"position:y",_stage.position.y-rocket_height*2,4.0)
		_log("Stage separation nominal.", 6.0)
	if not fairing_separated and time >= 0.6*ASCENT_SECONDS:
		fairing_separated = true
		for fairing in [_fairing_left,_fairing_right]:
			fairing.reparent(_root3d, true)
			var direction := -1.0 if fairing == _fairing_left else 1.0
			create_tween().tween_property(fairing,"position:x",fairing.position.x + direction*rocket_height,4.0)
		_log("Fairing separation nominal.", 9.0)

func skip_ascent() -> void:
	if not ignited or failed or not can_skip or finished: return
	advance_ascent(ASCENT_SECONDS - elapsed)

func _explode() -> void:
	_status.text = "LAUNCH FAILURE"
	_status.add_theme_color_override("font_color", Color("ff4d4d"))
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
	GameManager.last_result.objectives[0].done = true
	GameManager.flight_elapsed_s = elapsed
	var mission: Dictionary = GameManager.current_mission
	var initial := OrbitState.new()
	if mission.targetOrbit in ["GEO", "GTO"]:
		initial.semi_major_axis_km = (6621.0 + 42164.0) / 2.0
		initial.eccentricity = (42164.0 - 6621.0) / (42164.0 + 6621.0)
	else:
		initial.semi_major_axis_km = FlightSim.R_EARTH_KM + float(mission.targetAltitudeKm)
	GameManager.initial_orbit = initial
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade,"modulate:a",1.0,0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/FlightView.tscn"))

func _log(message: String, at: float = -1.0) -> void:
	var seconds := int(elapsed if at < 0 else at)
	GameManager.last_result.flight_log.append("T+%02d:%02d %s" % [seconds / 60, seconds % 60, message])

func _update_camera() -> void:
	var target := _rocket.position + Vector3(0,rocket_height*0.5,0)
	_camera.position = target + Vector3(rocket_height*0.8,rocket_height*0.25,rocket_height*1.7)
	_camera.look_at(target,Vector3.UP)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE: ignite()
