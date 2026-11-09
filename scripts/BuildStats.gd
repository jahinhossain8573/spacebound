extends RefCounted

func calculate_stats(build: Dictionary, mission: Dictionary) -> Dictionary:
	var bus: Dictionary = build.get("bus", {})
	var launcher: Dictionary = build.get("launcher", {})
	var parts: Array = build.get("installed_components", [])
	var fuel: float = maxf(0.0, float(build.get("propellant_mass_kg", 0.0)))
	var dry: float = float(bus.get("dryMassKg", 0.0)) + fuel * FlightSim.TANK_MASS_RATIO
	var volume := 0.0
	var generation := 0.0
	var draw := 0.0
	var battery := 0.0
	var cost: float = float(bus.get("costMillions", 0.0)) + float(launcher.get("costMillions", 0.0)) + fuel * FlightSim.PROPELLANT_COST_PER_KG_M
	var engine: Dictionary = {}
	for part: Dictionary in parts:
		dry += float(part.get("massKg", 0.0))
		cost += float(part.get("costMillions", 0.0))
		if not part.get("isExternal", false): volume += float(part.get("volumeLiters", 0.0))
		generation += float(part.get("powerGenWatts", 0.0))
		draw += float(part.get("powerDrawWatts", 0.0))
		battery += float(part.get("batteryWh", 0.0))
		if part.get("thrustNewtons", 0.0) > 0.0: engine = part
	var density: float = FlightSim.PROPELLANT_DENSITY_KG_L.get(engine.get("propellantType", ""), 0.0)
	var fuel_valid := fuel <= 0.0 or density > 0.0
	if fuel > 0.0 and density > 0.0: volume += fuel / density * (1.0 + FlightSim.ULLAGE_MARGIN)
	var adapter_ratio: float = 0.01 if "L10" in GameManager.owned_tech_nodes else FlightSim.ADAPTER_MASS_RATIO
	var adapter: float = dry * adapter_ratio
	var wet := dry + fuel + adapter
	var target: String = mission.get("targetOrbit", "")
	var capacity := 0.0
	match target:
		"LEO": capacity = launcher.get("capacityLeoKg", 0.0)
		"SSO": capacity = launcher.get("capacityLeoKg", 0.0) * 0.7
		"GEO", "GTO": capacity = launcher.get("capacityGtoKg", 0.0)
		_: capacity = launcher.get("capacityTliKg", 0.0)
	var eclipse_minutes := 0.0
	if target in ["LEO", "SSO", "Lunar Flyby"]:
		var radius: float = FlightSim.R_EARTH_KM + (250.0 if target == "Lunar Flyby" else float(mission.get("targetAltitudeKm", 0.0)))
		eclipse_minutes = FlightSim.orbital_period_s(radius) * FlightSim.eclipse_fraction(radius) / 60.0
	elif target in ["GEO", "GTO"]: eclipse_minutes = 72.0
	var isp: float = float(engine.get("ispSeconds", 0.0))
	var delta_v: float = FlightSim.calculate_delta_v(dry, dry + fuel, isp)
	var required_burn: float = FlightSim.calculate_required_propellant(dry, 2600.0, isp) if isp > 0.0 else INF
	var landing_mass: float = (dry + fuel) * exp(-2600.0 / (isp * FlightSim.G0)) if isp > 0.0 and fuel >= required_burn else dry
	var twr: float = float(engine.get("thrustNewtons", 0.0)) / (landing_mass * FlightSim.G_MOON) if landing_mass > 0 else 0.0
	return {"dry_mass_kg":dry, "wet_mass_kg":wet, "adapter_mass_kg":adapter, "launcher_capacity_kg":capacity, "mass_margin_pct":FlightSim.check_mass_margin(wet, capacity), "internal_volume_liters":volume, "volume_capacity_liters":float(bus.get("internalVolumeLiters", 0.0)), "generation_w":generation, "draw_w":draw, "net_power_w":generation-draw, "battery_wh":battery, "eclipse_minutes":eclipse_minutes, "endurance_minutes":battery / draw * 60.0 if draw > 0 else INF, "delta_v_mps":delta_v, "delta_v_target_mps":float(mission.get("requiredDeltaVMps", 0.0)) * 1.1, "cost_millions":cost, "budget_millions":float(mission.get("budgetCapMillions", 0.0)), "fuel_valid":fuel_valid, "landing_mass_kg":landing_mass, "landing_twr":twr, "landing_burn_possible":isp > 0.0 and fuel >= required_burn, "engine":engine}

func run_readiness_review(build: Dictionary, mission: Dictionary) -> Array[Dictionary]:
	var s := calculate_stats(build, mission)
	var parts: Array = build.get("installed_components", [])
	var checks: Array[Dictionary] = []
	var ids: Array = []
	var computer := false
	var hardened := false
	for part: Dictionary in parts:
		ids.append(part.get("id", ""))
		if part.get("subsystem", "") == "avionics":
			computer = true
			hardened = hardened or part.get("radiationHardened", false)
	_add(checks, "Mass budget", "FAIL" if s.launcher_capacity_kg <= 0 or s.mass_margin_pct < 10 else ("ADVISORY" if s.mass_margin_pct < 20 else "PASS"), "Mass %.2f kg / %.2f kg; margin %.1f%%. Keep at least 10%% margin." % [s.wet_mass_kg, s.launcher_capacity_kg, s.mass_margin_pct])
	_add(checks, "Volume", "PASS" if s.fuel_valid and s.internal_volume_liters <= s.volume_capacity_liters else "FAIL", "Internal volume %.2f / %.2f L. Remove parts or fuel if over capacity." % [s.internal_volume_liters, s.volume_capacity_liters])
	_add(checks, "Daylight power", "PASS" if s.generation_w >= s.draw_w else "FAIL", "Generation %.1f W, draw %.1f W. Add solar arrays if power is negative." % [s.generation_w, s.draw_w])
	var battery_required: bool = "battery" in mission.get("requiredCapabilities", [])
	var battery_fail: bool = (battery_required and s.battery_wh <= 0) or (s.draw_w > 0 and s.eclipse_minutes > 0 and s.endurance_minutes <= s.eclipse_minutes)
	var battery_advisory: bool = not battery_fail and s.draw_w > 0 and s.eclipse_minutes > 0 and s.endurance_minutes < 1.5 * s.eclipse_minutes
	_add(checks, "Eclipse endurance", "FAIL" if battery_fail else ("ADVISORY" if battery_advisory else "PASS"), "Battery %.1f Wh; eclipse %.1f min. Add a battery such as GomSpace BP4 if needed." % [s.battery_wh, s.eclipse_minutes])
	_add(checks, "Flight computer", "PASS" if computer else "FAIL", "On-board computer installed." if computer else "No on-board computer installed. Add avionics.")
	if mission.get("targetOrbit", "") in ["GEO", "GTO", "Lunar Flyby", "Lunar Surface"] or "radiationHardened" in mission.get("requiredCapabilities", []):
		_add(checks, "Radiation", "PASS" if hardened else "FAIL", "Radiation-hardened avionics installed." if hardened else "Install radiation-hardened avionics such as the BAE RAD750 (research A5).")
	var dv_fail: bool = s.delta_v_target_mps > 0.0 and (s.engine.is_empty() or s.delta_v_mps < s.delta_v_target_mps)
	var dv_advisory: bool = not dv_fail and mission.get("requiredDeltaVMps", 0.0) > 0 and s.delta_v_mps > float(mission.requiredDeltaVMps) * 1.5
	_add(checks, "Delta-v", "FAIL" if dv_fail else ("ADVISORY" if dv_advisory else "PASS"), "Delta-v %.1f / %.1f m/s including margin. Add an engine or fuel if needed." % [s.delta_v_mps, s.delta_v_target_mps])
	for id in mission.get("requiredPartIds", []):
		var part: Dictionary = GlobalData.get_part(id)
		var part_name: String = str(part.get("name", id))
		var message := "Required part installed: " + part_name
		if id not in ids:
			message = "Missing required part: " + part_name
			if not GameManager.is_part_unlocked(id):
				for node in GlobalData.tech_nodes:
					if id in node.unlocksParts and node.hackathonEnabled:
						message += " (research %s in the tech tree)" % node.id
						break
		_add(checks, "Required part", "PASS" if id in ids else "FAIL", message)
	_add(checks, "Budget", "PASS" if s.cost_millions <= s.budget_millions else "FAIL", "Cost $%.2fM / $%.2fM. Remove parts or fuel if over budget." % [s.cost_millions, s.budget_millions])
	if int(mission.get("missionNumber", 0)) == 7:
		_add(checks, "Lunar landing", "PASS" if s.landing_burn_possible and s.landing_twr >= 1.3 else "FAIL", "Landing TWR %.2f; requires 1.30 and fuel for the 2,600 m/s approach." % s.landing_twr)
	return checks

func _add(checks: Array[Dictionary], name: String, status: String, message: String) -> void:
	checks.append({"check": name, "status": status, "message": message})

## Fuel headroom after allowing for tanks, adapter, ullage and the launch margin.
func propellant_limits(build: Dictionary, mission: Dictionary) -> Dictionary:
	var empty := build.duplicate()
	empty["propellant_mass_kg"] = 0.0
	var s := calculate_stats(empty, mission)
	var density: float = FlightSim.PROPELLANT_DENSITY_KG_L.get(s.engine.get("propellantType", ""), 0.0)
	var mass_limit: float = maxf(0.0, (s.launcher_capacity_kg * 0.9 - s.wet_mass_kg) / (1.0 + FlightSim.TANK_MASS_RATIO * (1.0 + (0.01 if "L10" in GameManager.owned_tech_nodes else FlightSim.ADAPTER_MASS_RATIO))))
	var volume_limit: float = maxf(0.0, s.volume_capacity_liters - s.internal_volume_liters) * density / (1.0 + FlightSim.ULLAGE_MARGIN)
	var budget_limit: float = maxf(0.0, s.budget_millions - s.cost_millions) / FlightSim.PROPELLANT_COST_PER_KG_M
	var maximum := minf(mass_limit, minf(volume_limit, budget_limit)) if not s.engine.is_empty() else 0.0
	var reason := "space inside the bus" if volume_limit <= mass_limit and volume_limit <= budget_limit else ("launcher mass margin" if mass_limit <= budget_limit else "mission budget")
	return {"maximum_kg":maximum, "limiting_factor":reason, "mass_kg":mass_limit, "volume_kg":volume_limit, "budget_kg":budget_limit}
