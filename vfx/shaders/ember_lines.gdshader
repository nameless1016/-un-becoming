shader_type canvas_item;
// Turns light line art (dark lines on a pale background) into glowing lines on
// a dark background, with a heat-haze sway and a fire flicker. Used by the
// Act 0 cutscene so the layout sketches read as a house burning at night.

uniform vec4 dark_color : source_color = vec4(0.07, 0.04, 0.08, 1.0);
uniform vec4 line_color : source_color = vec4(1.0, 0.36, 0.24, 1.0);
// Lines thinner than a screen pixel come out faint; this brightens them back up.
uniform float line_boost : hint_range(1.0, 4.0) = 2.0;
uniform float sway_speed : hint_range(0.1, 5.0) = 1.4;
uniform float sway_strength : hint_range(0.0, 0.02) = 0.003;
uniform float noise_scale : hint_range(1.0, 40.0) = 18.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.25;

float wave(vec2 p, float t) {
	return sin(p.x * 2.0 + t * sway_speed) * 0.5 + sin(p.y * 5.0 + t * sway_speed * 1.5) * 0.3;
}

void fragment() {
	// The node's modulate (and its parents'), so fades still apply.
	vec4 tint = COLOR;
	vec2 uv = UV;
	// Heat rises: the sway is strongest near the bottom of the image.
	uv.x += wave(UV * noise_scale, TIME) * sway_strength * (0.3 + UV.y);
	vec4 tex = texture(TEXTURE, uv);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float line = clamp((1.0 - lum) * line_boost, 0.0, 1.0);
	float glow = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 11.0 + UV.y * 3.0)) * (0.5 + 0.5 * sin(TIME * 4.3));
	COLOR = vec4(mix(dark_color.rgb, line_color.rgb * glow, line), tex.a) * tint;
}
