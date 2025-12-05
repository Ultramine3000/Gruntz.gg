// StandardMaterial3D with Grass Wind Effects
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

// Original material uniforms
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);
uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// Wind parameters
uniform float wind_strength : hint_range(0.0, 2.0) = 0.15;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_turbulence : hint_range(0.0, 1.0) = 0.1;
uniform float grass_sway : hint_range(0.0, 1.0) = 0.3;

void vertex() {
	// Original UV scaling
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	
	// Grass wind effects - gentle side-to-side sway
	
	// Base wind wave using only TIME (same for all grass)
	float wind_wave = sin(TIME * wind_speed);
	float wind_wave2 = cos(TIME * wind_speed * 0.7);
	
	// Combine waves for more natural movement
	float combined_wind = mix(wind_wave, wind_wave2, 0.5);
	
	// Add subtle turbulence (gusts)
	float turbulence = sin(TIME * wind_speed * 2.0) * wind_turbulence;
	combined_wind += turbulence;
	
	// Use vertex color red channel or UV.y as wind weight (top of grass moves more)
	float wind_weight = max(COLOR.r, UV.y);
	
	// Apply main wind displacement (horizontal sway only)
	vec2 wind_dir_norm = normalize(wind_direction);
	VERTEX.x += wind_dir_norm.x * combined_wind * wind_strength * wind_weight;
	VERTEX.z += wind_dir_norm.y * combined_wind * wind_strength * wind_weight;
	
	// Gentle side-to-side sway
	float sway = sin(TIME * wind_speed * 2.0);
	VERTEX.x += sway * grass_sway * wind_weight * 0.03;
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;
	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	ALPHA *= albedo.a * albedo_tex.a;
}