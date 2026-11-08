extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + label)


func near(actual: float, expected: float, label: String, tolerance: float = 0.01) -> void:
	check(absf(actual - expected) <= maxf(absf(expected) * tolerance, 1e-6), label)


func run_tests() -> void:
	var sim := root.get_node("FlightSim")
	var leo_period: float = sim.orbital_period_s(6771.0)
	near(leo_period, 5545.0, "400 km LEO period")
	near(sim.eclipse_fraction(6771.0), 0.39, "LEO eclipse fraction")
	near(sim.eclipse_fraction(42164.0), 0.048, "GEO eclipse fraction")
	near(sim.circular_speed_kms(42164.0), 3.075, "GEO circular speed")
	var gto_speed: float = sim.speed_at_radius_kms(42164.0, 24392.5)
	near(gto_speed, 1.602, "GTO apoapsis speed")
	var circularization_dv: float = sim.circular_speed_kms(42164.0) - gto_speed
	near(circularization_dv, 1.47, "GTO circularization delta-v")
	var circularized: Dictionary = sim.tangential_burn(42164.0, gto_speed, circularization_dv)
	check(not circularized.escaped and circularized.eccentricity < 0.001, "circularization orbit")
	near(circularized.periapsis_km, 42164.0, "circularization periapsis")
	near(sim.calculate_delta_v(1000.0, 2000.0, 315.0), 2141.0, "rocket equation")
	var propellant: float = sim.calculate_required_propellant(1000.0, 1500.0, 315.0)
	near(sim.calculate_delta_v(1000.0, 1000.0 + propellant, 315.0), 1500.0, "inverse rocket equation", 1e-9)
	near(sim.burn_duration_s(1000.0 + propellant, 1500.0, 315.0, 490.0), propellant * sim.G0 * 315.0 / 490.0, "burn time versus mass flow", 1e-9)
	near(sim.check_mass_margin(80.0, 100.0), 20.0, "mass margin")
	near(sim.check_mass_margin(110.0, 100.0), -10.0, "overweight margin")
	var eclipse: float = sim.eclipse_fraction(6771.0)
	var healthy: Dictionary = sim.simulate_mission_skip(7.0 * 86400.0, leo_period, eclipse, 7.0, 2.7, 70.0)
	check(healthy.survived and healthy.failed_orbit == -1 and healthy.lowest_wh > 0.0 and healthy.lowest_wh <= 70.0, "Mission 1 survives")
	var empty: Dictionary = sim.simulate_mission_skip(7.0 * 86400.0, leo_period, eclipse, 7.0, 2.7, 1.0)
	check(not empty.survived and empty.lowest_wh == 0.0 and empty.failed_orbit == 1, "1 Wh battery fails first orbit")
	var a := 10000.0
	var period: float = sim.orbital_period_s(a)
	check(sim.position_on_orbit_km(a, 0.0, period / 2.0).distance_to(Vector2(-a, 0.0)) < 0.01, "circular half-period position")
	for e in [0.0, 0.5, 0.99]:
		check(sim.position_on_orbit_km(a, e, 0.0).distance_to(Vector2(a * (1.0 - e), 0.0)) < 0.01, "periapsis e=" + str(e))
		check(sim.position_on_orbit_km(a, e, period / 2.0).distance_to(Vector2(-a * (1.0 + e), 0.0)) < 0.01, "apoapsis e=" + str(e))
		var p: Vector2 = sim.position_on_orbit_km(a, e, period * 0.37)
		var ellipse_equation := pow((p.x + a * e) / a, 2.0) + pow(p.y / (a * sqrt(1.0 - e * e)), 2.0)
		near(ellipse_equation, 1.0, "Kepler position lies on ellipse e=" + str(e), 1e-6)
	check(sim.position_on_orbit_km(a, 0.6, -period * 0.25).distance_to(sim.position_on_orbit_km(a, 0.6, period * 0.75)) < 0.01, "negative time wraps")
	check(sim.position_on_orbit_km(a, 0.6, period * 100.25).distance_to(sim.position_on_orbit_km(a, 0.6, period * 0.25)) < 0.01, "multiple periods wrap")
	var v: float = sim.circular_speed_kms(6771.0)
	var raised: Dictionary = sim.tangential_burn(6771.0, v, 0.1)
	check(raised.periapsis_km >= 6771.0 - 0.001 and raised.apoapsis_km > 6771.0, "prograde raises apoapsis")
	var lowered: Dictionary = sim.tangential_burn(6771.0, v, -0.1)
	check(lowered.periapsis_km < 6771.0 and lowered.apoapsis_km <= 6771.0 + 0.001, "retrograde lowers periapsis")
	check(sim.tangential_burn(6771.0, v, v).escaped, "escape burn")
	near(sim.circular_speed_kms(1837.4, sim.MU_MOON_KM3_S2), sqrt(4902.8 / 1837.4), "Moon gravitational parameter")
	var partial: Dictionary = sim.simulate_mission_skip(1800.0, 3600.0, 0.5, 0.0, 1.0, 0.75)
	check(partial.survived, "partial final orbit does not simulate extra eclipse")
	near(partial.lowest_wh, 0.25, "partial orbit charge")
	var second_orbit: Dictionary = sim.simulate_mission_skip(7200.0, 3600.0, 0.5, 0.0, 1.0, 1.5)
	check(not second_orbit.survived and second_orbit.failed_orbit == 2, "cumulative depletion fails orbit 2")
	check(not sim.simulate_mission_skip(3600.0, 3600.0, 0.5, 0.0, 10.0, 1.0).survived, "depletion during sunlight")
	check(sim.simulate_mission_skip(0.0, 3600.0, 0.5, 0.0, 1.0, 0.0).survived, "zero duration")
	check(not sim.simulate_mission_skip(1.0, 0.0, 0.5, 7.0, 2.7, 70.0).survived, "invalid orbit period")
	check(not sim.simulate_mission_skip(3600.0, 3600.0, 1.0, 7.0, 1.0, 1.0).survived, "exact zero charge fails")
	check(sim.calculate_delta_v(0.0, 100.0, 315.0) == 0.0 and sim.calculate_delta_v(100.0, 100.0, 315.0) == 0.0, "rocket invalid mass guards")
	check(sim.calculate_required_propellant(100.0, 1500.0, 0.0) == 0.0 and sim.calculate_required_propellant(100.0, 0.0, 315.0) == 0.0, "propellant guards")
	check(sim.burn_duration_s(100.0, 100.0, 315.0, 0.0) == 0.0 and sim.check_mass_margin(100.0, 0.0) == 0.0, "burn and capacity guards")
	check(sim.orbital_period_s(0.0) == 0.0 and sim.circular_speed_kms(0.0) == 0.0 and sim.speed_at_radius_kms(0.0, a) == 0.0, "orbital division guards")
	check(sim.position_on_orbit_km(a, 1.0, 0.0) == Vector2.ZERO and sim.tangential_burn(0.0, 1.0, 0.1).is_empty(), "invalid elements")
	print("FlightSim: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
