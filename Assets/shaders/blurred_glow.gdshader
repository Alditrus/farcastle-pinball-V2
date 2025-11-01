shader_type canvas_item;

// Editable parameters
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float blur_radius : hint_range(0.0, 20.0, 0.5) = 8.0;
uniform float glow_intensity : hint_range(0.0, 2.0, 0.1) = 1.0;
uniform int blur_quality : hint_range(1, 16, 1) = 8;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec4 glow = vec4(0.0);

	// Multi-pass gaussian blur approximation
	float weight_sum = 0.0;

	for (int i = -blur_quality; i <= blur_quality; i++) {
		for (int j = -blur_quality; j <= blur_quality; j++) {
			vec2 offset = vec2(float(i), float(j)) * blur_radius * TEXTURE_PIXEL_SIZE;
			float distance = length(vec2(float(i), float(j)));

			// Gaussian weight calculation
			float weight = exp(-distance * distance / (2.0 * blur_radius * blur_radius));

			vec4 sample_col = texture(TEXTURE, UV + offset);
			glow += sample_col * weight;
			weight_sum += weight;
		}
	}

	// Normalize
	glow /= weight_sum;

	// Apply glow color and intensity
	vec4 colored_glow = vec4(glow_color.rgb, glow.a * glow_intensity);

	// Composite: glow behind original
	COLOR = mix(colored_glow, col, col.a);
}
