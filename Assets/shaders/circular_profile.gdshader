shader_type canvas_item;

void fragment() {
	// Get the UV coordinates centered around (0.5, 0.5)
	vec2 uv = UV - vec2(0.5, 0.5);

	// Calculate distance from center
	float distance = length(uv);

	// If distance is greater than 0.5 (radius of circle), discard the pixel
	if (distance > 0.5) {
		discard;
	}

	// Otherwise, sample the texture normally
	COLOR = texture(TEXTURE, UV);
}
