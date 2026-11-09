extends Control

signal build_changed

const CATEGORIES := ["power", "avionics", "adcs", "comms", "propulsion", "instrument", "thermal", "landing"]
var mission: Dictionary
var launcher: Dictionary
var bus: Dictionary
var installed_components: Array[Dictionary] = []
var propellant_mass_kg: float = 0.0
var _visuals: Array[Node3D] = []
var _engine_buttons: Array[Button] = []
var _category_container: VBoxContainer
var _installed_container: VBoxContainer
var _fuel_box: VBoxContainer
var _slider: HSlider
var _spin: SpinBox
var _fuel_hint: Label
var _message: Label
var _viewport_container: SubViewportContainer
var _craft: Node3D
var _attachments: Node3D
var _camera: Camera3D
var _pitch := 0.35
var _yaw := 0.6
var _distance := 5.0
var _dragging := false
var _dimensions := Vector3.ONE
var _stats_helper = preload("res://scripts/BuildStats.gd").new()
var _telemetry: VBoxContainer
var _launch: Button
var _notice: Label
var stats: Dictionary = {}
var review: Array[Dictionary] = []

func _ready() -> void:
	mission = GameManager.current_mission if not GameManager.current_mission.is_empty() else GlobalData.get_mission(1)
	launcher = GlobalData.get_launcher(mission.get("requiredLauncher", ""))
	bus = GlobalData.get_bus(mission.get("requiredBus", ""))
	if mission.is_empty() or launcher.is_empty() or bus.is_empty():
		push_error("Workshop: mission, launcher or bus is unavailable")
		return
	_make_ui()
	_make_world()
	_refresh_parts()
	_refresh_build()
	build_changed.connect(_update_readiness)
	_update_readiness()
	GameManager.campaign_changed.connect(_refresh_parts)

func _make_ui() -> void:
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(_back)
	header.add_child(back)
	var title := Label.new()
	title.text = "  WORKSHOP   /   " + str(mission.title) + "\n  " + str(launcher.name) + "   •   " + str(bus.name)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("00e5ff"))
	header.add_child(title)
	var reset := Button.new()
	reset.text = "Reset view"
	reset.pressed.connect(_reset_camera)
	header.add_child(reset)
	_launch = Button.new()
	_launch.text = "Launch"
	_launch.disabled = true
	_launch.pressed.connect(_launch_build)
	header.add_child(_launch)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 350
	columns.add_child(left)
	var left_label := Label.new()
	left_label.text = "PARTS CATALOG"
	left.add_child(left_label)
	var part_scroll := ScrollContainer.new()
	part_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	part_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(part_scroll)
	_category_container = VBoxContainer.new()
	_category_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	part_scroll.add_child(_category_container)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(center)
	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.focus_mode = Control.FOCUS_ALL
	_viewport_container.gui_input.connect(_viewport_input)
	center.add_child(_viewport_container)
	var viewport := SubViewport.new()
	viewport.name = "SpacecraftViewport"
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(viewport)
	var objective_panel := PanelContainer.new()
	objective_panel.name = "MissionObjectivePanel"
	center.add_child(objective_panel)
	var objective_margin := MarginContainer.new()
	for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		objective_margin.add_theme_constant_override(edge, 12)
	objective_panel.add_child(objective_margin)
	var objective_content := VBoxContainer.new()
	objective_margin.add_child(objective_content)
	var objective_title := Label.new()
	objective_title.text = "MISSION OBJECTIVE  /  " + str(mission.title)
	objective_title.add_theme_color_override("font_color", Color("00e5ff"))
	objective_content.add_child(objective_title)
	var objective_brief := Label.new()
	objective_brief.text = str(mission.get("briefing", ""))
	objective_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_content.add_child(objective_brief)
	if mission.has("historyNote"):
		var history := Label.new()
		history.text = "History: " + str(mission.historyNote)
		history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		history.add_theme_color_override("font_color", Color("ffb300"))
		objective_content.add_child(history)
	var required_names: Array[String] = []
	for part_id in mission.get("requiredPartIds", []):
		required_names.append(str(GlobalData.get_part(part_id).get("name", part_id)))
	var objective_details := Label.new()
	objective_details.text = "%s  ·  %s km  ·  %s days\nRequired: %s" % [mission.get("targetOrbit", ""), mission.get("targetAltitudeKm", 0), mission.get("durationDays", 0), ", ".join(required_names)]
	objective_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_details.add_theme_color_override("font_color", Color("b7c6d7"))
	objective_content.add_child(objective_details)
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size.x = 400
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	var installed_label := Label.new()
	installed_label.text = "INSTALLED PARTS"
	right.add_child(installed_label)
	var installed_scroll := ScrollContainer.new()
	installed_scroll.custom_minimum_size.y = 240
	installed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	installed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(installed_scroll)
	_installed_container = VBoxContainer.new()
	_installed_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	installed_scroll.add_child(_installed_container)
	_fuel_box = VBoxContainer.new()
	right.add_child(_fuel_box)
	var fuel_label := Label.new()
	fuel_label.text = "PROPELLANT (kg)"
	_fuel_box.add_child(fuel_label)
	_slider = HSlider.new()
	_slider.max_value = 100.0
	_slider.step = 0.001
	_slider.value_changed.connect(set_propellant_mass)
	_fuel_box.add_child(_slider)
	_spin = SpinBox.new()
	_spin.max_value = 100.0
	_spin.step = 0.001
	_spin.allow_greater = true
	_spin.value_changed.connect(set_propellant_mass)
	_fuel_box.add_child(_spin)
	_fuel_hint = Label.new()
	_fuel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fuel_box.add_child(_fuel_hint)
	var fill := Button.new()
	fill.text = "Fill to required Δv + 10%"
	fill.pressed.connect(fill_to_required_delta_v)
	_fuel_box.add_child(fill)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color("ffb300"))
	_fuel_box.add_child(_message)
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_notice)
	var review_button := Button.new()
	review_button.text = "Run Readiness Review"
	review_button.pressed.connect(_show_review)
	right.add_child(review_button)
	_telemetry = VBoxContainer.new()
	right.add_child(_telemetry)

func _make_world() -> void:
	var viewport: SubViewport = _viewport_container.get_child(0)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111721")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4c2d9")
	environment.ambient_light_energy = 0.7
	env.environment = environment
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(light)
	var grid := ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-10, 11):
		grid.surface_add_vertex(Vector3(i, -1.5, -10))
		grid.surface_add_vertex(Vector3(i, -1.5, 10))
		grid.surface_add_vertex(Vector3(-10, -1.5, i))
		grid.surface_add_vertex(Vector3(10, -1.5, i))
	grid.surface_end()
	var grid_node := MeshInstance3D.new()
	grid_node.mesh = grid
	grid_node.material_override = _material(Color("344556"))
	world.add_child(grid_node)
	_camera = Camera3D.new()
	_camera.current = true
	world.add_child(_camera)
	var dims: Array = bus.dimensionsMeters
	_dimensions = Vector3(dims[0], dims[1], dims[2])
	_craft = Node3D.new()
	_craft.scale = Vector3.ONE * (2.0 / maxf(_dimensions.x, maxf(_dimensions.y, _dimensions.z)))
	world.add_child(_craft)
	var box := CSGBox3D.new()
	box.name = "Bus"
	box.size = _dimensions
	box.material = _material(Color("d5d9de"))
	_craft.add_child(box)
	_attachments = Node3D.new()
	_attachments.name = "Attachments"
	_craft.add_child(_attachments)
	for marker in {"mount_top": Vector3(0, _dimensions.y/2, 0), "mount_bottom": Vector3(0, -_dimensions.y/2, 0), "mount_front": Vector3(0, 0, -_dimensions.z/2), "mount_back": Vector3(0, 0, _dimensions.z/2), "mount_left": Vector3(-_dimensions.x/2, 0, 0), "mount_right": Vector3(_dimensions.x/2, 0, 0), "array_hinge_left": Vector3(-_dimensions.x/2, 0, 0), "array_hinge_right": Vector3(_dimensions.x/2, 0, 0), "engine_mount": Vector3(0, -_dimensions.y/2, 0)}:
		var point := Marker3D.new()
		point.name = marker
		point.position = {"mount_top": Vector3(0, _dimensions.y/2, 0), "mount_bottom": Vector3(0, -_dimensions.y/2, 0), "mount_front": Vector3(0, 0, -_dimensions.z/2), "mount_back": Vector3(0, 0, _dimensions.z/2), "mount_left": Vector3(-_dimensions.x/2, 0, 0), "mount_right": Vector3(_dimensions.x/2, 0, 0), "array_hinge_left": Vector3(-_dimensions.x/2, 0, 0), "array_hinge_right": Vector3(_dimensions.x/2, 0, 0), "engine_mount": Vector3(0, -_dimensions.y/2, 0)}[marker]
		if marker in ["mount_bottom", "engine_mount"]:
			point.rotation.z = PI
		elif marker == "mount_front":
			point.rotation.x = -PI / 2.0
		elif marker == "mount_back":
			point.rotation.x = PI / 2.0
		elif marker in ["mount_left", "array_hinge_left"]:
			point.rotation.z = PI / 2.0
		elif marker in ["mount_right", "array_hinge_right"]:
			point.rotation.z = -PI / 2.0
		_craft.add_child(point)
	_reset_camera()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)

func _refresh_parts() -> void:
	for child in _category_container.get_children():
		child.queue_free()
	_engine_buttons.clear()
	var groups: Dictionary = GlobalData.parts_by_subsystem(true)
	for category in CATEGORIES:
		if not groups.has(category):
			continue
		var toggle := Button.new()
		toggle.text = category.to_upper() + " [show/hide]"
		toggle.toggle_mode = true
		toggle.button_pressed = true
		_category_container.add_child(toggle)
		var entries := VBoxContainer.new()
		_category_container.add_child(entries)
		toggle.toggled.connect(func(on: bool): entries.visible = on)
		for part: Dictionary in groups[category]:
			var button := Button.new()
			button.text = "%s\n%.2f kg · +%.1f/−%.1f W · $%.2fM" % [part.name, part.massKg, part.powerGenWatts, part.powerDrawWatts, part.costMillions]
			button.tooltip_text = part.heritage
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(add_part.bind(part.id))
			entries.add_child(button)
			if part.get("thrustNewtons", 0.0) > 0.0:
				button.disabled = not _engine().is_empty()
				_engine_buttons.append(button)

func _engine() -> Dictionary:
	for part in installed_components:
		if part.get("thrustNewtons", 0.0) > 0.0:
			return part
	return {}

func add_part(part_id: String) -> bool:
	var part: Dictionary = GlobalData.get_part(part_id)
	if part.is_empty() or not GameManager.is_part_unlocked(part_id):
		return false
	if part.get("thrustNewtons", 0.0) > 0.0 and not _engine().is_empty():
		return false
	installed_components.append(part)
	_refresh_build()
	build_changed.emit()
	return true

func remove_part(index: int) -> void:
	if index < 0 or index >= installed_components.size():
		return
	var was_engine: bool = installed_components[index].get("thrustNewtons", 0.0) > 0.0
	installed_components.remove_at(index)
	if was_engine:
		propellant_mass_kg = 0.0
	_refresh_build()
	build_changed.emit()

func set_propellant_mass(kg: float) -> void:
	var value := maxf(0.0, kg) if not _engine().is_empty() and is_finite(kg) else 0.0
	if is_equal_approx(value, propellant_mass_kg):
		return
	propellant_mass_kg = value
	_sync_fuel()
	build_changed.emit()

func _sync_fuel() -> void:
	var limits: Dictionary = _stats_helper.propellant_limits(_build_data(), mission)
	# The slider covers usable headroom; the spin box still permits deliberate overloads.
	var upper := maxf(0.001, maxf(floorf(limits.maximum_kg * 1000.0) / 1000.0, propellant_mass_kg))
	_slider.set_block_signals(true)
	_spin.set_block_signals(true)
	_slider.max_value = upper
	_spin.max_value = maxf(100.0, upper)
	_slider.value = propellant_mass_kg
	_spin.value = propellant_mass_kg
	_slider.set_block_signals(false)
	_spin.set_block_signals(false)
	_fuel_hint.text = "Fuel allowance: %.3f kg, limited by %s." % [limits.maximum_kg, limits.limiting_factor]
	if float(mission.get("requiredDeltaVMps", 0.0)) <= 0.0:
		_fuel_hint.text += " This mission needs no propulsion; its launcher supplies the orbit."
	if propellant_mass_kg > limits.maximum_kg + 0.000001:
		_fuel_hint.text += " Current fuel exceeds this allowance. Reduce fuel or remove parts."

func fill_to_required_delta_v() -> void:
	var engine := _engine()
	if engine.is_empty():
		return
	var target: float = float(mission.requiredDeltaVMps) * 1.1
	var dry: float = float(bus.dryMassKg)
	for part in installed_components:
		dry += float(part.massKg)
	var q: float = FlightSim.calculate_required_propellant(1.0, target, engine.ispSeconds)
	if not is_finite(q) or q * FlightSim.TANK_MASS_RATIO >= 1.0:
		_message.text = "This engine cannot reach the target with its tank mass."
		return
	var fuel := 0.0
	for i in 4:
		fuel = FlightSim.calculate_required_propellant(dry + fuel * FlightSim.TANK_MASS_RATIO, target, engine.ispSeconds)
	fuel = maxf(fuel, dry * q / (1.0 - q * FlightSim.TANK_MASS_RATIO))
	if target > 0.0:
		fuel *= 1.000001
	_message.text = ""
	set_propellant_mass(fuel)

func _refresh_build() -> void:
	for child in _installed_container.get_children():
		_installed_container.remove_child(child)
		child.queue_free()
	var categories: Array[String] = []
	categories.assign(CATEGORIES)
	for part in installed_components:
		var subsystem: String = part.get("subsystem", "other")
		if subsystem not in categories: categories.append(subsystem)
	for category in categories:
		var indices: Array[int] = []
		for i in installed_components.size():
			if installed_components[i].get("subsystem", "other") == category: indices.append(i)
		if indices.is_empty(): continue
		var heading := Label.new()
		heading.text = category.to_upper().replace("_", " ")
		heading.add_theme_color_override("font_color", Color("00e5ff"))
		_installed_container.add_child(heading)
		for index in indices:
			var row := HBoxContainer.new()
			_installed_container.add_child(row)
			var label := Label.new()
			label.text = installed_components[index].name
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var remove := Button.new()
			remove.text = "Remove"
			remove.pressed.connect(remove_part.bind(index))
			row.add_child(remove)
	for child in _attachments.get_children():
		child.queue_free()
	_visuals.clear()
	var wing := 0
	for i in installed_components.size():
		var part := installed_components[i]
		var visual := Node3D.new()
		visual.name = "Part%d" % i
		_attachments.add_child(visual)
		_visuals.append(visual)
		var d := _dimensions
		if part.id == "pwr_gomspace_p31u":
			_box(visual, Vector3(d.x*0.85,d.y*0.85,d.z*0.03), Vector3(0,0,-d.z*0.52), Color("173f79"))
			_box(visual, Vector3(d.x*0.85,d.y*0.85,d.z*0.03), Vector3(0,0,d.z*0.52), Color("173f79"))
		elif part.subsystem == "power" and part.powerGenWatts > 0 and part.isExternal:
			var side := -1.0 if wing % 2 == 0 else 1.0
			_box(visual, Vector3(d.x,d.y*0.75,d.z*0.05), Vector3(side*d.x,0,0), Color("16447f"))
			wing += 1
		elif part.get("thrustNewtons", 0.0) > 0.0 and part.isExternal:
			var nozzle := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = d.x*0.08
			cylinder.bottom_radius = d.x*0.2
			cylinder.height = d.y*0.3
			nozzle.mesh = cylinder
			nozzle.position.y = -d.y*0.65
			nozzle.material_override = _material(Color("515e68"))
			visual.add_child(nozzle)
		elif part.subsystem == "landing" and part.id == "land_hex_gear":
			for x in [-1,1]:
				for z in [-1,1]:
					_box(visual, Vector3(d.x*0.06,d.y*0.4,d.z*0.06), Vector3(x*d.x*0.4,-d.y*0.7,z*d.z*0.4), Color("aab5be"))
					visual.get_child(visual.get_child_count() - 1).rotation.z = x * 0.3
		elif part.subsystem == "comms":
			_box(visual, Vector3(d.x*0.25,d.y*0.15,d.z*0.25), Vector3(0,d.y*0.57,0), Color("98a8b4"))
		elif part.subsystem == "instrument":
			_box(visual, Vector3(d.x*0.25,d.y*0.25,d.z*0.15), Vector3(0,0,-d.z*0.58), Color("42515c"))
	for button in _engine_buttons:
		button.disabled = not _engine().is_empty()
	_fuel_box.visible = not _engine().is_empty()
	_sync_fuel()

func _viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_viewport_container.grab_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			if event.pressed:
				_viewport_container.grab_focus()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 2.5, 12.0)
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch + event.relative.y * 0.01, -1.35, 1.35)
		_update_camera()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: _yaw -= 0.1
			KEY_RIGHT: _yaw += 0.1
			KEY_UP: _pitch -= 0.1
			KEY_DOWN: _pitch += 0.1
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: _distance *= 0.9
			KEY_MINUS, KEY_KP_SUBTRACT: _distance *= 1.1
			_: return
		_pitch = clampf(_pitch, -1.35, 1.35)
		_distance = clampf(_distance, 2.5, 12.0)
		_update_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_dragging = false

func _update_camera() -> void:
	_camera.position = Vector3(sin(_yaw)*cos(_pitch), sin(_pitch), cos(_yaw)*cos(_pitch)) * _distance
	_camera.look_at(Vector3.ZERO, Vector3.UP)

func _reset_camera() -> void:
	_yaw = 0.6
	_pitch = 0.35
	_distance = 5.0
	_update_camera()

func _back() -> void:
	var path := "res://scenes/MissionSelect.tscn"
	get_tree().change_scene_to_file(path if ResourceLoader.exists(path) else "res://scenes/MainMenu.tscn")

func _build_data() -> Dictionary:
	return {"launcher": launcher, "bus": bus, "installed_components": installed_components, "propellant_mass_kg": propellant_mass_kg}

func _update_readiness() -> void:
	var build := _build_data()
	stats = _stats_helper.calculate_stats(build, mission)
	review = _stats_helper.run_readiness_review(build, mission)
	_launch.disabled = _has_failures()
	_notice.text = ""
	for child in _telemetry.get_children():
		child.queue_free()
	var endurance := "No load" if is_inf(stats.endurance_minutes) else "%.1f min" % stats.endurance_minutes
	if mission.get("targetOrbit", "") == "SSO":
		var capacity := Label.new()
		capacity.text = "SSO capacity: %.0f kg" % stats.launcher_capacity_kg
		_telemetry.add_child(capacity)
	_add_telemetry("Mass", "%.2f / %.2f kg (%.1f%% margin)" % [stats.wet_mass_kg, stats.launcher_capacity_kg, stats.mass_margin_pct], stats.wet_mass_kg, stats.launcher_capacity_kg * 0.9, "Mass budget")
	_add_telemetry("Volume", "%.2f / %.2f L" % [stats.internal_volume_liters, stats.volume_capacity_liters], stats.internal_volume_liters, stats.volume_capacity_liters, "Volume")
	_add_telemetry("Power", "+%.1f / -%.1f W (net %.1f W)" % [stats.generation_w, stats.draw_w, stats.net_power_w], stats.draw_w, stats.generation_w, "Daylight power")
	_add_telemetry("Battery", "%.1f Wh; %s / %.1f min eclipse" % [stats.battery_wh, endurance, stats.eclipse_minutes], stats.eclipse_minutes, stats.endurance_minutes, "Eclipse endurance")
	_add_telemetry("Delta-v", "%.1f / %.1f m/s" % [stats.delta_v_mps, stats.delta_v_target_mps], stats.delta_v_target_mps, stats.delta_v_mps, "Delta-v")
	_add_telemetry("Cost", "$%.2fM / $%.2fM" % [stats.cost_millions, stats.budget_millions], stats.cost_millions, stats.budget_millions, "Budget")

func _add_telemetry(title: String, text: String, used: float, limit: float, check_name: String) -> void:
	var status := "PASS"
	for item in review:
		if item.check == check_name: status = item.status
	var color := Color("ff4d4d") if status == "FAIL" else (Color("ffb300") if status == "ADVISORY" or (is_finite(limit) and limit > 0.0 and used >= limit * 0.9) else Color("55d785"))
	var label := Label.new()
	label.text = title + ": " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	_telemetry.add_child(label)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = clampf(used / limit * 100.0, 0.0, 100.0) if is_finite(limit) and limit > 0 else 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	_telemetry.add_child(bar)

func _has_failures() -> bool:
	for item in review:
		if item.status == "FAIL": return true
	return false

func _show_review() -> void:
	var dialog: AcceptDialog = load("res://scenes/ui/ReadinessReport.tscn").instantiate()
	add_child(dialog)
	var container: VBoxContainer = dialog.get_node("Scroll/Checks")
	for item in review:
		var label := Label.new()
		label.text = "%s — %s: %s" % [item.status, item.check, item.message]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 600
		label.add_theme_color_override("font_color", Color("ff4d4d") if item.status == "FAIL" else (Color("ffb300") if item.status == "ADVISORY" else Color("55d785")))
		container.add_child(label)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(700, 600))

func _launch_build() -> void:
	_update_readiness()
	if _has_failures(): return
	var build := _build_data().duplicate(true)
	build["stats"] = stats.duplicate(true)
	GameManager.current_build = build
	if ResourceLoader.exists("res://scenes/Launch.tscn"):
		GameManager.state = GameManager.State.LAUNCH
		get_tree().change_scene_to_file("res://scenes/Launch.tscn")
	else:
		_notice.text = "Build ready. Launch sequence coming soon."
