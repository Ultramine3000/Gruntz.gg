shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap;

// Base colors
uniform vec4 base_color : source_color = vec4(0.616, 0.502, 0.267, 1.0); // Your #9D8044
uniform vec4 dark_color : source_color = vec4(0.5, 0.4, 0.2, 1.0);
uniform vec4 light_color : source_color = vec4(0.7, 0.6, 0.35, 1.0);

// Noise and detail
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.3;
uniform float color_variation : hint_range(0.0, 1.0) = 0.4;

// Triplanar blending sharpness
uniform float blend_sharpness : hint_range(1.0, 16.0) = 4.0;

// Simple hash function for noise
vec3 hash3(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx);
}

// Voronoi-style noise for more organic variation
float voronoi(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);

    float res = 8.0;
    for(int k = -1; k <= 1; k++) {
        for(int j = -1; j <= 1; j++) {
            for(int i = -1; i <= 1; i++) {
                vec3 b = vec3(float(i), float(j), float(k));
                vec3 r = b - f + hash3(p + b);
                float d = dot(r, r);
                res = min(res, d);
            }
        }
    }
    return sqrt(res);
}

void fragment() {
    // Get world position for triplanar mapping
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Triplanar blend weights based on normal
    vec3 blend_weights = abs(NORMAL);
    blend_weights = pow(blend_weights, vec3(blend_sharpness));
    blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z);

    // Sample noise from three planes
    float noise_xy = voronoi(world_pos * noise_scale);
    float noise_xz = voronoi(world_pos.xzy * noise_scale);
    float noise_yz = voronoi(world_pos.zyx * noise_scale);

    // Blend noise samples
    float noise = noise_xy * blend_weights.z +
                  noise_xz * blend_weights.y +
                  noise_yz * blend_weights.x;

    // Add secondary detail layer
    float detail = voronoi(world_pos * noise_scale * 3.0) * 0.5;
    noise = mix(noise, detail, detail_strength);

    // Create color variation
    vec3 final_color = mix(dark_color.rgb, light_color.rgb, noise);
    final_color = mix(base_color.rgb, final_color, color_variation);

    // Slight rim lighting effect for cartoon feel
    float rim = 1.0 - dot(NORMAL, VIEW);
    rim = pow(rim, 3.0) * 0.15;
    final_color += vec3(rim);

    ALBEDO = final_color;
    ROUGHNESS = 0.85; // Keep it matte for mil-sim feel
    SPECULAR = 0.2;   // Low specularity
}