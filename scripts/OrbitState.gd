class_name OrbitState
extends RefCounted

const PHYSICS = preload("res://scripts/autoload/FlightSim.gd")
var semi_major_axis_km: float = 6771.0
var eccentricity: float = 0.0
var arg_periapsis_rad: float = 0.0
var time_since_periapsis_s: float = 0.0
var direction := 1.0
var mu: float = PHYSICS.MU_EARTH_KM3_S2

func is_valid() -> bool:
	return is_finite(semi_major_axis_km) and semi_major_axis_km > 0.0 and is_finite(eccentricity) and eccentricity >= 0.0 and eccentricity < 1.0 and is_finite(arg_periapsis_rad) and is_finite(time_since_periapsis_s) and is_finite(mu) and mu > 0.0 and absf(direction) == 1.0

func copy() -> OrbitState:
	var result := OrbitState.new()
	result.semi_major_axis_km = semi_major_axis_km
	result.eccentricity = eccentricity
	result.arg_periapsis_rad = arg_periapsis_rad
	result.time_since_periapsis_s = time_since_periapsis_s
	result.mu = mu
	result.direction = direction
	return result
