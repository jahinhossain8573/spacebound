extends SceneTree

const ASCENT = preload("res://scripts/AscentSim.gd")
const LIVE_ASCENT = preload("res://scripts/LiveAscent.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func altitude_at(result: Dictionary, t: float) -> float:
	return (ASCENT.sample_at(result.samples, t).position.length() - ASCENT.R_EARTH) / 1000.0

## Perigee and apogee radii in km of the orbit through a position and velocity.
func apsides_km(position: Vector2, velocity: Vector2) -> Vector2:
	var radius := position.length()
	var semi_major := -ASCENT.MU / (2.0 * (velocity.length_squared() / 2.0 - ASCENT.MU / radius))
	var momentum := position.x * velocity.y - position.y * velocity.x
	var eccentricity := sqrt(maxf(0.0, 1.0 - momentum * momentum / (ASCENT.MU * semi_major)))
	return Vector2(semi_major * (1.0 - eccentricity), semi_major * (1.0 + eccentricity)) / 1000.0

func run_tests() -> void:
	var data := root.get_node("GlobalData")
	for number in [1, 2, 3, 4]:
		var mission: Dictionary = data.get_mission(number)
		var launcher: Dictionary = data.get_launcher(mission.requiredLauncher)
		var transfer: bool = mission.targetOrbit in ["GEO", "GTO"]
		var capacity: float = load("res://scripts/BuildStats.gd").new().calculate_stats({"launcher": launcher, "bus": data.get_bus(mission.requiredBus), "installed_components": [], "propellant_mass_kg": 0.0}, mission).launcher_capacity_kg
		var target := ASCENT.target_for(mission, launcher.ascent)
		var expected := Vector2(ASCENT.GTO_PERIGEE_M, ASCENT.GTO_APOGEE_M) / 1000.0 if transfer else Vector2.ONE * (ASCENT.R_EARTH / 1000.0 + float(mission.targetAltitudeKm))
		var order := ["liftoff", "max_q", "meco", "stage_separation", "upper_ignition", "fairing", "cutoff"]
		if not transfer:
			order += ["circularization", "circularization_cutoff"]
		order += ["payload_separation", "end"]
		for payload in [capacity * 0.05, capacity * 0.9]:
			var label := "Mission %d on %s with %.0f kg" % [number, launcher.id, payload]
			var result := ASCENT.simulate(launcher.ascent, payload, target)
			var final: Dictionary = result.final
			var apsides := apsides_km(final.position, final.velocity)
			var events: Dictionary = result.events
			print("  %s: cutoff T+%.0f s, end T+%.0f s, MECO %.0f km, max-Q %.1f km, fairing %.0f km, orbit %.0f x %.0f km altitude" % [label, events.get("cutoff", -1.0), events.end, altitude_at(result, events.get("meco", 0.0)), altitude_at(result, events.get("max_q", 0.0)), altitude_at(result, events.get("fairing", 0.0)), apsides.x - 6371.0, apsides.y - 6371.0])
			check(not result.depleted, "%s finishes with propellant left" % label)
			var tolerance := Vector2(10.0, 400.0) if transfer else Vector2(10.0, 10.0)
			check(absf(apsides.x - expected.x) < tolerance.x and absf(apsides.y - expected.y) < tolerance.y, "%s reaches the target orbit" % label)
			var ordered := true
			for i in order.size() - 1:
				ordered = ordered and events.has(order[i]) and events.has(order[i + 1]) and events[order[i]] <= events[order[i + 1]]
			check(ordered, "%s events in flight order" % label)
			check(altitude_at(result, events.max_q) > 5.0 and altitude_at(result, events.max_q) < 20.0, "%s max-Q in the lower atmosphere" % label)
			check(altitude_at(result, events.meco) > 40.0 and altitude_at(result, events.meco) < 130.0, "%s MECO at a realistic altitude" % label)
	check_autopilot_recovery(data)
	print("Ascent failures: ", failures)
	quit(1 if failures else 0)

func check_autopilot_recovery(data: Node) -> void:
	for mission_number in [1, 4]:
		var mission: Dictionary = data.get_mission(mission_number)
		var launcher: Dictionary = data.get_launcher(mission.requiredLauncher)
		var payload := 50.0 if mission_number == 1 else 500.0
		var flight := LIVE_ASCENT.new(launcher.ascent, payload, mission)
		while flight.elapsed < 29.0:
			flight.advance(ASCENT.STEP, -1.0, 0.0)
		flight.scripted = true
		while flight.elapsed < 4000.0 and not flight.deployed and flight.failure.is_empty():
			flight.advance(flight.step_size(), 0.0, 0.0)
		check(flight.deployed and flight.target_reached(), "%s autopilot recovers an early pitch-over and reaches the target orbit" % launcher.name)

	var mission: Dictionary = data.get_mission(1)
	var launcher: Dictionary = data.get_launcher(mission.requiredLauncher)
	var flight := LIVE_ASCENT.new(launcher.ascent, 50.0, mission)
	# Recreate a low, nearly level Electron at the reported point in flight.
	flight.clamped = false
	flight.elapsed = 74.0
	flight.py += 5282.0
	flight.vx += 744.0
	flight.pitch = deg_to_rad(-6.0)
	flight.fuel -= (flight.elapsed - ASCENT.CLAMP_HOLD_TIME) * ASCENT.propellant_flow(flight.stages[0])
	flight._update_conditions()
	flight.scripted = true
	var initial_fuel := flight.fuel
	while flight.elapsed < 120.0 and flight.failure.is_empty():
		flight.advance(ASCENT.STEP, 0.0, 0.0)
	check(flight.failure.is_empty() and flight.radial_speed > 150.0 and flight.altitude > 5282.0
		and flight.fuel < initial_fuel, "autopilot pulls out of the low dive using the remaining booster fuel")
