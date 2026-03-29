shader_type canvas_item;
render_mode unshaded;

uniform vec4 fog_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fog_alpha = 0.28;
uniform float edge_width = 0.16;
uniform float edge_softness = 0.10;

void fragment() {
	vec2 uv = UV;
	float dist_edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float mask = 1.0 - smoothstep(edge_width, edge_width + edge_softness, dist_edge);
	COLOR = vec4(fog_color.rgb, mask * fog_alpha);
}
