extends RefCounted

static func optical_installed(parts: Array) -> bool:
	for part: Dictionary in parts:
		if part.get("optical", false): return true
	return false

static func clear_observation_seconds(start: float, end: float, blocked_start: float, blocked_end: float) -> float:
	return maxf(0.0, end - start - maxf(0.0, minf(end, blocked_end) - maxf(start, blocked_start)))

static func reach_orbit(launched: bool) -> bool:
	return launched

static func imaging(parts: Array) -> bool:
	var camera := false
	var pointing := false
	for part: Dictionary in parts:
		camera = camera or part.get("optical", false)
		pointing = pointing or (part.get("subsystem", "") == "adcs" and part.get("activePointing", false))
	return camera and pointing

static func downlink(parts: Array, minimum_rate_kbps: float) -> bool:
	for part: Dictionary in parts:
		if part.get("subsystem", "") == "comms" and float(part.get("dataRateKbps", 0)) >= minimum_rate_kbps: return true
	return false

static func survive(survived: bool) -> bool:
	return survived

static func circularize(orbit: OrbitState, target_radius_km: float) -> bool:
	return orbit != null and orbit.is_valid() and orbit.eccentricity < 0.01 and absf(orbit.semi_major_axis_km - target_radius_km) < target_radius_km * 0.01

static func count_passes(first_s: float, period_s: float, until_s: float, unblocked_s: float) -> int:
	if first_s < 0.0 or period_s <= 0.0 or until_s < first_s: return 0
	var start_index := maxi(0, ceili((unblocked_s - first_s) / period_s - 0.000000001))
	var end_index := floori((until_s - first_s) / period_s + 0.000000001)
	return maxi(0, end_index - start_index + 1)
