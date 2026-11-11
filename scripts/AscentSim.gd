extends RefCounted

## Planar launch simulation: thrust that rises from sea-level to vacuum values, propellant burn-off,
## inverse-square gravity and exponential-atmosphere drag. The first stage rises vertically,
## pitches over and flies a gravity turn. The upper stage burns into a transfer orbit with its
## perigee at the insertion altitude; for circular targets it coasts to apogee and burns again to
## circularize, as Electron's kick stage and Falcon 9's second stage do. Positions are metres from
## Earth's centre, with the launch site on +Y and downrange towards +X.

const MU := 3.986004418e14
const R_EARTH := 6371000.0
const G0 := 9.80665
const SCALE_HEIGHT := 8500.0
const SEA_LEVEL_DENSITY := 1.225
const DRAG_COEFFICIENT := 0.4
const STEP := 0.1
const FINE_STEP := 0.002
const COAST_STEP := 2.0
const SAMPLE_INTERVAL := 0.5
const COAST_SAMPLE_INTERVAL := 20.0
const VERTICAL_RISE_SPEED := 60.0
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
	var radius := position.length()
	var energy := velocity.length_squared() / 2.0 - MU / radius
	if energy >= 0.0:
		return INF
	var momentum := position.x * velocity.y - position.y * velocity.x
	var eccentricity := sqrt(maxf(0.0, 1.0 + 2.0 * energy * momentum * momentum / (MU * MU)))
	return -MU / (2.0 * energy) * (1.0 + eccentricity)

## Returns {samples, events, final, depleted}. Each sample is {t, position, velocity, pitch, stage,
## thrusting}, where pitch is the thrust direction above the local horizon. events maps names to
## seconds: liftoff, max_q, meco, stage_separation, upper_ignition, fairing, cutoff, and for
## circular targets circularization and circularization_cutoff; then payload_separation, end.
static func simulate(ascent: Dictionary, payload_kg: float, target: Dictionary) -> Dictionary:
	var stages: Array = ascent.stages
	var area := PI * pow(float(ascent.diameterMeters) / 2.0, 2.0)
	var kick := deg_to_rad(float(ascent.pitchKickDeg))
	var target_apogee: float = target.apogee
	var circularize: bool = target.circularize
	var ground_speed: float = target.ground_speed
	var position := Vector2(0.0, R_EARTH)
	var velocity := Vector2(ground_speed, 0.0)
	var stage := 0
	var propellant := float(stages[0].propellantKg)
	var fairing_on := true
	var phase := "burn"
	var pitch := PI / 2.0
	var t := 0.0
	var events := {"liftoff": 0.0}
	var samples: Array[Dictionary] = []
	var next_sample := 0.0
	var max_q := 0.0
	var depleted := false
	var climbing := false
	while t < 20000.0:
		var radius := position.length()
		var up := position / radius
		var downrange := Vector2(up.y, -up.x)
		var altitude := radius - R_EARTH
		var vertical_speed := velocity.dot(up)
		var horizontal_speed := velocity.dot(downrange)
		var mass := _mass(stages, stage, propellant, fairing_on, payload_kg)
		var density := SEA_LEVEL_DENSITY * exp(-altitude / SCALE_HEIGHT)
		var airspeed := velocity - downrange * ground_speed * radius / R_EARTH
		var dynamic_pressure := 0.5 * density * airspeed.length_squared()
		var thrusting := phase in ["burn", "circularize"]
		if dynamic_pressure > max_q:
			max_q = dynamic_pressure
			events.max_q = t
		if t >= next_sample:
			samples.append({"t": t, "position": position, "velocity": velocity, "pitch": pitch, "stage": stage, "thrusting": thrusting})
			next_sample = t + (COAST_SAMPLE_INTERVAL if phase == "transfer" else SAMPLE_INTERVAL)
		var acceleration := -position * MU / pow(radius, 3.0)
		if airspeed.length() > 1.0:
			acceleration -= airspeed.normalized() * dynamic_pressure * DRAG_COEFFICIENT * area / mass
		var flight_path := atan2(vertical_speed, horizontal_speed)
		var air_path := atan2(airspeed.dot(up), airspeed.dot(downrange))
		var step := COAST_STEP if phase == "transfer" else STEP
		if phase == "circularize" or phase == "burn" and stage == stages.size() - 1 and apogee_radius(position, velocity) > R_EARTH + (target_apogee - R_EARTH) * 0.9:
			step = FINE_STEP
		if thrusting:
			var s: Dictionary = stages[stage]
			var vacuum := float(s.thrustVacuumN)
			var thrust := vacuum - (vacuum - float(s.get("thrustSeaLevelN", vacuum))) * exp(-altitude / SCALE_HEIGHT)
			var flow := vacuum / (float(s.ispVacuumS) * G0)
			var desired := pitch
			if phase == "circularize":
				desired = 0.0
			elif stage == 0:
				desired = PI / 2.0 if airspeed.length() < VERTICAL_RISE_SPEED else minf(PI / 2.0 - kick, air_path)
			else:
				desired = _upper_stage_pitch(pitch, radius, vertical_speed, horizontal_speed, thrust / mass, mass, flow, float(s.ispVacuumS), target)
			pitch = move_toward(pitch, desired, MAX_PITCH_RATE * step)
			acceleration += (downrange * cos(pitch) + up * sin(pitch)) * thrust / mass
			propellant -= flow * step
			if phase == "circularize" and velocity.length() >= sqrt(MU / radius):
				phase = "final"
				events.circularization_cutoff = t
			elif phase == "burn" and stage == stages.size() - 1 and apogee_radius(position, velocity) >= target_apogee:
				events.cutoff = t
				phase = "transfer" if circularize else "final"
			elif propellant <= 0.0:
				if stage < stages.size() - 1:
					phase = "staging"
					events.meco = t
				else:
					depleted = true
					events[("circularization_cutoff" if phase == "circularize" else "cutoff")] = t
					phase = "final"
		else:
			pitch = move_toward(pitch, flight_path, MAX_PITCH_RATE * step)
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
		velocity += acceleration * step
		position += velocity * step
		t += step
	events.end = t
	samples.append({"t": t, "position": position, "velocity": velocity, "pitch": pitch, "stage": stage, "thrusting": false})
	return {"samples": samples, "events": events, "final": samples.back(), "depleted": depleted}

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

static func _mass(stages: Array, stage: int, propellant: float, fairing_on: bool, payload_kg: float) -> float:
	var mass := payload_kg + maxf(0.0, propellant)
	for i in range(stage, stages.size()):
		mass += float(stages[i].dryMassKg)
		if i > stage:
			mass += float(stages[i].propellantKg)
	return mass

## Linear interpolation of the samples at time t; flags come from the earlier sample.
static func sample_at(samples: Array, t: float) -> Dictionary:
	if t <= samples[0].t:
		return samples[0]
	var low := 0
	var high := samples.size() - 1
	if t >= samples[high].t:
		return samples[high]
	while high - low > 1:
		var middle := (low + high) / 2
		if samples[middle].t <= t: low = middle
		else: high = middle
	var a: Dictionary = samples[low]
	var b: Dictionary = samples[high]
	var w: float = (t - a.t) / (b.t - a.t)
	var position: Vector2 = a.position.slerp(b.position, w) if a.position.length() > 0.0 else a.position.lerp(b.position, w)
	return {"t": t, "position": position, "velocity": a.velocity.lerp(b.velocity, w), "pitch": lerpf(a.pitch, b.pitch, w), "stage": a.stage, "thrusting": a.thrusting}
