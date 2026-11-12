extends RefCounted

const PHYSICS = preload("res://scripts/AscentSim.gd")
const MAX_FLIGHT_S := 20000.0
const ATMOSPHERE_M := 130000.0
const CIRCULAR_TOLERANCE_M := 25000.0
const RECOVERY_CEILING_M := 105000.0
const LATE_BURN_WINDOW_S := 10.0

var stages: Array
var target: Dictionary
var ground_speed: float
var _area: float
var _fairing_mass: float
var _payload_mass: float
var _kick: float
var _staging_coast: float

var elapsed := 0.0
var px := 0.0
var py := PHYSICS.R_EARTH
var vx: float
var vy := 0.0
var pitch := PI * 0.5
var stage := 0
var fuel: float
var throttle := 1.0
var engine_lit := true
var clamped := true
var fairing_on := true
var deployed := false
var scripted := false
var hold := false
var cutoff_at := -1.0
var events: Array[Dictionary] = []
var failure := ""

var altitude := 0.0
var radial_speed := 0.0
var horizontal_speed := 0.0
var airspeed := 0.0
var air_path := PI * 0.5
var orbit_path := 0.0
var mach := 0.0
var pressure := 0.0
var thrust := 0.0
var applied_throttle := 0.0
var mass: float
var g_load := 1.0
var coast: Dictionary
var _peak_q := 0.0
var _passed_max_q := false
var _coast_to_burn := false
var _circularizing := false
var _recovery := false
var _booster_recovery := false
var _upper_recovery := false

func _init(ascent: Dictionary, payload_kg: float, mission: Dictionary) -> void:
	stages = ascent.stages
	target = PHYSICS.target_for(mission, ascent)
	ground_speed = target.ground_speed
	vx = ground_speed
	_area = PI * pow(float(ascent.diameterMeters) * 0.5, 2.0)
	_fairing_mass = float(ascent.fairingMassKg)
	_payload_mass = payload_kg
	_kick = deg_to_rad(float(ascent.pitchKickDeg))
	_staging_coast = float(ascent.stagingCoastSeconds)
	fuel = float(stages[0].propellantKg)
	mass = PHYSICS.stack_mass(stages, stage, fuel, fairing_on, _fairing_mass, _payload_mass)
	_update_conditions()

func advance(dt: float, turn: float, throttle_rate: float) -> void:
	if deployed or not failure.is_empty():
		return
	if not safe_orbit():
		_coast_to_burn = false
		_circularizing = false
	_upper_recovery = _needs_upper_recovery()
	_booster_recovery = stage == 0 and (scripted or hold) and altitude < RECOVERY_CEILING_M and (
		_booster_recovery or _needs_booster_recovery()
	)
	if scripted:
		_script_controls()
		if deployed:
			return
	else:
		set_throttle(throttle + throttle_rate * dt)

	var radius := sqrt(px * px + py * py)
	var up_x := px / radius
	var up_y := py / radius
	var desired := target_pitch() if scripted or hold else pitch + turn * PHYSICS.MAX_PITCH_RATE * dt
	pitch = PI * 0.5 if clamped else rotate_toward(pitch, desired, PHYSICS.MAX_PITCH_RATE * dt)
	mass = PHYSICS.stack_mass(stages, stage, fuel, fairing_on, _fairing_mass, _payload_mass)

	var flow := PHYSICS.propellant_flow(stages[stage])
	applied_throttle = 0.0
	if engine_lit and fuel > 0.0:
		applied_throttle = lerpf(0.28, 1.0, elapsed / PHYSICS.CLAMP_HOLD_TIME) if clamped else minf(throttle, fuel / (flow * dt))
	thrust = PHYSICS.ambient_thrust(stages[stage], altitude) * applied_throttle

	var drag := PHYSICS.drag_acceleration(pressure, mach, _area, mass, airspeed) if not clamped else 0.0
	var air_rotation := ground_speed * radius / PHYSICS.R_EARTH
	var thrust_acc := thrust / mass
	var ax := (up_y * cos(pitch) + up_x * sin(pitch)) * thrust_acc - (vx - up_y * air_rotation) * drag
	var ay := (-up_x * cos(pitch) + up_y * sin(pitch)) * thrust_acc - (vy + up_x * air_rotation) * drag
	g_load = 1.0 if clamped else sqrt(ax * ax + ay * ay) / PHYSICS.G0

	var was_clamped := clamped
	elapsed += dt
	if clamped:
		var pad := PHYSICS.pad_eci_at(ground_speed, elapsed)
		px = pad[0]
		py = pad[1]
		vx = ground_speed * cos(pad[2])
		vy = -ground_speed * sin(pad[2])
		if elapsed >= PHYSICS.CLAMP_HOLD_TIME:
			clamped = false
			_emit("clamp_release")
	else:
		var next := PHYSICS.integrate(px, py, vx, vy, radius, ax, ay, dt)
		px = next[0]
		py = next[1]
		vx = next[2]
		vy = next[3]
		fuel = maxf(0.0, fuel - flow * applied_throttle * dt)
		if engine_lit and fuel <= 0.000001:
			fuel = 0.0
			set_throttle(0.0)

	_update_conditions()
	if not _passed_max_q and pressure < _peak_q * 0.98 and _peak_q > 1000.0:
		_passed_max_q = true
		_emit("max_q")
	_peak_q = maxf(pressure, _peak_q)
	if not was_clamped and altitude == 0.0 and radial_speed < 0.0:
		var contact_scale := PHYSICS.R_EARTH / sqrt(px * px + py * py)
		px *= contact_scale
		py *= contact_scale
		failure = "The spacecraft impacted Earth before reaching a safe orbit."
	elif coast.energy >= 0.0 and (stage == 0 or fuel <= 0.0):
		failure = "The spacecraft is on an escape trajectory."
	elif elapsed >= MAX_FLIGHT_S:
		failure = "Flight time limit reached before payload deployment."

func _update_conditions() -> void:
	var radius := sqrt(px * px + py * py)
	altitude = maxf(0.0, radius - PHYSICS.R_EARTH)
	radial_speed = (vx * px + vy * py) / radius
	horizontal_speed = (vx * py - vy * px) / radius
	var air_down := horizontal_speed - ground_speed * radius / PHYSICS.R_EARTH
	airspeed = sqrt(air_down * air_down + radial_speed * radial_speed)
	air_path = PI * 0.5 if airspeed < 0.5 else atan2(radial_speed, air_down)
	orbit_path = atan2(radial_speed, horizontal_speed)
	mach = airspeed / PHYSICS.speed_of_sound_mps(altitude)
	pressure = 0.5 * PHYSICS.air_density(altitude) * airspeed * airspeed
	coast = PHYSICS.coast_elements(px, py, vx, vy)

func set_throttle(value: float) -> void:
	if clamped or not engine_lit or (fuel <= 0.0 and value > 0.0):
		return
	var previous := throttle
	if previous == 0.0 and value > 0.0:
		_upper_recovery = _needs_upper_recovery()
	throttle = clampf(value, 0.0, 1.0)
	if previous > 0.0 and throttle == 0.0:
		cutoff_at = elapsed
		applied_throttle = 0.0
		thrust = 0.0
		_emit("meco" if stage == 0 else ("circularization_cutoff" if _circularizing else "cutoff"))
		if not scripted:
			_circularizing = false
			_coast_to_burn = false
	elif previous == 0.0 and throttle > 0.0:
		cutoff_at = -1.0
		if stage > 0:
			_circularizing = _coast_to_burn or _near_burn_window()
			_emit("circularization" if _circularizing else "upper_restart")

func stage_action() -> String:
	if stage == 0:
		return "Separate booster"
	if not engine_lit:
		return "Ignite upper stage"
	return "Jettison fairings" if fairing_on else "Deploy payload"

func stage_lockout() -> String:
	if clamped:
		return "Wait for liftoff."
	if stage == 0:
		if throttle > 0.0:
			return "Cut thrust before separating the booster."
		return "Wait for the booster to shut down." if elapsed - cutoff_at < PHYSICS.SEPARATION_DELAY else ""
	if not engine_lit:
		return "Wait for the booster to clear." if elapsed - cutoff_at < _staging_coast else ""
	if fairing_on:
		return "Wait until 110 km to jettison the fairings." if altitude < PHYSICS.FAIRING_ALTITUDE else ""
	if throttle > 0.0:
		return "Cut thrust before deploying the payload."
	if not safe_orbit():
		return "Raise periapsis above 130 km to deploy."
	return "Wait for the upper stage to settle." if elapsed - cutoff_at < PHYSICS.PAYLOAD_SEPARATION_DELAY else ""

func next_stage() -> bool:
	if deployed or not stage_lockout().is_empty():
		return false
	if stage == 0:
		stage += 1
		engine_lit = false
		fuel = float(stages[stage].propellantKg)
		_emit("stage_separation")
	elif not engine_lit:
		engine_lit = true
		throttle = 1.0
		cutoff_at = -1.0
		_emit("upper_ignition")
	elif fairing_on:
		fairing_on = false
		_emit("fairing")
	else:
		deployed = true
		_emit("payload_separation")
	mass = PHYSICS.stack_mass(stages, stage, fuel, fairing_on, _fairing_mass, _payload_mass)
	return true

func _emit(event: String) -> void:
	events.append({"id": event, "t": elapsed})

func safe_orbit() -> bool:
	return coast.energy < 0.0 and coast.periapsis >= PHYSICS.R_EARTH + ATMOSPHERE_M

func target_reached(precise := false) -> bool:
	var pe := float(target.apogee) if target.circularize else float(target.radius)
	var pe_tolerance := 2000.0 if precise and target.circularize else CIRCULAR_TOLERANCE_M
	var ap_tolerance := CIRCULAR_TOLERANCE_M if target.circularize else 500000.0
	if precise:
		ap_tolerance = 2000.0 if target.circularize else 15000.0
	return safe_orbit() and absf(coast.periapsis - pe) <= pe_tolerance and absf(coast.apoapsis - float(target.apogee)) <= ap_tolerance and horizontal_speed > 0.0

func target_pitch() -> float:
	if stage == 0:
		var gravity_turn := PHYSICS.booster_pitch(altitude, airspeed, air_path, _kick)
		if _booster_recovery or _needs_booster_recovery():
			# Rebuild a climb before turning downrange again. Following air-relative
			# prograde here would preserve the shallow or descending trajectory.
			var recovery_pitch := deg_to_rad(42.0 + 43.0 * exp(-altitude / 17000.0))
			recovery_pitch *= 1.0 - smoothstep(65000.0, RECOVERY_CEILING_M, altitude)
			return maxf(gravity_turn, maxf(recovery_pitch, _climb_pitch_floor()))
		return gravity_turn
	if coast.energy >= 0.0:
		return wrapf(orbit_path + PI, -PI, PI)
	if _needs_upper_recovery():
		return _upper_recovery_pitch()
	if scripted and _recovery:
		return 0.0 if horizontal_speed >= 0.0 else PI
	if safe_orbit() and _overshot_target():
		return wrapf(orbit_path + PI, -PI, PI)
	if safe_orbit() and (_circularizing or _coast_to_burn or _near_burn_window()):
		# Level at apoapsis, with a small radial correction if the burn starts early or late.
		return clampf(-radial_speed / maxf(circularization_dv(), 70.0), -0.18, 0.18)
	if not engine_lit:
		return air_path if altitude < 50000.0 else orbit_path
	var engine: Dictionary = stages[stage]
	return PHYSICS.upper_stage_pitch(
		pitch, altitude + PHYSICS.R_EARTH, radial_speed, horizontal_speed,
		PHYSICS.ambient_thrust(engine, altitude) / mass, mass,
		PHYSICS.propellant_flow(engine), float(engine.ispVacuumS), target
	)

func _needs_upper_recovery() -> bool:
	return (stage > 0 and engine_lit and fuel > 0.0 and radial_speed < 0.0
		and not safe_orbit() and coast.energy < 0.0
		and (_upper_recovery or throttle == 0.0 or altitude < 75000.0 or coast.apoapsis >= float(target.apogee)))

func _upper_recovery_pitch() -> float:
	# Raise periapsis with tangential thrust while arresting descent near the atmosphere.
	var radius := PHYSICS.R_EARTH + altitude
	var effective_gravity := PHYSICS.MU / (radius * radius) - horizontal_speed * horizontal_speed / radius
	var drag := PHYSICS.drag_acceleration(pressure, mach, _area, mass, airspeed)
	var arrest_time := clampf((altitude - ATMOSPHERE_M) / -radial_speed, 5.0, 30.0)
	var thrust_accel := PHYSICS.ambient_thrust(stages[stage], altitude) / mass
	return asin(clampf((effective_gravity + drag * radial_speed - radial_speed / arrest_time) / thrust_accel, 0.0, 1.0))

func _needs_booster_recovery() -> bool:
	return not clamped and altitude >= PHYSICS.VERTICAL_CLEAR_ALTITUDE and (
		(altitude < 30000.0 and air_path < deg_to_rad(42.0))
		or (altitude < 75000.0 and radial_speed < 0.0)
	)

func _climb_pitch_floor() -> float:
	# Following a shallow or descending velocity vector in dense air keeps the rocket diving.
	# Restore climb rate while leaving the nominal gravity turn in control when it is climbing.
	var atmosphere_weight := 1.0 - smoothstep(45000.0, RECOVERY_CEILING_M, altitude)
	var climb_speed := minf(400.0, 100.0 + altitude * 0.007) * atmosphere_weight
	var deficit := climb_speed - radial_speed
	if deficit <= 0.0 or atmosphere_weight <= 0.0:
		return -PI * 0.5
	var radius := PHYSICS.R_EARTH + altitude
	var effective_gravity := PHYSICS.MU / (radius * radius) - horizontal_speed * horizontal_speed / radius
	var drag := PHYSICS.drag_acceleration(pressure, mach, _area, mass, airspeed)
	var needed := effective_gravity + drag * radial_speed + deficit / 8.0
	var full_thrust_accel := PHYSICS.ambient_thrust(stages[stage], altitude) / mass
	var climb_pitch := asin(clampf(needed / full_thrust_accel, 0.0, 1.0))
	return climb_pitch * smoothstep(0.0, 85.0, deficit) * atmosphere_weight

func circularization_dv() -> float:
	if not is_finite(coast.apoapsis):
		return 0.0
	var apo := float(coast.apoapsis)
	var desired_speed := sqrt(PHYSICS.MU / apo)
	if not target.circularize and apo > float(target.radius):
		desired_speed = sqrt(PHYSICS.MU * (2.0 / apo - 2.0 / (apo + float(target.radius))))
	return maxf(0.0, desired_speed - absf(coast.momentum) / apo)

func burn_duration() -> float:
	var engine: Dictionary = stages[stage]
	var isp := float(engine.ispVacuumS)
	return mass / PHYSICS.propellant_flow(engine) * (1.0 - exp(-circularization_dv() / (isp * PHYSICS.G0)))

func remaining_dv() -> float:
	return float(stages[stage].ispVacuumS) * PHYSICS.G0 * log(mass / maxf(1.0, mass - fuel))

func _near_burn_window() -> bool:
	if stage == 0 or not _ready_to_coast():
		return false
	var since_apoapsis := float(coast.phase) - float(coast.period) * 0.5
	return (float(coast.to_apoapsis) <= maxf(4.0, burn_duration() * 0.5 + 2.0)
		or (since_apoapsis >= 0.0 and since_apoapsis <= LATE_BURN_WINDOW_S))

func _overshot_target() -> bool:
	var goal_pe := float(target.apogee) if target.circularize else float(target.radius)
	var ap_tolerance := CIRCULAR_TOLERANCE_M if target.circularize else 500000.0
	return coast.apoapsis > float(target.apogee) + ap_tolerance or coast.periapsis > goal_pe + CIRCULAR_TOLERANCE_M

func _ready_to_coast() -> bool:
	var goal := float(target.apogee) - 500.0
	if not safe_orbit() or coast.apoapsis < goal or circularization_dv() > remaining_dv():
		return false
	# A steep suborbital ascent can reach the apoapsis target long before insertion.
	var periapsis_floor := float(target.radius) - CIRCULAR_TOLERANCE_M
	return coast.periapsis >= periapsis_floor if target.circularize else coast.periapsis < periapsis_floor

func warp_limit() -> int:
	if _near_burn_window() or _needs_upper_recovery():
		return 1
	if clamped or altitude < 70000.0 or (engine_lit and throttle > 0.0) or (stage == 0 or not engine_lit):
		return 10
	return 250 if safe_orbit() else 10

func step_size() -> float:
	if _circularizing and throttle > 0.0 or (stage > 0 and throttle > 0.0 and coast.apoapsis > PHYSICS.R_EARTH + (float(target.apogee) - PHYSICS.R_EARTH) * 0.9):
		return PHYSICS.FINE_STEP
	return PHYSICS.STEP

func _script_controls() -> void:
	if clamped:
		return
	if stage == 0 and fuel > 0.0 and throttle == 0.0:
		set_throttle(1.0)
	if stage == 0 or not engine_lit:
		next_stage()
		return
	if fairing_on and altitude >= PHYSICS.FAIRING_ALTITUDE:
		next_stage()

	if target_reached(true) or (safe_orbit() and fuel <= 0.0):
		set_throttle(0.0)
		next_stage()
		return

	# A ballistic apoapsis overshoot alone says little about insertion speed.
	if altitude > ATMOSPHERE_M and (coast.energy >= 0.0 or (_overshot_target() and safe_orbit())):
		_recovery = true
	if _recovery and safe_orbit():
		set_throttle(0.0)
		next_stage()
		return
	if coast.energy >= 0.0 or _recovery:
		set_throttle(1.0 if absf(angle_difference(pitch, target_pitch())) < deg_to_rad(12.0) else 0.0)
		return

	if _needs_upper_recovery():
		set_throttle(1.0)
		return

	if not _coast_to_burn and not _circularizing and _ready_to_coast():
		_coast_to_burn = true
		set_throttle(0.0)
	if _coast_to_burn and not _circularizing:
		if _near_burn_window():
			_circularizing = true
			set_throttle(1.0)
		return

	# Fine steps near the target prevent large changes in projected apogee on fast transfer burns.
	set_throttle(1.0)

func guidance() -> String:
	if clamped:
		return "Hold vertical while the engines spool."
	if stage == 0:
		if fuel <= 0.0:
			return "Booster cutoff. Use the staging panel to separate."
		if throttle == 0.0:
			return "Booster still has fuel. Press Z to resume the ascent."
		if altitude < PHYSICS.VERTICAL_CLEAR_ALTITUDE or airspeed < PHYSICS.VERTICAL_RISE_SPEED:
			return "Climb vertically to clear the tower."
		if _booster_recovery or _needs_booster_recovery():
			return "Climbing to recover the ascent. Follow the pitch marker."
		if not _passed_max_q:
			return "Pitch toward downrange and follow the target marker through Max-Q."
		return "Past Max-Q. Follow the gravity turn until booster cutoff."
	if not engine_lit:
		return "Ignite the upper stage once the booster clears."
	if _needs_upper_recovery() or (fuel > 0.0 and throttle == 0.0 and coast.energy < 0.0 and not safe_orbit()):
		var hazard := "Earth impact" if coast.periapsis <= PHYSICS.R_EARTH else "Atmospheric entry"
		return "%s predicted if coasting. Follow the pitch marker and apply full thrust with Z." % hazard
	if target_reached():
		if throttle > 0.0:
			return "Target orbit achieved. Cut thrust with X."
		if fairing_on:
			return "Target orbit achieved. Jettison the fairings from the staging panel."
		return "Target orbit achieved. Deploy from the staging panel."
	if fuel <= 0.0:
		return "Upper stage fuel exhausted. " + ("Safe orbit. Deploy when ready." if safe_orbit() else "A safe orbit is out of reach.")
	if coast.energy >= 0.0:
		return "Escape trajectory. Cut thrust and turn retrograde to reduce speed."
	if fairing_on and altitude >= PHYSICS.FAIRING_ALTITUDE:
		return "Above 110 km. Jettison the fairings using the staging panel."
	if safe_orbit() and _overshot_target():
		if coast.apoapsis > float(target.apogee) + (CIRCULAR_TOLERANCE_M if target.circularize else 500000.0):
			return "Apoapsis overshot. Use a short retrograde burn at periapsis to lower it."
		return "Periapsis overshot. Use a short retrograde burn at apoapsis to lower it."
	if safe_orbit() and (_ready_to_coast() or _circularizing):
		var time_to_burn := maxf(0.0, float(coast.to_apoapsis) - burn_duration() * 0.5)
		if _circularizing or _near_burn_window():
			return "Burn prograde with Z to raise periapsis. About %.0f m/s left. Cut thrust with X at the target." % circularization_dv()
		var action := "Cut thrust and coast with X." if throttle > 0.0 else "Coast toward apoapsis."
		return "%s Burn in %s for about %.0f s (%.0f m/s)." % [action, format_time(time_to_burn), burn_duration(), circularization_dv()]
	if safe_orbit() and throttle == 0.0:
		return "Safe orbit. Raise the low apsis before deploying to meet the mission target."
	if not safe_orbit() and coast.apoapsis >= float(target.apogee) - 500.0:
		return "Apoapsis is high enough. Follow the pitch marker and burn with Z until periapsis clears the atmosphere."
	if throttle == 0.0:
		return "Follow the pitch marker and press Z to continue the ascent."
	return "Follow the target marker and raise apoapsis to %.0f km." % ((float(target.apogee) - PHYSICS.R_EARTH) / 1000.0)

static func format_time(seconds: float) -> String:
	var whole := maxi(0, ceili(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]
