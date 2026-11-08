extends SceneTree

var failures := 0
var helper
var data
var sim

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1

func has_status(checks: Array, name: String, status: String) -> bool:
	for row in checks:
		if row.check == name and row.status == status: return true
	return false

func run_tests() -> void:
	data = root.get_node("GlobalData")
	sim = root.get_node("FlightSim")
	helper = load("res://scripts/BuildStats.gd").new()
	var mission: Dictionary = data.get_mission(1)
	var build := {"launcher":data.get_launcher(mission.requiredLauncher), "bus":data.get_bus(mission.requiredBus), "installed_components":[data.get_part("com_endurosat_uhf"),data.get_part("pwr_gomspace_p31u")], "propellant_mass_kg":0.0}
	var checks: Array = helper.run_readiness_review(build, mission)
	check(has_status(checks, "Eclipse endurance", "FAIL") and has_status(checks, "Flight computer", "FAIL"), "mission 1 incomplete")
	build.installed_components.append(data.get_part("av_gomspace_a3200"))
	build.installed_components.append(data.get_part("pwr_gomspace_bp4"))
	checks = helper.run_readiness_review(build, mission)
	var fail := false
	for row in checks: fail = fail or row.status == "FAIL"
	check(not fail, "mission 1 reference passes")
	var s: Dictionary = helper.calculate_stats(build, mission)
	check(is_equal_approx(s.dry_mass_kg, 2.37) and is_equal_approx(s.adapter_mass_kg, 2.37 * 0.02), "dry mass and adapter")
	check(is_equal_approx(s.internal_volume_liters, 0.4), "external volume ignored")
	build.installed_components.append(data.get_part("pwr_gomspace_bp4"))
	check(is_equal_approx(helper.calculate_stats(build, mission).battery_wh, 140.0), "duplicate battery counted")
	var workshop = load("res://scenes/Workshop.tscn").instantiate()
	root.add_child(workshop)
	check(workshop._launch.disabled, "launch initially blocked")
	for id in ["com_endurosat_uhf", "pwr_gomspace_p31u", "av_gomspace_a3200", "pwr_gomspace_bp4"]: workshop.add_part(id)
	check(not workshop._launch.disabled and workshop.stats.battery_wh == 70, "telemetry and launch update")
	workshop._show_review()
	check(workshop.has_node("ReadinessReport/Scroll/Checks"), "review modal created")
	workshop._launch_build()
	var manager := root.get_node("GameManager")
	check(manager.current_build.installed_components.size() == 4, "launch stores build")
	workshop.remove_part(0)
	check(workshop._launch.disabled and manager.current_build.installed_components.size() == 4, "edit invalidates and snapshot stays independent")
	workshop.queue_free()
	await process_frame
	var m4: Dictionary = data.get_mission(4)
	var geo := {"launcher":data.get_launcher(m4.requiredLauncher), "bus":data.get_bus(m4.requiredBus), "installed_components":[data.get_part("av_gomspace_a3200")], "propellant_mass_kg":0.0}
	check(helper.calculate_stats(geo,m4).launcher_capacity_kg == 5500, "GEO uses GTO capacity")
	check(has_status(helper.run_readiness_review(geo,m4), "Radiation", "FAIL"), "radiation fails")
	var boundary_build: Dictionary = empty_build_for_boundary(data, mission)
	var boundary_checks: Array = helper.run_readiness_review(boundary_build, mission)
	check(has_status(boundary_checks, "Mass budget", "ADVISORY"), "10 percent mass margin is advisory")
	boundary_build.bus.dryMassKg = 90.1 / 1.02
	check(has_status(helper.run_readiness_review(boundary_build, mission), "Mass budget", "FAIL"), "under 10 percent mass margin fails")
	var empty := {"launcher":build.launcher, "bus":build.bus, "installed_components":[], "propellant_mass_kg":0.0}
	check(is_inf(helper.calculate_stats(empty,mission).endurance_minutes), "zero load endurance")
	check(has_status(helper.run_readiness_review(empty,mission), "Eclipse endurance", "FAIL"), "battery required at zero load")
	var fuel_build := {"launcher":data.get_launcher(m4.requiredLauncher), "bus":data.get_bus(m4.requiredBus), "installed_components":[data.get_part("prop_aerojet_r4d15")], "propellant_mass_kg":120.0}
	s = helper.calculate_stats(fuel_build,m4)
	check(is_equal_approx(s.internal_volume_liters, 110.0) and is_equal_approx(s.dry_mass_kg, 374.6), "fuel density, ullage and tank mass")
	var m7: Dictionary = data.get_mission(7)
	fuel_build.launcher = data.get_launcher(m7.requiredLauncher)
	fuel_build.bus = data.get_bus(m7.requiredBus)
	fuel_build.installed_components = [data.get_part("prop_lpsc_throttleable")]
	fuel_build.propellant_mass_kg = 800.0
	s = helper.calculate_stats(fuel_build,m7)
	var expected: float = (s.dry_mass_kg + 800.0) * exp(-2600.0 / (312.0 * sim.G0))
	check(absf(s.landing_mass_kg - expected) < 0.001 and absf(s.landing_twr - 2400.0 / (expected * sim.G_MOON)) < 0.001, "lunar burn landing mass and TWR")
	fuel_build.propellant_mass_kg = 1.0
	check(has_status(helper.run_readiness_review(fuel_build,m7), "Lunar landing", "FAIL"), "insufficient lunar burn fuel fails")
	print("Readiness failures: ", failures)
	quit(1 if failures else 0)

func empty_build_for_boundary(source: Node, mission: Dictionary) -> Dictionary:
	var small_bus: Dictionary = source.get_bus(mission.requiredBus).duplicate(true)
	small_bus.dryMassKg = 90.0 / 1.02
	var vehicle: Dictionary = source.get_launcher(mission.requiredLauncher).duplicate(true)
	vehicle.capacityLeoKg = 100.0
	return {"launcher": vehicle, "bus": small_bus, "installed_components": [], "propellant_mass_kg": 0.0}
