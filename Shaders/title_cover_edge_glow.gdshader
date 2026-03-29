hader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float glow_size = 4.0;
uniform float glow_intensity = 1.3;

void fragment() {
	float incoming_alpha = COLOR.a;
	vec4 base = texture(TEXTURE, UV);
	float center = base.a;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * glow_size;

	float neighbor = 0.0;
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-step_uv.x, 0.0)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, -step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(step_uv.x, step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-step_uv.x, -step_uv.y)).a);

	float edge = max(neighbor - center, 0.0);
	float alpha = edge * glow_color.a * glow_intensity * incoming_alpha;
	COLOR = vec4(glow_color.rgb, alpha);
}
