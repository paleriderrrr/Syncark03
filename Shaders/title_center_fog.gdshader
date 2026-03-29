shader_type canvas_item;
render_mode unshaded;

uniform vec4 fog_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fog_alpha = 0.42;
uniform vec2 fog_center = vec2(0.5, 0.52);
uniform vec2 fog_radius = vec2(0.34, 0.22);
uniform float fog_softness = 0.22;

float ellipse_mask(vec2 uv, vec2 center, vec2 radius) {
	vec2 p = (uv - center) / max(radius, vec2(0.001));
	float d = dot(p, p);
	return 1.0 - smoothstep(1.0 - fog_softness, 1.0 + fog_softness, d);
}

void fragment() {
	float mask = ellipse_mask(UV, fog_center, fog_radius);
	COLOR = vec4(fog_color.rgb, mask * fog_alpha);
}
