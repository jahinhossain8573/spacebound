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
var _camera_mode := "Earth"
var _dragging := false

func _ready() -> void:
	GameManager.state = GameManager.State.FLIGHT_OPS
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

func _build_scene() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	_add_button(buttons, "< Back", func(): get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn"))
	for level in WARP_LEVELS:
		_add_button(buttons, "%dx" % level, set_warp.bind(level))
	for preset in ["Spacecraft", "Earth", "Wide"]:
		_add_button(buttons, preset, set_camera_preset.bind(preset))
	_add_button(buttons, "Reset view", _reset_view)
	_hud = Label.new()
	_hud.add_theme_color_override("font_color", Color("00e5ff"))
	layout.add_child(_hud)
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
	if orbit == null or not is_finite(real_delta_s) or real_delta_s < 0.0: return
	var elapsed := real_delta_s * warp
	mission_elapsed_s += elapsed
	var period: float = FlightSim.orbital_period_s(orbit.semi_major_axis_km, orbit.mu)
	orbit.time_since_periapsis_s = fposmod(orbit.time_since_periapsis_s + elapsed, period)
	_update_position()

func _process(delta: float) -> void:
	advance_time(delta)
	if orbit != null:
		_update_camera()
		var pixels := maxf(1.0, float(_view.size.y))
		var diameter := 8.0 * 2.0 * _camera.global_position.distance_to(_marker.global_position) * tan(deg_to_rad(_camera.fov) * 0.5) / pixels
		_marker.scale = Vector3.ONE * maxf(0.5, diameter)

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

func set_camera_preset(value: String) -> void:
	if orbit == null: return
	_camera_mode = value
	_distance = 20.0 if value == "Spacecraft" else 190.0
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
			_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 2.0, 5000.0)
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch + event.relative.y * 0.01, -1.4, 1.4)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: _yaw -= 0.1
			KEY_RIGHT: _yaw += 0.1
			KEY_UP: _pitch = maxf(-1.4, _pitch - 0.1)
			KEY_DOWN: _pitch = minf(1.4, _pitch + 0.1)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: _distance = maxf(2.0, _distance * 0.9)
			KEY_MINUS, KEY_KP_SUBTRACT: _distance = minf(5000.0, _distance * 1.1)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed: _dragging = false
