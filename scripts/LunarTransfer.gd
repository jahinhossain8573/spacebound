extends RefCounted

const DAY := 86400.0
const PARKING_ALTITUDE_KM := 250.0
const MOON_DISTANCE_KM := 384400.0
const MOON_RADIUS_KM := 1737.4
const EARTH_RADIUS_KM := 6371.0
const PARKING_S := 90.0
const NAVIGATION_S := 0.9 * DAY
const CLOSEST_S := 3.0 * DAY
const FLYBY_HALF_S := 0.035 * DAY
const RETURN_S := 5.75 * DAY
const END_S := 6.0 * DAY
const ENTRY_S := END_S - 600.0
const CHUTE_S := END_S - 120.0
const ENTRY_ALTITUDE_KM := 120.0
const CHUTE_ALTITUDE_KM := 6.0
# In the map's XZ plane, +145° is 145° west on the equatorial Pacific.
const SPLASH_ANGLE := deg_to_rad(145.0)
const ENTRY_ANGLE := SPLASH_ANGLE - deg_to_rad(18.0)
const CHUTE_ANGLE := SPLASH_ANGLE - deg_to_rad(0.015)
const EARTH_APPROACH := Vector3(0.0, 0.0, 18000.0)
const IMAGE_COUNT := 20
const NOMINAL_MISS_KM := 4200.0
const IMAGE_START_S := CLOSEST_S - 150.0
const IMAGE_END_S := CLOSEST_S + 150.0
const SHADOW_START_S := CLOSEST_S - 600.0
const SHADOW_END_S := CLOSEST_S + 600.0
const PATH_TIMES := [0.0, NAVIGATION_S, CLOSEST_S - FLYBY_HALF_S, CLOSEST_S, CLOSEST_S + FLYBY_HALF_S, RETURN_S, ENTRY_S, CHUTE_S, END_S]
const PATH_SEGMENTS := 120

var elapsed := 0.0
var parking_elapsed := 0.0
var correction_mps := 0.0
var closest_km := NOMINAL_MISS_KM
var cruise_started := false
var navigation_open := false
var closest_passed := false
var approaching := false
var splashed_down := false
var finished := false
var failure := ""
var images := 0
var fuel_kg: float
var battery_wh: float
var lowest_battery_wh: float
var _stats: Dictionary
var _camera_installed := false
var _link_installed := false
var _parking_orbit: OrbitState
var _departure: Vector3
var curve := Curve3D.new()

func _init(build: Dictionary, stats: Dictionary, orbit: OrbitState) -> void:
	_stats = stats
	_parking_orbit = orbit.copy()
	_departure = parking_position_km(PARKING_S)
	fuel_kg = float(build.propellant_mass_kg)
	battery_wh = float(stats.battery_wh)
	lowest_battery_wh = battery_wh
	for part: Dictionary in build.installed_components:
		_camera_installed = _camera_installed or part.id == "inst_lroc_wac"
		_link_installed = _link_installed or part.id == "com_gd_sdst"
	_rebuild_curve()

func parking_position_km(seconds: float) -> Vector3:
	var orbit := _parking_orbit
	var position := FlightSim.position_on_orbit_km(orbit.semi_major_axis_km, orbit.eccentricity, orbit.time_since_periapsis_s + seconds, orbit.mu)
	position.y *= orbit.direction
	position = position.rotated(orbit.arg_periapsis_rad)
	return Vector3(position.x, 0.0, position.y)

func predict_correction(amount_mps: float, retrograde: bool) -> float:
	return NOMINAL_MISS_KM - 80.0 * (correction_mps + amount_mps * (-1.0 if retrograde else 1.0))

func available_dv() -> float:
	return FlightSim.calculate_delta_v(_stats.dry_mass_kg, _stats.dry_mass_kg + fuel_kg, _stats.engine.get("ispSeconds", 0.0))

func apply_correction(amount_mps: float, retrograde: bool) -> bool:
	if not navigation_open or not is_finite(amount_mps) or amount_mps <= 0.0 or amount_mps > available_dv() + 0.000001:
		return false
	var isp := float(_stats.engine.ispSeconds)
	var wet := float(_stats.dry_mass_kg) + fuel_kg
	var remaining_wet := wet * exp(-amount_mps / (FlightSim.G0 * isp))
	fuel_kg = maxf(0.0, remaining_wet - float(_stats.dry_mass_kg))
	closest_km = predict_correction(amount_mps, retrograde)
	correction_mps += -amount_mps if retrograde else amount_mps
	_rebuild_curve()
	return true

func link_active() -> bool:
	return _link_installed and battery_wh > 0.0

func in_eclipse() -> bool:
	return closest_km <= 1000.0 and elapsed >= SHADOW_START_S and elapsed < SHADOW_END_S

func corridor_met() -> bool:
	return closest_passed and closest_km >= 100.0 and closest_km <= 500.0

func advance(seconds: float) -> void:
	if navigation_open or finished or not is_finite(seconds) or seconds <= 0.0:
		return
	if not cruise_started:
		parking_elapsed = minf(parking_elapsed + seconds, PARKING_S)
		cruise_started = parking_elapsed >= PARKING_S
		return
	var end := minf(elapsed + seconds, END_S)
	var approach_half := _approach_half_duration()
	var approach_start := CLOSEST_S - approach_half
	var approach_end := CLOSEST_S + approach_half
	var milestones := [NAVIGATION_S, approach_start, SHADOW_START_S, CLOSEST_S, IMAGE_END_S, SHADOW_END_S, approach_end, RETURN_S, ENTRY_S, CHUTE_S, END_S]
	milestones.sort()
	for milestone: float in milestones:
		if milestone <= elapsed or milestone > end:
			continue
		advance_segment(milestone)
		if finished:
			return
		if milestone == NAVIGATION_S:
			navigation_open = true
			return
		if milestone == approach_start and approach_half > 0.0:
			approaching = true
			return
		if milestone == CLOSEST_S:
			closest_passed = true
			if closest_km < 50.0:
				failure = "The spacecraft impacted the Moon."
				finished = true
				return
		if milestone == approach_end:
			approaching = false
		if milestone == RETURN_S or milestone == ENTRY_S or milestone == CHUTE_S:
			return
	if end > elapsed:
		advance_segment(end)
	if elapsed >= END_S:
		splashed_down = true
		finished = true

func advance_segment(end: float) -> void:
	var power := -float(_stats.draw_w) if in_eclipse() else float(_stats.net_power_w)
	var charge := battery_wh + power * (end - elapsed) / 3600.0
	if charge <= 0.0:
		if power < 0.0:
			elapsed = minf(end, elapsed + battery_wh * 3600.0 / -power)
		battery_wh = 0.0
		lowest_battery_wh = 0.0
		failure = "Battery depleted. Deep-space link lost."
		finished = true
		return
	battery_wh = minf(float(_stats.battery_wh), charge)
	lowest_battery_wh = minf(battery_wh, lowest_battery_wh)
	elapsed = end
	if _camera_installed and closest_km <= 1000.0 and elapsed >= IMAGE_START_S:
		images = mini(IMAGE_COUNT, floori(remap(elapsed, IMAGE_START_S, IMAGE_END_S, 0.0, IMAGE_COUNT)))

func position_km() -> Vector3:
	return _path_at(elapsed) if cruise_started else parking_position_km(parking_elapsed)

func moon_altitude_km() -> float:
	return position_km().distance_to(Vector3(MOON_DISTANCE_KM, 0.0, 0.0)) - MOON_RADIUS_KM

func _approach_half_duration() -> float:
	var altitude := maxf(0.0, closest_km)
	return FLYBY_HALF_S * sqrt(maxf(0.0, (10000.0 - altitude) / (_flyby_edge() - MOON_RADIUS_KM - altitude)))

func _flyby_edge() -> float:
	return maxf(16000.0, MOON_RADIUS_KM + closest_km + 6000.0)

func _rebuild_curve() -> void:
	curve.clear_points()
	for segment in PATH_TIMES.size() - 1:
		for i in PATH_SEGMENTS:
			var time := lerpf(PATH_TIMES[segment], PATH_TIMES[segment + 1], float(i) / PATH_SEGMENTS)
			curve.add_point(_path_at(time))
	curve.add_point(_path_at(END_S))

func _path_at(time: float) -> Vector3:
	var mid := Vector3(158000.0, 0.0, -47000.0)
	var edge := _flyby_edge()
	var inbound := Vector3(MOON_DISTANCE_KM, 0.0, -edge)
	var outbound := Vector3(MOON_DISTANCE_KM, 0.0, edge)
	if time <= NAVIGATION_S:
		var progress := time / NAVIGATION_S
		var angle := lerp_angle(atan2(_departure.z, _departure.x), atan2(mid.z, mid.x), smoothstep(0.0, 1.0, progress))
		var radius := lerpf(_departure.length(), mid.length(), progress * progress * (2.0 - progress))
		return _earth_position(angle, radius - EARTH_RADIUS_KM)
	if time < (CLOSEST_S - FLYBY_HALF_S):
		return mid.bezier_interpolate(mid + Vector3(84000.0, 0.0, 0.0), inbound - Vector3(38000.0, 0.0, 0.0), inbound, inverse_lerp(NAVIGATION_S, (CLOSEST_S - FLYBY_HALF_S), time))
	if time <= (CLOSEST_S + FLYBY_HALF_S):
		var phase := (time - CLOSEST_S) / FLYBY_HALF_S
		var angle := phase * PI * 0.5
		var periapsis := MOON_RADIUS_KM + maxf(0.0, closest_km)
		var radius := lerpf(periapsis, edge, phase * phase)
		return Vector3(MOON_DISTANCE_KM + cos(angle) * radius, 0.0, sin(angle) * radius)
	if time <= RETURN_S:
		return outbound.bezier_interpolate(outbound - Vector3(70000.0, 0.0, 0.0), Vector3(40000.0, 0.0, 42000.0), EARTH_APPROACH, inverse_lerp(CLOSEST_S + FLYBY_HALF_S, RETURN_S, time))
	if time <= ENTRY_S:
		var progress := inverse_lerp(RETURN_S, ENTRY_S, time)
		return _earth_position(lerpf(PI * 0.5, ENTRY_ANGLE, progress), lerpf(EARTH_APPROACH.z - EARTH_RADIUS_KM, ENTRY_ALTITUDE_KM, progress))
	if time <= CHUTE_S:
		var progress := inverse_lerp(ENTRY_S, CHUTE_S, time)
		var braking := progress * (2.0 - progress)
		var descent := progress * (1.6 - 0.6 * progress)
		return _earth_position(lerpf(ENTRY_ANGLE, CHUTE_ANGLE, braking), lerpf(ENTRY_ALTITUDE_KM, CHUTE_ALTITUDE_KM, descent))
	var remaining := 1.0 - inverse_lerp(CHUTE_S, END_S, time)
	var descent := remaining * (0.1 + 0.9 * remaining)
	return _earth_position(lerpf(SPLASH_ANGLE, CHUTE_ANGLE, descent), CHUTE_ALTITUDE_KM * descent)

func _earth_position(angle: float, altitude_km: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle)) * (EARTH_RADIUS_KM + altitude_km)
