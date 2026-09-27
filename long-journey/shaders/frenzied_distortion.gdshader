shader_type canvas_item;
render_mode unshaded;

// Attach this material to a full-screen ColorRect or another full-screen
// CanvasItem. The ColorRect color should stay white.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// 0 = clean image, 1 = fully destabilized image.
uniform float insanity : hint_range(0.0, 1.0) = 0.7;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform vec2 distortion_center = vec2(0.5, 0.5);

uniform float wave_strength : hint_range(0.0, 0.08) = 0.018;
uniform float wave_frequency : hint_range(0.0, 80.0) = 31.0;
uniform float wave_speed : hint_range(0.0, 8.0) = 2.4;

uniform float swirl_strength : hint_range(0.0, 1.2) = 0.24;

uniform float jitter_strength : hint_range(0.0, 4.0) = 0.65;

uniform float glitch_strength : hint_range(0.0, 0.12) = 0.028;
uniform float glitch_density : hint_range(0.0, 1.0) = 0.16;
uniform float glitch_bands : hint_range(4.0, 160.0) = 42.0;
uniform float glitch_speed : hint_range(1.0, 30.0) = 10.0;

uniform float chroma_aberration : hint_range(0.0, 16.0) = 4.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.12;
uniform vec3 tint_color : source_color = vec3(0.72, 0.38, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.06;

// Sparse white specks that flicker over the unstable image.
uniform float white_noise_density : hint_range(0.0, 0.25) = 0.025;
uniform float white_noise_amount : hint_range(0.0, 1.0) = 0.9;
uniform float white_noise_cell_size : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float white_noise_speed : hint_range(0.0, 60.0) = 18.0;
uniform float white_noise_seed : hint_range(0.0, 100.0) = 17.0;

// Animate dissolve from 0 (fully visible) to 1 (fully torn away).
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec2 tear_direction = vec2(1.0, 0.0);
uniform float tear_roughness : hint_range(0.0, 0.5) = 0.18;
uniform float tear_softness : hint_range(0.001, 0.15) = 0.025;
uniform float tear_glow : hint_range(0.0, 1.0) = 0.55;

float hash21(vec2 p) {
	vec3 hash_input = fract(vec3(p.xyx) * 0.1031);
	hash_input += dot(hash_input, hash_input.yzx + 33.33);
	return fract((hash_input.x + hash_input.y) * hash_input.z);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);

	float bottom_left = hash21(cell);
	float bottom_right = hash21(cell + vec2(1.0, 0.0));
	float top_left = hash21(cell + vec2(0.0, 1.0));
	float top_right = hash21(cell + vec2(1.0, 1.0));
	float bottom = mix(bottom_left, bottom_right, local.x);
	float top = mix(top_left, top_right, local.x);
	return mix(bottom, top, local.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += value_noise(p) * amplitude;
		p = p * 2.03 + vec2(19.1, 7.7);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * speed;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	vec2 centered = uv - distortion_center;
	centered.x *= aspect;
	float radius = length(centered);
	float angle = atan(centered.y, centered.x);
	vec2 radial_dir = centered / max(radius, 0.0001);
	radial_dir.x /= aspect;

	// Slow pulse makes the entire image feel unstable.
	float breathe = 1.0 + sin(t * 2.15) * 0.012 * insanity;
	uv = distortion_center + (uv - distortion_center) * breathe;

	// Rotate in loose spiral bands instead of a uniform circular swirl.
	float edge_pressure = smoothstep(0.08, 0.78, radius);
	float spiral = sin(angle * 5.0 + radius * 19.0 - t * 1.8);
	float swirl_angle = swirl_strength * insanity * edge_pressure
		* (0.55 + spiral * 0.45);
	float ca = cos(swirl_angle);
	float sa = sin(swirl_angle);
	mat2 swirl_rotation = mat2(vec2(ca, -sa), vec2(sa, ca));
	vec2 uv_from_center = uv - distortion_center;
	uv = distortion_center + swirl_rotation * uv_from_center;

	// Multiple interfering ripples create a nervous, twitching surface.
	float ripple = sin(radius * wave_frequency - t * wave_speed
		+ sin(angle * 7.0 + t * 2.7) * 1.35);
	float secondary_ripple = sin(
		dot(centered, vec2(17.0, -23.0)) - t * 3.1
	);
	float wave = ripple * 0.78 + secondary_ripple * 0.22;
	float radial_falloff = mix(0.42, 1.0, edge_pressure);
	uv += radial_dir * wave * wave_strength * insanity * radial_falloff;

	// Pixel-level tremor keeps edges from ever feeling completely still.
	vec2 tremor = vec2(
		sin(t * 6.1 + uv.y * 43.0) + sin(t * 13.7 + uv.y * 19.0) * 0.45,
		cos(t * 5.3 + uv.x * 39.0) + sin(t * 11.9 + uv.x * 23.0) * 0.45
	);
	uv += tremor * SCREEN_PIXEL_SIZE * jitter_strength * insanity;

	// A few horizontal bands tear sideways and then snap back.
	float band = floor(uv.y * glitch_bands);
	float band_time = floor(t * glitch_speed);
	float band_noise = hash21(vec2(band, band_time));
	float tear = step(1.0 - glitch_density, band_noise);
	float band_direction = hash21(vec2(band + 37.0, band_time + 11.0)) * 2.0 - 1.0;
	uv.x += tear * band_direction * glitch_strength * insanity;

	// Separate channels slightly to produce unstable, vibrating color fringes.
	vec2 chroma_offset = vec2(chroma_aberration * insanity * SCREEN_PIXEL_SIZE.x, 0.0);
	float red = texture(screen_texture, clamp(uv + chroma_offset, vec2(0.0), vec2(1.0))).r;
	float green = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).g;
	float blue = texture(screen_texture, clamp(uv - chroma_offset, vec2(0.0), vec2(1.0))).b;
	float alpha = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).a;
	vec3 color = vec3(red, green, blue);

	float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(color, vec3(gray), desaturation * insanity);
	color = mix(color, tint_color, tint_strength * insanity);

	// Faint color breathing makes the output feel electrically unstable.
	color += vec3(0.012, 0.0, 0.02) * sin(t * 3.7 + uv.y * 29.0) * insanity;

	// Each active noise cell gets its own random position instead of filling
	// the full cell, which prevents the specks from aligning into lines.
	vec2 noise_grid = FRAGCOORD.xy / max(white_noise_cell_size, 0.001);
	vec2 noise_cell = floor(noise_grid);
	vec2 noise_local = fract(noise_grid);
	float noise_frame = floor(TIME * white_noise_speed);
	float static_noise = hash21(
		noise_cell + vec2(white_noise_seed, noise_frame * 37.0)
	);
	float speck_active = step(
		1.0 - white_noise_density * insanity,
		static_noise
	);
	vec2 speck_position = vec2(
		hash21(noise_cell + vec2(white_noise_seed + 19.19, noise_frame * 17.0)),
		hash21(noise_cell + vec2(white_noise_seed + 73.31, noise_frame * 29.0))
	);
	vec2 speck_center = mix(vec2(0.5), speck_position, 0.64);
	float speck_shape = 1.0 - smoothstep(
		0.16,
		0.42,
		distance(noise_local, speck_center)
	);
	float white_speck = speck_active * speck_shape;
	color = mix(
		color,
		vec3(1.0),
		white_speck * white_noise_amount * insanity
	);

	// A warped, noisy boundary tears the effect away instead of fading it evenly.
	vec2 tear_axis = tear_direction;
	if (length(tear_axis) < 0.001) {
		tear_axis = vec2(1.0, 0.0);
	}
	tear_axis = normalize(tear_axis);
	float tear_progress = dot(SCREEN_UV - vec2(0.5), tear_axis) + 0.5;
	float tear_noise = fbm(
		SCREEN_UV * vec2(3.0, 21.0)
		+ vec2(white_noise_seed * 0.37, white_noise_seed)
	);
	float torn_edge = tear_progress
		+ (tear_noise - 0.5) * tear_roughness;
	float edge_start = -tear_roughness * 0.5 - tear_softness;
	float edge_end = 1.0 + tear_roughness * 0.5 + tear_softness;
	float tear_threshold = mix(edge_start, edge_end, dissolve);
	float tear_visible = smoothstep(
		tear_threshold - tear_softness,
		tear_threshold + tear_softness,
		torn_edge
	);

	// White heat clings briefly to the torn fibers before they disappear.
	float tear_distance = abs(torn_edge - tear_threshold);
	float tear_heat = 1.0 - smoothstep(
		0.0,
		max(tear_softness * 2.5, 0.001),
		tear_distance
	);
	float dissolve_active = smoothstep(0.0, 0.01, dissolve)
		* (1.0 - smoothstep(0.99, 1.0, dissolve));
	color = mix(
		color,
		vec3(1.0),
		tear_heat * tear_glow * insanity * dissolve_active
	);

	COLOR = vec4(color, alpha * tear_visible);
}
