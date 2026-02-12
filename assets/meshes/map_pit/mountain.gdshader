shader_type spatial;

// Color definitions
uniform vec3 base_color : source_color = vec3(0.4, 0.3, 0.2); // Brown base
uniform vec3 mid_color : source_color = vec3(0.5, 0.5, 0.5); // Grey middle
uniform vec3 snow_color : source_color = vec3(0.95, 0.95, 1.0); // White/blue snow

// Height thresholds (world space units)
uniform float snow_height : hint_range(-100.0, 100.0) = 8.0;
uniform float mid_height : hint_range(-100.0, 100.0) = 4.0;

// Blend sharpness
uniform float blend_sharpness : hint_range(0.1, 10.0) = 2.0;

// Noise settings - smoother
uniform float noise_scale : hint_range(0.01, 5.0) = 0.3;
uniform float noise_strength : hint_range(0.0, 10.0) = 1.5;

varying float world_height;
varying vec3 world_pos;

// Smooth hash function
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Smooth Perlin noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Smoothstep for better interpolation
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    
    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

// Smooth FBM with fewer octaves
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    // Only 3 octaves for smoothness
    for(int i = 0; i < 3; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void vertex() {
    vec4 world_position = MODEL_MATRIX * vec4(VERTEX, 1.0);
    world_pos = world_position.xyz;
    world_height = world_position.y;
}

void fragment() {
    // Generate smooth noise based on world XZ position
    vec2 noise_pos = world_pos.xz * noise_scale;
    float base_noise = fbm(noise_pos);
    
    // Apply noise to height
    float noise_offset = base_noise * noise_strength;
    float adjusted_height = world_height + noise_offset;
    
    // Smooth blend factors
    float base_to_mid = smoothstep(
        mid_height - blend_sharpness, 
        mid_height + blend_sharpness, 
        adjusted_height
    );
    
    float mid_to_snow = smoothstep(
        snow_height - blend_sharpness, 
        snow_height + blend_sharpness, 
        adjusted_height
    );
    
    // Blend colors smoothly
    vec3 color = mix(base_color, mid_color, base_to_mid);
    color = mix(color, snow_color, mid_to_snow);
    
    ALBEDO = color;
    
    // Smooth roughness transition
    ROUGHNESS = mix(0.8, 0.95, mid_to_snow);
}