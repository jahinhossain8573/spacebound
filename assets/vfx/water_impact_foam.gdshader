shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform float age;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float distance = length(p);
	float leading_edge = 0.06 + 0.80 * (1.0 - exp(-age * 1.05));
	float turbulence = sin(angle * 11.0 + age * 4.0) * 0.014 + sin(angle * 29.0 - age * 3.2) * 0.008;
	float lead = 1.0 - smoothstep(0.005, 0.035, abs(distance - leading_edge + turbulence));
	float wake = 1.0 - smoothstep(0.006, 0.033, abs(distance - leading_edge * 0.77 - turbulence));
	float breaks = 0.58 + 0.42 * smoothstep(-0.5, 0.7, sin(angle * 19.0 + distance * 83.0));
	float churn = 0.52 + 0.24 * sin(p.x * 91.0 + sin(p.y * 72.0))
		+ 0.20 * sin(p.y * 116.0 - p.x * 44.0 + age * 2.0);
	float froth = (1.0 - smoothstep(0.0, leading_edge * 0.78, distance)) * churn * exp(-age * 1.6);
	ALBEDO = vec3(0.82, 0.93, 0.96);
	ALPHA = clamp((lead * 0.72 + wake * 0.36) * breaks + froth, 0.0, 1.0) * (1.0 - smoothstep(1.2, 3.0, age));
}
