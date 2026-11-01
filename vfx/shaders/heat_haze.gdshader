shader_type canvas_item;
// Heat haze: the picture sways as if seen through rising hot air, strongest at
// the bottom. Keeps the node's modulate, so fades still work.

uniform float sway_speed : hint_range(0.1, 5.0) = 1.3;
uniform float sway_strength : hint_range(0.0, 0.02) = 0.004;
uniform float noise_scale : hint_range(1.0, 40.0) = 14.0;

void fragment() {
	vec2 uv = UV;
	float wave = sin(UV.x * noise_scale * 2.0 + TIME * sway_speed) * 0.5
		+ sin(UV.y * noise_scale * 5.0 + TIME * sway_speed * 1.5) * 0.3;
	uv.x += wave * sway_strength * (0.3 + UV.y);
	COLOR = texture(TEXTURE, uv) * COLOR;
}
