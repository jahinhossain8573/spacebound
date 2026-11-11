shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform, shadows_disabled;

uniform sampler2D smoke_texture : source_color, filter_linear;

void vertex() {
	vec2 size = vec2(length(MODELVIEW_MATRIX[0].xyz), length(MODELVIEW_MATRIX[1].xyz));
	float angle = INSTANCE_CUSTOM.x;
	mat2 roll = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	VERTEX = MODELVIEW_MATRIX[3].xyz + vec3(roll * (VERTEX.xy * size), 0.0);
}

void fragment() {
	vec4 puff = texture(smoke_texture, UV);
	// The alpha texture also supplies shading across the billows.
	ALBEDO = COLOR.rgb * mix(0.86, 1.0, puff.a);
	ALPHA = puff.a * COLOR.a;
}
