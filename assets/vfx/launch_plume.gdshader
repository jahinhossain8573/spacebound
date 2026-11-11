shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, skip_vertex_transform, shadows_disabled;

uniform sampler2D turbulence : filter_linear, repeat_enable;
uniform float vacuum_expansion = 0.0;

void vertex() {
	vec3 origin = MODELVIEW_MATRIX[3].xyz;
	vec3 axis = normalize(MODELVIEW_MATRIX[1].xyz);
	vec3 across = cross(axis, normalize(-origin));
	if (dot(across, across) < 0.0001) {
		across = cross(axis, vec3(1.0, 0.0, 0.0));
	}
	VERTEX = origin + VERTEX.y * MODELVIEW_MATRIX[1].xyz
		+ VERTEX.x * length(MODELVIEW_MATRIX[0].xyz) * normalize(across);
}

void fragment() {
	float down = UV.y;
	float edge_texture = texture(turbulence, vec2(UV.x * 1.7, down * 5.0 - TIME * 3.9)).a;
	float rolls = texture(turbulence, vec2(UV.x * 0.8 + 0.12, down * 2.1 - TIME * 1.7)).a;
	float center = 0.5 + sin(down * 26.0 - TIME * 33.0) * down * 0.025;
	float radius = abs(UV.x - center) * 2.0;
	float width = mix(0.34, 0.78, smoothstep(0.0, 0.73, down));
	width += (edge_texture - 0.16) * smoothstep(0.0, 0.26, down) * 0.29;
	float body = 1.0 - smoothstep(width * 0.73, width, radius);
	float tail = 1.0 - smoothstep(0.68 + rolls * 0.13, 1.0, down);
	float hot = (1.0 - smoothstep(width * 0.51, width * 0.92, radius))
		* (1.0 - smoothstep(0.59 + rolls * 0.20, 0.96, down));
	float halo = (1.0 - smoothstep(width * 0.65, 1.0, radius)) * tail * 0.25;
	vec3 amber = mix(vec3(1.0, 0.56, 0.22), vec3(0.64, 0.73, 1.0), vacuum_expansion);
	ALBEDO = mix(amber, vec3(1.0, 0.99, 0.93), hot);
	ALPHA = max(body * tail, halo);
}
