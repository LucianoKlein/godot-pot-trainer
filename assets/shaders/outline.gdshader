shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);
uniform float outline_width : hint_range(1.0, 30.0, 0.5) = 3.0;
uniform bool enabled = false;
uniform float breath_speed : hint_range(0.5, 5.0, 0.1) = 1.5;
uniform float breath_min : hint_range(0.0, 1.0, 0.05) = 0.3;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	if (enabled) {
		vec2 ps = TEXTURE_PIXEL_SIZE;
		float max_alpha = 0.0;

		// Sample in a circle around the pixel
		for (float angle = 0.0; angle < 6.283; angle += 0.785) {
			vec2 offset = vec2(cos(angle), sin(angle)) * ps * outline_width;
			max_alpha = max(max_alpha, texture(TEXTURE, UV + offset).a);
		}
		// Also sample at half width
		for (float angle = 0.0; angle < 6.283; angle += 0.785) {
			vec2 offset = vec2(cos(angle), sin(angle)) * ps * outline_width * 0.5;
			max_alpha = max(max_alpha, texture(TEXTURE, UV + offset).a);
		}

		// Breathing: oscillate alpha between breath_min and 1.0
		float breath = mix(breath_min, 1.0, (sin(TIME * breath_speed * 3.14159) + 1.0) * 0.5);

		// If current pixel is transparent but neighbor is not, draw outline
		if (col.a < 0.1 && max_alpha > 0.3) {
			col = vec4(outline_color.rgb, outline_color.a * breath);
		}
	}

	COLOR = col;
}
