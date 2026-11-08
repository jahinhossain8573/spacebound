extends Node
## Pure calculations: orbital distances in km, times in seconds, rocket delta-v in m/s.

const G0: float = 9.80665
const MU_EARTH_KM3_S2: float = 398600.4418
const R_EARTH_KM: float = 6371.0
const MU_MOON_KM3_S2: float = 4902.8
const R_MOON_KM: float = 1737.4
const MOON_DISTANCE_KM: float = 384400.0
const G_MOON: float = 1.62
const RENDER_SCALE: float = 50.0 / 6371.0
const TANK_MASS_RATIO: float = 0.08
const ADAPTER_MASS_RATIO: float = 0.02
const PROPELLANT_COST_PER_KG_M: float = 0.005
const PROPELLANT_DENSITY_KG_L = {"cold_gas": 1.0, "hydrazine": 1.0, "bipropellant": 1.2}
const ULLAGE_MARGIN: float = 0.10


func calculate_delta_v(dry_mass_kg: float, wet_mass_kg: float, isp_sec: float) -> float:
	if dry_mass_kg <= 0.0 or wet_mass_kg <= dry_mass_kg or isp_sec <= 0.0:
		return 0.0
	return isp_sec * G0 * log(wet_mass_kg / dry_mass_kg)


func calculate_required_propellant(dry_mass_kg: float, target_dv_mps: float, isp_sec: float) -> float:
	if dry_mass_kg <= 0.0 or target_dv_mps <= 0.0 or isp_sec <= 0.0:
		return 0.0
	return dry_mass_kg * (exp(target_dv_mps / (isp_sec * G0)) - 1.0)


func check_mass_margin(wet_mass_kg: float, launcher_limit_kg: float) -> float:
	if launcher_limit_kg <= 0.0:
		return 0.0
	return (launcher_limit_kg - wet_mass_kg) / launcher_limit_kg * 100.0


func burn_duration_s(wet_mass_kg: float, dv_mps: float, isp_sec: float, thrust_n: float) -> float:
	if wet_mass_kg <= 0.0 or dv_mps <= 0.0 or isp_sec <= 0.0 or thrust_n <= 0.0:
		return 0.0
	var exhaust_speed := G0 * isp_sec
	return wet_mass_kg * exhaust_speed / thrust_n * (1.0 - exp(-dv_mps / exhaust_speed))


func orbital_period_s(semi_major_axis_km: float, mu: float = MU_EARTH_KM3_S2) -> float:
	if semi_major_axis_km <= 0.0 or mu <= 0.0:
		return 0.0
	return TAU * sqrt(pow(semi_major_axis_km, 3.0) / mu)


func circular_speed_kms(radius_km: float, mu: float = MU_EARTH_KM3_S2) -> float:
	if radius_km <= 0.0 or mu <= 0.0:
		return 0.0
	return sqrt(mu / radius_km)


func speed_at_radius_kms(radius_km: float, semi_major_axis_km: float, mu: float = MU_EARTH_KM3_S2) -> float:
	if radius_km <= 0.0 or is_zero_approx(semi_major_axis_km) or mu <= 0.0:
		return 0.0
	return sqrt(maxf(0.0, mu * (2.0 / radius_km - 1.0 / semi_major_axis_km)))


func eclipse_fraction(orbit_radius_km: float, body_radius_km: float = R_EARTH_KM) -> float:
	if orbit_radius_km <= 0.0 or body_radius_km <= 0.0:
		return 0.0
	return asin(clampf(body_radius_km / orbit_radius_km, 0.0, 1.0)) / PI


## A tangential impulse assumes zero radial velocity at the burn point.
## Apsides are radii from the body's center, not altitudes above the surface.
## Invalid radius/mu returns {}; escape returns only {escaped: true}.
func tangential_burn(r_km: float, speed_kms: float, dv_kms: float, mu: float = MU_EARTH_KM3_S2) -> Dictionary:
	if r_km <= 0.0 or mu <= 0.0:
		return {}
	var v_new := speed_kms + dv_kms
	var energy := v_new * v_new / 2.0 - mu / r_km
	if energy >= 0.0:
		return {"escaped": true}
	var a := -mu / (2.0 * energy)
	var r_other := maxf(0.0, 2.0 * a - r_km)
	return {
		"escaped": false,
		"semi_major_axis_km": a,
		"eccentricity": absf(r_other - r_km) / (r_other + r_km),
		"periapsis_km": minf(r_km, r_other),
		"apoapsis_km": maxf(r_km, r_other),
	}


## Elliptic orbits only; invalid elements return Vector2.ZERO.
func position_on_orbit_km(semi_major_axis_km: float, eccentricity: float, time_since_periapsis_s: float, mu: float = MU_EARTH_KM3_S2) -> Vector2:
	if semi_major_axis_km <= 0.0 or mu <= 0.0 or eccentricity < 0.0 or eccentricity >= 1.0:
		return Vector2.ZERO
	var period := orbital_period_s(semi_major_axis_km, mu)
	var mean_anomaly := TAU * fposmod(time_since_periapsis_s, period) / period
	var eccentric_anomaly := mean_anomaly if eccentricity < 0.8 else PI
	for _iteration in 32:
		var correction := (eccentric_anomaly - eccentricity * sin(eccentric_anomaly) - mean_anomaly) / (1.0 - eccentricity * cos(eccentric_anomaly))
		eccentric_anomaly -= correction
		if absf(correction) < 1e-12:
			break
	var x := semi_major_axis_km * (cos(eccentric_anomaly) - eccentricity)
	var y := semi_major_axis_km * sqrt(1.0 - eccentricity * eccentricity) * sin(eccentric_anomaly)
	return Vector2(x, y)


## Starts with a full battery at the start of sunlight; failure orbit is one-based.
## The last orbit is truncated to duration_s. Reaching zero charge is failure.
func simulate_mission_skip(duration_s: float, orbit_period_s: float, eclipse_fraction: float, gen_w: float, draw_w: float, battery_wh: float) -> Dictionary:
	var charge_wh := maxf(0.0, battery_wh)
	var lowest_wh := charge_wh
	if duration_s <= 0.0:
		return {"survived": true, "lowest_wh": lowest_wh, "failed_orbit": -1}
	if orbit_period_s <= 0.0 or not is_finite(duration_s) or not is_finite(orbit_period_s):
		return {"survived": false, "lowest_wh": 0.0, "failed_orbit": 1}
	var fraction := clampf(eclipse_fraction, 0.0, 1.0)
	var sunlight_s := orbit_period_s * (1.0 - fraction)
	var generation := maxf(0.0, gen_w)
	var load_w := maxf(0.0, draw_w)
	var remaining_s := duration_s
	var orbit := 0
	while remaining_s > 0.0:
		orbit += 1
		var step_s := minf(remaining_s, orbit_period_s)
		var sun_s := minf(step_s, sunlight_s)
		charge_wh = minf(battery_wh, charge_wh + (generation - load_w) * sun_s / 3600.0)
		lowest_wh = minf(lowest_wh, charge_wh)
		if charge_wh <= 0.0:
			return {"survived": false, "lowest_wh": 0.0, "failed_orbit": orbit}
		charge_wh -= load_w * maxf(0.0, step_s - sun_s) / 3600.0
		lowest_wh = minf(lowest_wh, charge_wh)
		if charge_wh <= 0.0:
			return {"survived": false, "lowest_wh": 0.0, "failed_orbit": orbit}
		remaining_s -= step_s
	return {"survived": true, "lowest_wh": lowest_wh, "failed_orbit": -1}
