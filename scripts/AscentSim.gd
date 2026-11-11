extends RefCounted

## Planar 64-bit launch physics simulation:
## - Pad hold-down clamps with main-engine turbopump spool-up until TWR > 1 and full thrust
## - Thrust rising smoothly from sea-level to vacuum values as ambient pressure drops
## - Mass flow propellant burn-off, stage dry masses, and fairing mass jettison
## - Inverse-square Newtonian gravity and Mach-dependent exponential-atmosphere drag
## - Co-rotating Earth surface & atmosphere (launch site starts at +Y, rotating toward +X)
## All internal kinematics use 64-bit GDScript floats to avoid 32-bit Vector2 quantization near 6,371 km.

const MU := 3.986004418e14
const R_EARTH := 6371000.0
const G0 := 9.80665
const SCALE_HEIGHT := 8500.0
const SEA_LEVEL_DENSITY := 1.225
const DRAG_COEFFICIENT := 0.38
const CLAMP_HOLD_TIME := 1.2
const STEP := 0.05
const FINE_STEP := 0.002
const COAST_STEP := 1.0
const LIFTOFF_SAMPLE_INTERVAL := 0.05
const BURN_SAMPLE_INTERVAL := 0.25
const COAST_SAMPLE_INTERVAL := 10.0
const VERTICAL_RISE_SPEED := 60.0
const VERTICAL_CLEAR_ALTITUDE := 180.0
const MAX_PITCH_RATE := deg_to_rad(2.0)
const FAIRING_ALTITUDE := 110000.0
const INSERTION_ALTITUDE := 200000.0
const SEPARATION_DELAY := 1.0
const PAYLOAD_SEPARATION_DELAY := 6.0
const COAST_AFTER_PAYLOAD := 6.0
const GTO_PERIGEE_M := 6621000.0
const GTO_APOGEE_M := 42164000.0
const SSO_GROUND_SPEED := -50.0

## The transfer orbit the upper stage's first burn aims for (perigee radius and speed, apogee
## radius), whether to circularize at apogee afterwards, and the ground speed the launch site
## gives: Earth's rotation helps eastward launches and slightly hinders sun-synchronous ones.
static func target_for(mission: Dictionary, ascent: Dictionary) -> Dictionary:
	if mission.get("targetOrbit", "") in ["GEO", "GTO"]:
		return _transfer(GTO_PERIGEE_M, GTO_APOGEE_M, false, float(ascent.siteRotationMps))
	var radius := R_EARTH + float(mission.get("targetAltitudeKm", 400.0)) * 1000.0
	var insertion := minf(radius, R_EARTH + INSERTION_ALTITUDE)
	var ground_speed := SSO_GROUND_SPEED if mission.get("targetOrbit", "") == "SSO" else float(ascent.siteRotationMps)
	return _transfer(insertion, radius, radius > insertion, ground_speed)

static func _transfer(perigee: float, apogee: float, circularize: bool, ground_speed: float) -> Dictionary:
	var semi_major := (perigee + apogee) / 2.0
	return {"radius": perigee, "speed": sqrt(MU * (2.0 / perigee - 1.0 / semi_major)), "apogee": apogee, "circularize": circularize, "ground_speed": ground_speed}

static func apogee_radius(position: Vector2, velocity: Vector2) -> float:
	return apogee_radius_64(position.x, position.y, velocity.x, velocity.y)

static func apogee_radius_64(px: float, py: float, vx: float, vy: float) -> float:
	var radius: float = sqrt(px * px + py * py)
	var energy: float = (vx * vx + vy * vy) * 0.5 - MU / radius
	if energy >= 0.0:
		return INF
	var momentum: float = px * vy - py * vx
	var eccentricity: float = sqrt(maxf(0.0, 1.0 + 2.0 * energy * momentum * momentum / (MU * MU)))
	return -MU / (2.0 * energy) * (1.0 + eccentricity)

static func speed_of_sound_mps(altitude_m: float) -> float:
	if altitude_m < 11000.0:
		return lerpf(340.3, 295.1, clampf(altitude_m / 11000.0, 0.0, 1.0))
	if altitude_m < 25000.0:
		return 295.1
	if altitude_m < 47000.0:
		return lerpf(295.1, 329.8, (altitude_m - 25000.0) / 22000.0)
	return 300.0

static func mach_drag_cd(mach: float) -> float:
	if mach < 0.8:
		return 0.30
	if mach < 1.15:
		return lerpf(0.30, 0.52, (mach - 0.8) / 0.35)
	if mach < 2.5:
		return lerpf(0.52, 0.28, (mach - 1.15) / 1.35)
	return 0.25

## ECI coordinates (x, y) of the co-rotating launch pad on Earth's surface at simulated time t.
static func pad_eci_at(ground_speed: float, t: float) -> Array[float]:
	var angle: float = (ground_speed / R_EARTH) * t
	return [R_EARTH * sin(angle), R_EARTH * cos(angle), angle]

## Returns {samples, events, final, depleted, ground_speed}.
static func simulate(ascent: Dictionary, payload_kg: float, target: Dictionary) -> Dictionary:
	var stages: Array = ascent.stages
	var area: float = PI * pow(float(ascent.diameterMeters) / 2.0, 2.0)
	var fairing_mass: float = float(ascent.get("fairingMassKg", 0.0))
	var kick: float = deg_to_rad(float(ascent.pitchKickDeg))
	var target_apogee: float = float(target.apogee)
	var circularize: bool = bool(target.circularize)
	var ground_speed: float = float(target.ground_speed)
	var omega: float = ground_speed / R_EARTH

	var px: float = 0.0
	var py: float = R_EARTH
	var vx: float = ground_speed
	var vy: float = 0.0

	var stage := 0
	var s1_cap: float = maxf(1.0, float(stages[0].propellantKg))
	var s2_cap: float = maxf(1.0, float(stages[1].propellantKg)) if stages.size() > 1 else 1.0
	var propellant: float = float(stages[0].propellantKg)
	var fairing_on := true
	var phase := "burn"
	var pitch: float = PI / 2.0
	var t: float = 0.0
	var events := {"liftoff": 0.0}
	var samples: Array[Dictionary] = []
	var next_sample: float = 0.0
	var max_q: float = 0.0
	var depleted := false
	var climbing := false

	while t < 20000.0:
		var clamped := stage == 0 and phase == "burn" and t < CLAMP_HOLD_TIME
		if clamped:
			var pad_angle: float = omega * t
			px = R_EARTH * sin(pad_angle)
			py = R_EARTH * cos(pad_angle)
			vx = R_EARTH * omega * cos(pad_angle)
			vy = -R_EARTH * omega * sin(pad_angle)
		elif not events.has("clamp_release"):
			events["clamp_release"] = t

		var radius: float = sqrt(px * px + py * py)
		var up_x: float = px / radius
		var up_y: float = py / radius
		var down_x: float = up_y
		var down_y: float = -up_x
		var altitude: float = maxf(0.0, radius - R_EARTH)
		var vertical_speed: float = vx * up_x + vy * up_y
		var horizontal_speed: float = vx * down_x + vy * down_y
		var mass: float = _mass(stages, stage, propellant, fairing_on, fairing_mass, payload_kg)
		var density: float = SEA_LEVEL_DENSITY * exp(-altitude / SCALE_HEIGHT) if altitude < 130000.0 else 0.0

		var air_vx: float = vx - down_x * ground_speed * (radius / R_EARTH)
		var air_vy: float = vy - down_y * ground_speed * (radius / R_EARTH)
		var airspeed_sq: float = air_vx * air_vx + air_vy * air_vy
		var airspeed_mag: float = sqrt(airspeed_sq)
		var air_up: float = air_vx * up_x + air_vy * up_y
		var air_down: float = air_vx * down_x + air_vy * down_y
		var mach: float = airspeed_mag / speed_of_sound_mps(altitude)
		var cd: float = mach_drag_cd(mach)
		var dynamic_pressure: float = 0.5 * density * airspeed_sq

		var thrusting := phase in ["burn", "circularize"]
		if dynamic_pressure > max_q and not clamped:
			max_q = dynamic_pressure
			events.max_q = t

		var orbit_path: float = atan2(vertical_speed, horizontal_speed)
		var air_path: float = (PI / 2.0) if airspeed_mag < 0.5 else atan2(air_up, air_down)

		var step: float = COAST_STEP if phase == "transfer" else STEP
		if clamped or t < 25.0:
			step = STEP
		if phase == "circularize" or (phase == "burn" and stage == stages.size() - 1 and apogee_radius_64(px, py, vx, vy) > R_EARTH + (target_apogee - R_EARTH) * 0.9):
			step = FINE_STEP

		var grav_factor: float = -MU / (radius * radius * radius)
		var ax: float = px * grav_factor
		var ay: float = py * grav_factor
		var non_grav_x: float = 0.0
		var non_grav_y: float = 0.0

		if airspeed_mag > 0.5 and not clamped:
			var drag_acc: float = dynamic_pressure * cd * area / mass
			non_grav_x -= (air_vx / airspeed_mag) * drag_acc
			non_grav_y -= (air_vy / airspeed_mag) * drag_acc

		var throttle: float = 0.0
		var current_thrust: float = 0.0
		if thrusting:
			var s: Dictionary = stages[stage]
			var vacuum: float = float(s.thrustVacuumN)
			var full_thrust: float = vacuum - (vacuum - float(s.get("thrustSeaLevelN", vacuum))) * exp(-altitude / SCALE_HEIGHT)
			throttle = clampf(0.28 + 0.72 * (t / CLAMP_HOLD_TIME), 0.28, 1.0) if clamped else 1.0
			current_thrust = full_thrust * throttle
			var flow: float = vacuum / (float(s.ispVacuumS) * G0)

			var desired: float = pitch
			if clamped:
				desired = PI / 2.0
			elif phase == "circularize":
				desired = 0.0
			elif stage == 0:
				desired = PI / 2.0 if (airspeed_mag < VERTICAL_RISE_SPEED or altitude < VERTICAL_CLEAR_ALTITUDE) else minf(PI / 2.0 - kick, air_path)
			else:
				desired = _upper_stage_pitch(pitch, radius, vertical_speed, horizontal_speed, full_thrust / mass, mass, flow, float(s.ispVacuumS), target)

			pitch = move_toward(pitch, desired, MAX_PITCH_RATE * step)
			var thrust_acc: float = current_thrust / mass
			var dir_x: float = down_x * cos(pitch) + up_x * sin(pitch)
			var dir_y: float = down_y * cos(pitch) + up_y * sin(pitch)
			non_grav_x += dir_x * thrust_acc
			non_grav_y += dir_y * thrust_acc

			# Ground support umbilical supplies startup propellant while hold-down clamps are engaged.
			if not clamped:
				propellant -= flow * step
		else:
			pitch = move_toward(pitch, air_path if altitude < 50000.0 else orbit_path, MAX_PITCH_RATE * step)
			match phase:
				"staging":
					if stage == 0 and t >= events.meco + SEPARATION_DELAY:
						stage = 1
						propellant = float(stages[1].propellantKg)
						events.stage_separation = t
					if t >= events.meco + float(ascent.stagingCoastSeconds):
						phase = "burn"
						events.upper_ignition = t
				"transfer":
					if vertical_speed > 0.0:
						climbing = true
					elif climbing:
						phase = "circularize"
						events.circularization = t
				"final":
					var done: float = events.get("circularization_cutoff", events.get("cutoff"))
					if not events.has("payload_separation") and t >= done + PAYLOAD_SEPARATION_DELAY:
						events.payload_separation = t
					if events.has("payload_separation") and t >= events.payload_separation + COAST_AFTER_PAYLOAD:
						break

		if fairing_on and events.has("upper_ignition") and (altitude >= FAIRING_ALTITUDE or phase in ["transfer", "final"]):
			fairing_on = false
			events.fairing = t

		var total_ax: float = ax + non_grav_x
		var total_ay: float = ay + non_grav_y
		var next_vx: float = vx
		var next_vy: float = vy
		var next_px: float = px
		var next_py: float = py
		if clamped:
			var pad_angle: float = omega * (t + step)
			next_px = R_EARTH * sin(pad_angle)
			next_py = R_EARTH * cos(pad_angle)
			next_vx = R_EARTH * omega * cos(pad_angle)
			next_vy = -R_EARTH * omega * sin(pad_angle)
		else:
			# Symplectic Velocity-Verlet integration (conserves orbital energy & apogee across long coasts!)
			var vx_half: float = vx + 0.5 * total_ax * step
			var vy_half: float = vy + 0.5 * total_ay * step
			next_px = px + vx_half * step
			next_py = py + vy_half * step
			var next_r_verlet: float = sqrt(next_px * next_px + next_py * next_py)
			var next_grav: float = -MU / (next_r_verlet * next_r_verlet * next_r_verlet)
			var total_ax2: float = next_px * next_grav + non_grav_x
			var total_ay2: float = next_py * next_grav + non_grav_y
			next_vx = vx_half + 0.5 * total_ax2 * step
			next_vy = vy_half + 0.5 * total_ay2 * step

		if thrusting and not clamped:
			var next_r: float = sqrt(next_px * next_px + next_py * next_py)
			var v_mag_after: float = sqrt(next_vx * next_vx + next_vy * next_vy)
			if phase == "circularize" and v_mag_after >= sqrt(MU / next_r):
				phase = "final"
				events.circularization_cutoff = t + step
			elif phase == "burn" and stage == stages.size() - 1 and apogee_radius_64(next_px, next_py, next_vx, next_vy) >= target_apogee:
				events.cutoff = t + step
				phase = "transfer" if circularize else "final"
			elif propellant <= 0.0:
				propellant = 0.0
				if stage < stages.size() - 1:
					phase = "staging"
					events.meco = t + step
				else:
					depleted = true
					events[("circularization_cutoff" if phase == "circularize" else "cutoff")] = t + step
					phase = "final"

		var g_load: float = 1.0 if clamped else (sqrt(non_grav_x * non_grav_x + non_grav_y * non_grav_y) / G0)
		var s1_pct: float = (propellant / s1_cap) if stage == 0 else 0.0
		var s2_pct: float = 1.0 if stage == 0 else (propellant / s2_cap)

		if t >= next_sample:
			samples.append(_make_sample(
				t, px, py, vx, vy, pitch, air_path, orbit_path, airspeed_mag, air_up, air_down,
				stage, thrusting, throttle, current_thrust, mass, g_load, dynamic_pressure, mach, s1_pct, s2_pct, clamped
			))
			var interval := LIFTOFF_SAMPLE_INTERVAL if t < 30.0 else (COAST_SAMPLE_INTERVAL if phase == "transfer" else BURN_SAMPLE_INTERVAL)
			next_sample = t + interval

		px = next_px
		py = next_py
		vx = next_vx
		vy = next_vy

		t += step

	events.end = t
	var final_r: float = sqrt(px * px + py * py)
	var final_up_x: float = px / final_r
	var final_up_y: float = py / final_r
	var final_down_x: float = final_up_y
	var final_down_y: float = -final_up_x
	var final_vs: float = vx * final_up_x + vy * final_up_y
	var final_hs: float = vx * final_down_x + vy * final_down_y
	var final_s2_pct: float = (propellant / s2_cap) if stage > 0 else 0.0
	var final_mass: float = _mass(stages, stage, propellant, fairing_on, fairing_mass, payload_kg)
	samples.append(_make_sample(
		t, px, py, vx, vy, pitch, atan2(final_vs, final_hs), atan2(final_vs, final_hs),
		sqrt(vx * vx + vy * vy), final_vs, final_hs,
		stage, false, 0.0, 0.0, final_mass, 0.0, 0.0, 0.0, 0.0, final_s2_pct, false
	))
	return {"samples": samples, "events": events, "final": samples.back(), "depleted": depleted, "ground_speed": ground_speed}

static func _make_sample(
	t: float, px: float, py: float, vx: float, vy: float, pitch: float,
	air_path: float, orbit_path: float, air_speed: float, air_v_up: float, air_v_down: float,
	stage: int, thrusting: bool, throttle: float, thrust_n: float, mass_kg: float,
	g_load: float, q_pa: float, mach: float, s1_pct: float, s2_pct: float, clamped: bool
) -> Dictionary:
	return {
		"t": t,
		"px": px,
		"py": py,
		"vx": vx,
		"vy": vy,
		"position": Vector2(px, py),
		"velocity": Vector2(vx, vy),
		"pitch": pitch,
		"air_path": air_path,
		"orbit_path": orbit_path,
		"air_speed": air_speed,
		"air_v_up": air_v_up,
		"air_v_down": air_v_down,
		"stage": stage,
		"thrusting": thrusting,
		"throttle": throttle,
		"thrust_n": thrust_n,
		"mass_kg": mass_kg,
		"twr": thrust_n / maxf(1.0, mass_kg * G0),
		"g_load": g_load,
		"q_pa": q_pa,
		"mach": mach,
		"s1_fuel_pct": clampf(s1_pct, 0.0, 1.0),
		"s2_fuel_pct": clampf(s2_pct, 0.0, 1.0),
		"clamped": clamped
	}

## Zero-effort-miss guidance on the vertical channel: arrive at the insertion radius with no
## vertical speed when the speed target is met. Time to go comes from the rocket equation; the
## pitch is held for the last seconds, where the command would grow without bound.
static func _upper_stage_pitch(current: float, radius: float, vertical_speed: float, horizontal_speed: float, thrust_accel: float, mass: float, flow: float, isp: float, target: Dictionary) -> float:
	var target_radius: float = target.radius
	var target_speed: float = target.speed
	var time_to_go := mass / flow * (1.0 - exp(-maxf(0.0, target_speed - horizontal_speed) / (isp * G0)))
	if time_to_go < 8.0:
		return current
	var miss := target_radius - radius - vertical_speed * time_to_go
	var vertical_command := 6.0 * miss / (time_to_go * time_to_go) + 2.0 * vertical_speed / time_to_go
	var needed := vertical_command + MU / (radius * radius) - horizontal_speed * horizontal_speed / radius
	return asin(clampf(needed / thrust_accel, -0.4, 0.85))

static func _mass(stages: Array, stage: int, propellant: float, fairing_on: bool, fairing_mass: float, payload_kg: float) -> float:
	var mass := payload_kg + maxf(0.0, propellant) + (fairing_mass if fairing_on else 0.0)
	for i in range(stage, stages.size()):
		mass += float(stages[i].dryMassKg)
		if i > stage:
			mass += float(stages[i].propellantKg)
	return mass

## 64-bit Cubic Hermite interpolation of position and velocity between trajectory samples.
static func sample_at(samples: Array, t: float) -> Dictionary:
	if t <= samples[0].t:
		return samples[0]
	var low := 0
	var high := samples.size() - 1
	if t >= samples[high].t:
		return samples[high]
	while high - low > 1:
		var middle := (low + high) / 2
		if samples[middle].t <= t:
			low = middle
		else:
			high = middle
	var a: Dictionary = samples[low]
	var b: Dictionary = samples[high]
	var dt: float = maxf(0.000001, float(b.t) - float(a.t))
	var u: float = clampf((t - float(a.t)) / dt, 0.0, 1.0)
	var u2: float = u * u
	var u3: float = u2 * u

	# Cubic Hermite basis for C1-smooth 64-bit trajectory and velocity
	var h00: float = 2.0 * u3 - 3.0 * u2 + 1.0
	var h10: float = u3 - 2.0 * u2 + u
	var h01: float = -2.0 * u3 + 3.0 * u2
	var h11: float = u3 - u2

	var px: float = h00 * float(a.px) + h10 * dt * float(a.vx) + h01 * float(b.px) + h11 * dt * float(b.vx)
	var py: float = h00 * float(a.py) + h10 * dt * float(a.vy) + h01 * float(b.py) + h11 * dt * float(b.vy)

	var dh00: float = 6.0 * u2 - 6.0 * u
	var dh10: float = 3.0 * u2 - 4.0 * u + 1.0
	var dh01: float = -6.0 * u2 + 6.0 * u
	var dh11: float = 3.0 * u2 - 2.0 * u

	var vx: float = (dh00 * float(a.px) + dh01 * float(b.px)) / dt + dh10 * float(a.vx) + dh11 * float(b.vx)
	var vy: float = (dh00 * float(a.py) + dh01 * float(b.py)) / dt + dh10 * float(a.vy) + dh11 * float(b.vy)

	return {
		"t": t,
		"px": px,
		"py": py,
		"vx": vx,
		"vy": vy,
		"position": Vector2(px, py),
		"velocity": Vector2(vx, vy),
		"pitch": lerpf(float(a.pitch), float(b.pitch), u),
		"air_path": lerpf(float(a.air_path), float(b.air_path), u),
		"orbit_path": lerpf(float(a.orbit_path), float(b.orbit_path), u),
		"air_speed": lerpf(float(a.air_speed), float(b.air_speed), u),
		"air_v_up": lerpf(float(a.air_v_up), float(b.air_v_up), u),
		"air_v_down": lerpf(float(a.air_v_down), float(b.air_v_down), u),
		"stage": a.stage,
		"thrusting": a.thrusting,
		"throttle": lerpf(float(a.throttle), float(b.throttle), u) if a.thrusting == b.thrusting else float(a.throttle),
		"thrust_n": lerpf(float(a.thrust_n), float(b.thrust_n), u) if a.thrusting == b.thrusting else float(a.thrust_n),
		"mass_kg": lerpf(float(a.mass_kg), float(b.mass_kg), u),
		"twr": lerpf(float(a.twr), float(b.twr), u) if a.thrusting == b.thrusting else float(a.twr),
		"g_load": lerpf(float(a.g_load), float(b.g_load), u),
		"q_pa": lerpf(float(a.q_pa), float(b.q_pa), u),
		"mach": lerpf(float(a.mach), float(b.mach), u),
		"s1_fuel_pct": lerpf(float(a.s1_fuel_pct), float(b.s1_fuel_pct), u),
		"s2_fuel_pct": lerpf(float(a.s2_fuel_pct), float(b.s2_fuel_pct), u),
		"clamped": a.clamped and t < CLAMP_HOLD_TIME
	}
