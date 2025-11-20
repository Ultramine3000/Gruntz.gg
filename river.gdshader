shader_type spatial;
render_mode cull_back, unshaded;
// Color settings
uniform vec4 water_color : source_color = vec4(0.2, 0.5, 0.7, 0.9);
uniform vec4 deep_color : source_color = vec4(0.1, 0.3, 0.5, 1.0);
// Flow settings
uniform vec2 flow_direction = vec2(1.0, 0.0);
uniform float flow_speed = 0.3;
uniform sampler2D noise_texture : hint_default_white;
uniform float noise_scale = 0.5;
// Wave settings
uniform float wave_strength = 1.0;
uniform float wave_frequency = 2.0;
// Shading bands (for flat look)
uniform int shade_bands = 3;
varying vec3 world_pos;
varying vec3 vertex_normal;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	// Vertex displacement for waves - scaled down to 0.001 base
	float wave = sin(world_pos.x * wave_frequency + world_pos.z * wave_frequency + TIME * flow_speed * 3.0);
	wave += sin(world_pos.x * wave_frequency * 0.5 - world_pos.z * wave_frequency * 0.7 + TIME * flow_speed * 2.0) * 0.5;
	VERTEX.y += wave * 0.001 * wave_strength;
}
void fragment() {
	// Animated flow UV
	vec2 flow_uv = world_pos.xz * noise_scale + flow_direction * TIME * flow_speed;
	vec2 flow_uv2 = world_pos.xz * noise_scale * 0.7 - flow_direction * TIME * flow_speed * 0.8;
	
	// Sample noise for variation
	float noise1 = texture(noise_texture, flow_uv).r;
	float noise2 = texture(noise_texture, flow_uv2).r;
	float combined_noise = (noise1 + noise2) * 0.5;
	
	// Use vertex Y position for depth approximation (lower = deeper)
	float depth_factor = clamp((world_pos.y + 1.0) * 0.5, 0.0, 1.0);
	
	// Mix colors based on depth
	vec3 base_color = mix(deep_color.rgb, water_color.rgb, depth_factor);
	
	// Add noise variation to color
	base_color = mix(base_color, base_color * 1.2, combined_noise * 0.3);
	
	// Flat shading - simple directional light
	vec3 light_dir = normalize(vec3(0.5, 1.0, 0.3));
	float NdotL = dot(vertex_normal, light_dir);
	NdotL = (NdotL + 1.0) * 0.5; // Remap from [-1,1] to [0,1]
	
	// Create flat bands
	float bands = float(shade_bands);
	float shade = floor(NdotL * bands) / bands;
	shade = max(shade, 0.4); // Minimum brightness
	
	// Apply shading
	vec3 final_color = base_color * (0.5 + shade * 0.5);
	
	ALBEDO = final_color;
	ALPHA = water_color.a;
}