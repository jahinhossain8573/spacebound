shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 observer_km;
uniform vec3 sun_direction;
uniform float km_per_unit;
uniform float earth_radius_km;

const float ATMOSPHERE_HEIGHT = 96.0;
const vec2 DENSITY_HEIGHTS = vec2(8.0, 1.6);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Integrate on one side of the closest point, with more samples in the dense air.
vec2 air_column(float impact_squared, float near_offset, float far_offset) {
	float near_radius = sqrt(impact_squared + near_offset * near_offset);
	float near_height = max(0.0, near_radius - earth_radius_km);
	float rise_squared = 64.0 * (2.0 * near_radius + 64.0);
	float span = min(far_offset - near_offset,
		rise_squared / (sqrt(near_offset * near_offset + rise_squared) + near_offset));
	vec2 column = vec2(0.0);
	for (int i = 0; i < 5; i++) {
		float sample_point = (float(i) + 0.5) / 5.0;
		float offset = span * sample_point * sample_point;
		float rise = offset * (2.0 * near_offset + offset);
		float height = near_height + rise / (sqrt(near_radius * near_radius + rise) + near_radius);
		column += exp(-height / DENSITY_HEIGHTS) * (2.0 * sample_point * span / 5.0);
	}
	return column;
}

void fragment() {
	vec2 screen = SCREEN_UV * 2.0 - 1.0;
	vec3 ray = normalize((INV_PROJECTION_MATRIX * vec4(screen, 1.0, 1.0)).xyz);
	float closest = -dot(observer_km, ray);
	vec3 perpendicular = cross(observer_km, ray);
	float impact_squared = dot(perpendicular, perpendicular);
	float shell_radius = earth_radius_km + ATMOSPHERE_HEIGHT;
	float half_chord_squared = shell_radius * shell_radius - impact_squared;
	if (half_chord_squared <= 0.0) {
		discard;
	}
	float half_chord = sqrt(half_chord_squared);
	float entry = max(0.0, closest - half_chord);
	float exit = closest + half_chord;
	if (exit <= entry) {
		discard;
	}

	float scene_distance = exit;
	float depth = texture(scene_depth, SCREEN_UV).r;
	if (depth > 0.0) {
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
			depth = depth * 2.0 - 1.0;
		#endif
		vec4 surface = INV_PROJECTION_MATRIX * vec4(screen, depth, 1.0);
		scene_distance = surface.z / (surface.w * ray.z) * km_per_unit;
	}

	// The distant globe's depth is quantized in Compatibility. Use the sphere hit
	// there, and keep scene depth for foreground objects and local pad geometry.
	float ground_chord_squared = earth_radius_km * earth_radius_km - impact_squared;
	float ground_facing = 0.0;
	if (ground_chord_squared > 0.0) {
		float ground_chord = sqrt(ground_chord_squared);
		float ground_hit = closest - ground_chord;
		if (ground_hit > 2.0 && scene_distance > 1.5) {
			scene_distance = mix(min(scene_distance, ground_hit), ground_hit, smoothstep(2.0, 30.0, ground_hit));
			ground_facing = ground_chord / earth_radius_km;
		}
	}
	exit = min(exit, scene_distance);
	if (exit <= entry) {
		discard;
	}

	float start_offset = entry - closest;
	float end_offset = exit - closest;
	vec2 column = vec2(0.0);
	if (start_offset < 0.0) {
		column += air_column(impact_squared, max(0.0, -end_offset), -start_offset);
	}
	if (end_offset > 0.0) {
		column += air_column(impact_squared, max(0.0, start_offset), end_offset);
	}

	float sunlight = dot(normalize(observer_km + ray * clamp(closest, entry, exit)), sun_direction);
	float day = smoothstep(-0.12, 0.18, sunlight);
	float twilight = smoothstep(-0.19, -0.06, sunlight) * (1.0 - day);
	float forward = dot(ray, sun_direction);
	float haze_fraction = (column.y * 3.0) / max(0.01, column.x + column.y * 3.0);
	vec3 blue = mix(vec3(0.19, 0.42, 0.88), vec3(0.38, 0.65, 0.99), 0.25 + 0.75 * forward * forward);
	vec3 daylight = mix(blue, vec3(0.68, 0.80, 0.91), haze_fraction);
	vec3 sunset = mix(vec3(0.14, 0.31, 0.68), vec3(0.97, 0.50, 0.26), haze_fraction);
	float extinction = 1.0 - exp(-dot(column, vec2(0.023, 0.038)));
	ALBEDO = mix(sunset, daylight, day);
	float ground_visibility = mix(1.0, 0.59, smoothstep(0.02, 0.38, ground_facing));
	ALPHA = pow(extinction, 0.58) * (day + twilight * 0.62) * ground_visibility;
}
