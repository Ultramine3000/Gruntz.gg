shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_opaque;

// Color settings
uniform vec4 water_color : source_color = vec4(0.2, 0.5, 0.7, 0.9);
uniform vec4 deep_color : source_color = vec4(0.1, 0.3, 0.5, 1.0);

// Night color settings
uniform vec4 night_water_color : source_color = vec4(0.05, 0.1, 0.15, 0.9);
uniform vec4 night_deep_color : source_color = vec4(0.02, 0.05, 0.1, 1.0);

// Day/night transition
uniform float day_night_blend : hint_range(0.0, 1.0) = 1.0; // 0 = night, 1 = day
uniform float ambient_light : hint_range(0.0, 1.0) = 0.3;

// Shoreline settings
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_depth = 0.001;
uniform float foam_depth_multiplier = 1.0;
uniform float foam_min_depth = 0.0001;
uniform float foam_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float foam_edge_sharpness = 0.5;
uniform float foam_distance_compensation = 100.0;

// Distance fade settings
uniform float foam_max_distance = 50.0;
uniform float foam_fade_start = 30.0;

// Depth texture - compatibility mode
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

// Flow settings
uniform vec2 flow_direction = vec2(1.0, 0.0);
uniform float flow_speed = 0.3;
uniform sampler2D noise_texture : hint_default_white;
uniform float noise_scale = 0.5;

// Wave settings
uniform float wave_strength = 1.0;
uniform float wave_frequency = 2.0;

// Shading bands
uniform int shade_bands = 3;

// Foam animation
uniform float foam_animation_speed = 0.2;

varying vec3 world_pos;
varying vec3 vertex_normal;
varying float view_depth;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vertex_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

    // Store view space depth
    vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    view_depth = -view_pos.z;

    // Vertex displacement for waves
    float wave = sin(world_pos.x * wave_frequency + world_pos.z * wave_frequency + TIME * flow_speed * 3.0);
    wave += sin(world_pos.x * wave_frequency * 0.5 - world_pos.z * wave_frequency * 0.7 + TIME * flow_speed * 2.0) * 0.5;
    VERTEX.y += wave * 0.001 * wave_strength;
}

void fragment() {
    // Calculate distance fade
    float distance_fade = 1.0 - smoothstep(foam_fade_start, foam_max_distance, view_depth);

    // Animated flow UV with time offset for foam movement
    vec2 foam_flow_offset = flow_direction * TIME * foam_animation_speed;
    vec2 flow_uv = world_pos.xz * noise_scale + flow_direction * TIME * flow_speed;
    vec2 flow_uv2 = world_pos.xz * noise_scale * 0.7 - flow_direction * TIME * flow_speed * 0.8;

    // Sample noise for base foam texture
    float noise1 = texture(noise_texture, flow_uv + foam_flow_offset).r;
    float noise2 = texture(noise_texture, flow_uv2 + foam_flow_offset * 0.7).r;
    float combined_noise = (noise1 + noise2) * 0.5;

    // Initialize foam factor
    float foam_factor = 0.0;

    // Only calculate foam if within distance
    if (distance_fade > 0.0) {
        // Sample depth texture
        float scene_depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
        float fragment_depth = FRAGCOORD.z;

        // Calculate depth difference
        float depth_diff = abs(scene_depth - fragment_depth);

        // Apply runtime multiplier to foam depth threshold with minimum
        float adjusted_foam_depth = max(foam_depth * foam_depth_multiplier, foam_min_depth);

        // Compensate for distance
        float distance_adjusted_foam_depth = adjusted_foam_depth * (1.0 + view_depth / foam_distance_compensation);

        // Create foam where depth difference is small
        foam_factor = smoothstep(distance_adjusted_foam_depth, 0.0, depth_diff);
        foam_factor = pow(foam_factor, foam_edge_sharpness);

        // Add animated noise to foam edge
        foam_factor *= (0.5 + combined_noise * 0.5);

        // Apply intensity control AND distance fade
        foam_factor *= foam_intensity * distance_fade;
        foam_factor = clamp(foam_factor, 0.0, 1.0);
    }

    // Blend between day and night colors
    vec3 current_water_color = mix(night_water_color.rgb, water_color.rgb, day_night_blend);
    vec3 current_deep_color = mix(night_deep_color.rgb, deep_color.rgb, day_night_blend);

    // Depth-based color
    float depth_factor = clamp((world_pos.y + 1.0) * 0.5, 0.0, 1.0);
    vec3 base_color = mix(current_deep_color, current_water_color, depth_factor);
    base_color = mix(base_color, base_color * 1.2, combined_noise * 0.3);

    // Lighting with day/night consideration
    vec3 light_dir = normalize(vec3(0.5, 1.0, 0.3));
    float NdotL = dot(vertex_normal, light_dir);
    NdotL = (NdotL + 1.0) * 0.5;

    float bands = float(shade_bands);
    float shade = floor(NdotL * bands) / bands;

    // Reduce shading at night, increase ambient
    float min_shade = mix(0.2, 0.4, day_night_blend);
    shade = max(shade, min_shade);

    // Mix in more ambient light at night
    float lighting = mix(ambient_light, 0.5 + shade * 0.5, day_night_blend);

    vec3 final_color = base_color * lighting;

    // Foam is also dimmer at night
    vec3 current_foam_color = foam_color.rgb * mix(0.3, 1.0, day_night_blend);

    // Mix in foam at shoreline
    final_color = mix(final_color, current_foam_color, foam_factor);

    ALBEDO = final_color;
    ALPHA = water_color.a;
}