shader_type spatial;

uniform sampler2D local_ground : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D pad_ground : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D florida_surface : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D globe_surface : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform mat3 globe_to_kennedy;
uniform float ground_radius;
uniform float local_detail = 0.0;
uniform bool launch_plane = false;
uniform float plane_weight = 1.0;
uniform float ocean_detail = 0.0;

varying vec3 globe_point;
varying vec2 plane_position;

void vertex() {
	if (launch_plane) {
		plane_position = VERTEX.xz;
		vec3 radial = vec3(VERTEX.x, ground_radius, VERTEX.z);
		globe_point = transpose(globe_to_kennedy) * normalize(radial);
		NORMAL = normalize(radial);
	} else {
		globe_point = VERTEX;
	}
}

float edge_weight(vec2 uv, float feather) {
	vec2 edge = min(uv, 1.0 - uv);
	return smoothstep(0.0, feather, min(edge.x, edge.y));
}

void fragment() {
	if (launch_plane) {
		// The globe already has the same material. Reveal it progressively
		// around the perimeter and as the camera leaves the launch site.
		float coverage = plane_weight * edge_weight(plane_position / 12288.0 + vec2(0.5), 0.16);
		float threshold = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (coverage < threshold) {
			discard;
		}
	}
	vec3 radial = normalize(globe_point);
	vec2 lon_lat = vec2(atan(-radial.z, radial.x), asin(clamp(radial.y, -1.0, 1.0)));
	vec2 globe_uv = vec2(lon_lat.x / TAU + 0.5, 0.5 - lon_lat.y / PI);
	vec3 base = texture(globe_surface, launch_plane ? globe_uv : UV).rgb;

	// The Florida crop is georeferenced in the same longitude/latitude system as the globe.
	vec2 florida_uv = (degrees(lon_lat) - vec2(-83.5, 31.5)) / vec2(6.0, -5.5);
	float florida_weight = edge_weight(florida_uv, 0.22);
	if (florida_weight > 0.0) {
		base = mix(base, texture(florida_surface, florida_uv).rgb, florida_weight);
	}

	vec3 kennedy = globe_to_kennedy * radial;
	if (local_detail > 0.0 && kennedy.y > 0.0) {
		// Project both surfaces onto the same tangent plane so their textures meet.
		vec2 position_m = kennedy.xz * ground_radius / kennedy.y;
		vec2 local_uv = position_m / 12288.0 + vec2(0.5);
		vec2 pad_uv = position_m / 2048.0 + vec2(0.5);
		// Sample before applying the masks so mipmap derivatives stay continuous at the borders.
		vec4 detail = texture(local_ground, local_uv);
		vec4 pad = texture(pad_ground, pad_uv);
		detail.rgb = mix(detail.rgb, pad.rgb, edge_weight(pad_uv, 0.15) * pad.a);
		base = mix(base, detail.rgb, detail.a * edge_weight(local_uv, 0.02) * local_detail);
	}
	if (ocean_detail > 0.0) {
		// Local wave shading for the open-ocean recovery camera.
		vec2 p = lon_lat * 6371.0;
		float waves = sin(p.y * 2.4 + sin(p.x * 1.6) * 1.2 + TIME * 0.8);
		waves += 0.45 * sin(dot(p, vec2(2.0, 4.5)) - TIME * 1.4);
		float crest = smoothstep(0.45, 1.35, waves);
		float detail = ocean_detail * (1.0 - smoothstep(0.2, 0.7, length(fwidth(p))));
		base = mix(base, base * (0.94 + crest * 0.21) + vec3(0.009, 0.014, 0.018) * crest, detail);
	}
	ALBEDO = base;
	ROUGHNESS = 0.85;
}
