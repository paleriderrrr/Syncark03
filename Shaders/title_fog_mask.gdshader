shader_type canvas_item;
render_mode unshaded;

uniform vec4 fog_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fog_alpha = 0.22;
uniform float fog_scale = 3.2;
uniform float fog_softness = 0.62;
uniform float lower_bias = 0.75;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	vec2 noise_uv = vec2(uv.x * fog_scale, uv.y * fog_scale * 0.72);
	float cloud = fbm(noise_uv);
	float vertical = smoothstep(0.15, 1.0, uv.y + lower_bias - 0.25);
	float mask = smoothstep(fog_softness, 1.0, cloud) * vertical;
	COLOR = vec4(fog_color.rgb, mask * fog_alpha);
}
