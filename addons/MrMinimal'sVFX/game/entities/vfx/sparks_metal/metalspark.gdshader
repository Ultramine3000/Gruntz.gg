shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec3 spark_color : source_color = vec3(1.0, 0.8, 0.4);
uniform vec3 hot_core_color : source_color = vec3(1.0, 1.0, 0.95);
uniform float brightness : hint_range(0.0, 10.0) = 3.0;
uniform float fade_power : hint_range(0.5, 4.0) = 2.0;

void fragment() {
    // Center UV coordinates
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    
    // Soft circular gradient
    float glow = 1.0 - smoothstep(0.0, 1.0, dist);
    glow = pow(glow, fade_power);
    
    // Hot center to cooler edges
    vec3 color = mix(spark_color, hot_core_color, glow * 0.7);
    
    // Particle alpha from COLOR (set by particle system lifetime)
    float alpha = COLOR.a * glow;
    
    ALBEDO = color;
    ALPHA = alpha;
    EMISSION = color * brightness;
}