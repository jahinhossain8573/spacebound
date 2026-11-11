shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, skip_vertex_transform, shadows_disabled;

uniform sampler2D cloud_texture : filter_linear, repeat_disable;
uniform float age;
uniform float rotation;
uniform float air;
uniform float heat_duration;

void vertex() {
	vec2 scale = vec2(length(MODELVIEW_MATRIX[0].xyz), length(MODELVIEW_MATRIX[1].xyz));
	VERTEX = MODELVIEW_MATRIX[3].xyz + vec3(VERTEX.xy * scale, 0.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, -1.0);
	float radius = length(p);
	mat2 spin = mat2(vec2(cos(rotation), sin(rotation)), vec2(-sin(rotation), cos(rotation)));
	vec2 uv = spin * p + 0.5;
	float density = texture(cloud_texture, uv).a;
	float folds = texture(cloud_texture, fract(uv * 2.4 + vec2(age * 0.23, rotation))).a;
	float edge = (1.0 - smoothstep(0.31, 0.49, radius));
	float body = smoothstep(0.03, 0.47, density * (0.73 + 0.58 * folds)) * edge;
	float lit = texture(cloud_texture, uv + vec2(0.075, -0.065)).a;
	float relief = clamp(0.48 + 1.3 * (density - lit) + folds * 0.23, 0.0, 1.0);
	float heat = 1.0 - smoothstep(heat_duration * 0.30, heat_duration, age);
	vec3 smoke = mix(vec3(0.16, 0.155, 0.16), vec3(0.76, 0.73, 0.69), relief);
	smoke = mix(smoke, vec3(0.94, 0.66, 0.43), heat * 0.42);
	vec3 fire = mix(vec3(0.93, 0.24, 0.045), vec3(1.0, 0.95, 0.66),
		smoothstep(0.34, 0.75, density * 0.62 + folds * 0.44 + heat * 0.19));
	float hot_core = heat * smoothstep(0.045, 0.44, density * (0.90 + 0.53 * folds));
	ALBEDO = mix(smoke, fire, hot_core);
	float fade = smoothstep(0.0, 0.10, age) * (1.0 - smoothstep(2.05, 3.0, age));
	ALPHA = body * fade * max(heat, air) * 0.91;
}
