shader_type canvas_item;
// Full-screen glitch: torn horizontal slices, an RGB split and scanline noise.
// Put it on a ColorRect over everything and raise `amount` from 0 to 1.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 18.0);
	float slice = floor(uv.y * 28.0);
	float r = hash(vec2(slice, tick));
	// Only some slices tear, more of them as amount rises.
	if (r > 1.0 - amount * 0.7) {
		uv.x += (hash(vec2(tick, slice)) - 0.5) * 0.18 * amount;
	}
	float split = 0.012 * amount;
	vec3 col = vec3(
		texture(screen, uv + vec2(split, 0.0)).r,
		texture(screen, uv).g,
		texture(screen, uv - vec2(split, 0.0)).b);
	float scan = hash(vec2(floor(uv.y * 360.0), tick)) * amount * 0.25;
	COLOR = vec4(col + scan, 1.0);
}
