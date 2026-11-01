shader_type canvas_item;

uniform sampler2D portal_noise_texture: repeat_enable, filter_nearest;
uniform float pixel_resolution : hint_range(16.0, 512.0, 1.0) = 64.0;
uniform float speed = 0.3;
uniform float power_stregth : hint_range(0.0, 5.0, 0.1) = 0.3;
uniform vec3 portal_dark_color : source_color = vec3(0.15, 0.0, 0.3);
uniform vec3 portal_bright_color : source_color = vec3(0.3, 0.9, 1.0);
uniform float twist_strength: hint_range(-10.0, 10.0, 0.1) = 3.0;
uniform float rim_color_stregth = 2.0;
uniform vec3 rim_color_source: source_color;

void fragment() {
    // 1. Quantize the UV to a discrete grid based on target resolution
    vec2 pixel_grid_uv = floor(UV * pixel_resolution) / pixel_resolution;

    // 2. Perform all math and sampling on the snapped UV
    vec2 centered_uv = pixel_grid_uv - 0.5;
    float distance_from_centered_uv = length(centered_uv);
    float angle_around_center = atan(centered_uv.y, centered_uv.x);
    float angle_remap = angle_around_center / PI * 0.5 + 0.5;
    
    vec2 polar_uv = vec2(angle_remap + distance_from_centered_uv * twist_strength, distance_from_centered_uv);
    
    float noise_value = texture(portal_noise_texture, vec2(polar_uv.x + TIME * speed, polar_uv.y + TIME * speed)).r;
    float combine_effect = smoothstep(0.4, 0.6, pow(noise_value, power_stregth));
    vec3 portal_color = mix(portal_dark_color, portal_bright_color, combine_effect);
    
    float mask_circle = smoothstep(0.5, 0.65, 1.0 - distance_from_centered_uv);
    float center_hole_mask = smoothstep(0.03, 0.1, distance_from_centered_uv);
    float rim_rising = smoothstep(0.25, 0.5, distance_from_centered_uv);
    float rim_falling = smoothstep(0.5, 0.25, distance_from_centered_uv);
    float rim_mask = rim_rising * rim_falling;
    
    COLOR = vec4(vec3(portal_color * center_hole_mask + rim_mask * rim_color_source * rim_color_stregth), mask_circle * noise_value);
}