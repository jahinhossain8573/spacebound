extends VBoxContainer

var flight: Control
var engine: Dictionary = {}
var fuel_kg := 0.0
var dry_kg := 0.0
var _value: SpinBox
var _direction: OptionButton
var _info: Label
var _execute: Button
var _apo: Button
var _peri: Button
var _busy := false
var _last_burn: Dictionary = {}

func setup(owner_flight: Control) -> void:
	flight = owner_flight
	var build: Dictionary = GameManager.current_build
	for part in build.get("installed_components", []):
		if part.get("thrustNewtons", 0.0) > 0 and part.get("ispSeconds", 0.0) > engine.get("ispSeconds", 0.0): engine = part
	fuel_kg = maxf(0.0, float(build.get("propellant_mass_kg", 0.0)))
	flight.remaining_propellant_kg = fuel_kg
	if not build.is_empty(): dry_kg = preload("res://scripts/BuildStats.gd").new().calculate_stats(build, flight.mission).dry_mass_kg
	var title := Label.new()
	title.text = "ORBITAL BURN"
	add_child(title)
	var controls := HBoxContainer.new()
	add_child(controls)
	_value = SpinBox.new()
	_value.custom_minimum_size.x = 130
	_value.step = 1
	_value.update_on_text_changed = true
	_value.suffix = "m/s"
	_value.value_changed.connect(func(_v): refresh())
	controls.add_child(_value)
	_direction = OptionButton.new()
	_direction.add_item("Prograde")
	_direction.add_item("Retrograde")
	_direction.item_selected.connect(func(_i): refresh())
	controls.add_child(_direction)
	_execute = Button.new()
	_execute.text = "Execute burn"
	_execute.pressed.connect(_on_execute)
	controls.add_child(_execute)
	_apo = Button.new()
	_apo.text = "Wait for apoapsis"
	_apo.pressed.connect(func(): flight.wait_for_apsis(true))
	controls.add_child(_apo)
	_peri = Button.new()
	_peri.text = "Wait for periapsis"
	_peri.pressed.connect(func(): flight.wait_for_apsis(false))
	controls.add_child(_peri)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	refresh()

func remaining_dv() -> float:
	return FlightSim.calculate_delta_v(dry_kg, dry_kg + fuel_kg, float(engine.get("ispSeconds", 0.0)))

func refresh() -> void:
	if _value == null or flight.orbit == null: return
	var available := remaining_dv()
	if not is_equal_approx(_value.max_value, available): _value.max_value = available
	var amount := _value.value
	var result: Dictionary = FlightSim.predict_orbit_burn(flight.orbit, amount * (-1.0 if _direction.selected == 1 else 1.0))
	var prediction := "Unavailable"
	if result.get("escaped", false): prediction = "Escape trajectory"
	elif result.has("orbit"):
		var o: OrbitState = result.orbit
		prediction = "Periapsis %.0f km / apoapsis %.0f km" % [o.semi_major_axis_km * (1.0-o.eccentricity) - FlightSim.R_EARTH_KM, o.semi_major_axis_km * (1.0+o.eccentricity) - FlightSim.R_EARTH_KM]
	_info.text = "No propulsion installed" if engine.is_empty() else "Fuel %.2f kg  |  Available Δv %.1f m/s  |  Burn %.1f s  |  %s" % [fuel_kg, available, FlightSim.burn_duration_s(dry_kg + fuel_kg, amount, engine.ispSeconds, engine.thrustNewtons), prediction]
	_execute.disabled = _busy or engine.is_empty() or amount <= 0.0 or not result.has("orbit") or flight.power_failed or flight.mission_finished or not flight._skip_result.is_empty() or flight._wait_target >= 0.0
	_apo.disabled = _busy or flight.orbit.eccentricity < 0.001 or flight._wait_target >= 0.0 or flight.power_failed or flight.mission_finished
	_peri.disabled = _apo.disabled
	var editable := not _busy and not engine.is_empty()
	if _value.editable != editable: _value.editable = editable

func execute_burn(amount: float, retrograde: bool) -> bool:
	if EventManager.blocking or flight.orbit == null or engine.is_empty() or not is_finite(amount) or amount <= 0.0 or amount > remaining_dv() + 0.000001 or flight.power_failed or flight.mission_finished or not flight._skip_result.is_empty() or flight._wait_target >= 0.0: return false
	var predicted: Dictionary = FlightSim.predict_orbit_burn(flight.orbit, -amount if retrograde else amount)
	if not predicted.has("orbit"): return false
	var new_fuel := maxf(0.0, (dry_kg + fuel_kg) * exp(-amount / (engine.ispSeconds * FlightSim.G0)) - dry_kg)
	_last_burn = {"orbit":flight.orbit.copy(), "dv":amount, "retrograde":retrograde}
	if not flight.set_orbit(predicted.orbit): return false
	fuel_kg = new_fuel
	flight.remaining_propellant_kg = fuel_kg
	flight._sunlit_pass_started = false
	var o: OrbitState = flight.orbit
	GameManager.last_result.flight_log.append("T+%.1fs %s burn %.1f m/s (%s), %.0f × %.0f km" % [flight.mission_elapsed_s, "Retrograde" if retrograde else "Prograde", amount, engine.name, o.semi_major_axis_km*(1-o.eccentricity)-FlightSim.R_EARTH_KM, o.semi_major_axis_km*(1+o.eccentricity)-FlightSim.R_EARTH_KM])
	GameManager.burn_executed.emit(amount)
	_value.set_value_no_signal(0.0)
	refresh()
	return true

func _on_execute() -> void:
	if _busy: return
	_busy = true
	var amount := _value.value
	var retrograde := _direction.selected == 1
	refresh()
	var model: Node3D = flight._shared_rocket if is_instance_valid(flight._shared_rocket) else flight._craft_visual
	var orbit: OrbitState = flight.orbit
	var before: Vector2 = FlightSim.position_on_orbit_km(orbit.semi_major_axis_km, orbit.eccentricity, orbit.time_since_periapsis_s, orbit.mu).rotated(orbit.arg_periapsis_rad)
	var after: Vector2 = FlightSim.position_on_orbit_km(orbit.semi_major_axis_km, orbit.eccentricity, orbit.time_since_periapsis_s + 0.1, orbit.mu).rotated(orbit.arg_periapsis_rad)
	var direction := (after - before).normalized() * (-1.0 if retrograde else 1.0)
	var shared := is_instance_valid(flight._shared_rocket)
	var tween := create_tween()
	if shared: tween.tween_property(model, "rotation:z", atan2(-direction.y, direction.x), 1.0)
	else: tween.tween_property(model, "rotation:y", atan2(direction.y, direction.x), 1.0)
	await tween.finished
	_busy = false
	if execute_burn(amount, retrograde):
		var flame := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		var scale_factor: float = flight.shared_launch.rocket_height if shared else 0.03
		mesh.top_radius = scale_factor * 0.015
		mesh.bottom_radius = 0.0
		mesh.height = scale_factor * 0.15
		flame.mesh = mesh
		flame.position.y = scale_factor * (0.42 if shared else -0.15)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ffb300")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame.material_override = material
		model.add_child(flame)
		get_tree().create_timer(0.5).timeout.connect(flame.queue_free)
	refresh()

func spend_avoidance_fuel(amount: float) -> bool:
	if engine.is_empty() or amount <= 0.0 or remaining_dv() < amount: return false
	fuel_kg = maxf(0.0, (dry_kg + fuel_kg) * exp(-amount / (engine.ispSeconds * FlightSim.G0)) - dry_kg)
	flight.remaining_propellant_kg = fuel_kg
	refresh()
	return true

func apply_underperformance() -> bool:
	if _last_burn.is_empty(): return false
	var corrected: Dictionary = FlightSim.predict_orbit_burn(_last_burn.orbit, _last_burn.dv * (-0.9 if _last_burn.retrograde else 0.9))
	if not corrected.has("orbit"): return false
	return flight.set_orbit(corrected.orbit)
