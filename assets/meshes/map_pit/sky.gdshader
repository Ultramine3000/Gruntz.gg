shader_type spatial;
render_mode unshaded, cull_front;

// Time control - SET BY SCRIPT ONLY
uniform float current_time : hint_range(0.0, 1.0) = 0.5; // 0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset

// Sun rise direction control
uniform float sun_rise_angle : hint_range(0.0, 360.0) = 0.0; // Degrees - 0=East, 90=North, 180=West, 270=South
uniform float sun_tilt : hint_range(-1.0, 1.0) = 0.2;

// Sky colors - Day
uniform vec3 day_horizon_color : source_color = vec3(0.5, 0.7, 0.9);
uniform vec3 day_zenith_color : source_color = vec3(0.3, 0.5, 0.9);
uniform vec3 day_ground_color : source_color = vec3(0.4, 0.3, 0.2);

// Sunset/Sunrise colors
uniform vec3 sunset_horizon_color : source_color = vec3(0.8, 0.5, 0.3);
uniform vec3 sunset_zenith_color : source_color = vec3(0.6, 0.4, 0.6);

// Sky colors - Night
uniform vec3 night_horizon_color : source_color = vec3(0.1, 0.1, 0.2);
uniform vec3 night_zenith_color : source_color = vec3(0.05, 0.05, 0.15);
uniform vec3 night_ground_color : source_color = vec3(0.05, 0.05, 0.05);

// Storm colors
uniform vec3 storm_horizon_color : source_color = vec3(0.2, 0.2, 0.25);
uniform vec3 storm_zenith_color : source_color = vec3(0.15, 0.15, 0.2);
uniform vec3 storm_ground_color : source_color = vec3(0.1, 0.1, 0.12);

// Sun settings
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_size : hint_range(0.0, 1.0) = 0.05;
uniform float sun_sharpness : hint_range(1.0, 50.0) = 10.0;

// Lens flare settings
uniform bool enable_lens_flare = true;
uniform float flare_intensity : hint_range(0.0, 3.0) = 1.5;
uniform vec3 flare_color : source_color = vec3(1.0, 0.8, 0.5);

// Stars
uniform bool show_stars = true;
uniform float star_size : hint_range(0.001, 0.02) = 0.005;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;

// Weather
uniform bool storm_active = false;
uniform float storm_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float lightning_flash = 0.0;

const int NUM_STARS = 40;

float get_star_distance(vec3 dir) {
    float min_dist = 10.0;
    
    vec3 stars[40];
    stars[0] = normalize(vec3(0.5, 0.8, 0.3));
    stars[1] = normalize(vec3(0.45, 0.75, 0.35));
    stars[2] = normalize(vec3(0.35, 0.7, 0.4));
    stars[3] = normalize(vec3(0.25, 0.68, 0.5));
    stars[4] = normalize(vec3(0.15, 0.72, 0.55));
    stars[5] = normalize(vec3(0.1, 0.78, 0.5));
    stars[6] = normalize(vec3(0.0, 0.82, 0.45));
    stars[7] = normalize(vec3(-0.3, 0.4, 0.7));
    stars[8] = normalize(vec3(-0.25, 0.38, 0.75));
    stars[9] = normalize(vec3(-0.2, 0.36, 0.8));
    stars[10] = normalize(vec3(0.8, 0.5, 0.2));
    stars[11] = normalize(vec3(-0.6, 0.6, 0.4));
    stars[12] = normalize(vec3(0.3, 0.9, -0.2));
    stars[13] = normalize(vec3(-0.7, 0.4, 0.5));
    stars[14] = normalize(vec3(0.6, 0.7, -0.3));
    stars[15] = normalize(vec3(-0.4, 0.8, 0.3));
    stars[16] = normalize(vec3(0.2, 0.6, 0.7));
    stars[17] = normalize(vec3(-0.8, 0.3, 0.4));
    stars[18] = normalize(vec3(0.7, 0.6, 0.2));
    stars[19] = normalize(vec3(-0.5, 0.7, -0.4));
    stars[20] = normalize(vec3(0.4, 0.5, 0.6));
    stars[21] = normalize(vec3(-0.3, 0.9, 0.1));
    stars[22] = normalize(vec3(0.9, 0.3, 0.2));
    stars[23] = normalize(vec3(-0.2, 0.5, 0.8));
    stars[24] = normalize(vec3(0.5, 0.4, -0.6));
    stars[25] = normalize(vec3(-0.6, 0.5, 0.5));
    stars[26] = normalize(vec3(0.3, 0.8, 0.4));
    stars[27] = normalize(vec3(-0.7, 0.6, -0.3));
    stars[28] = normalize(vec3(0.6, 0.3, 0.7));
    stars[29] = normalize(vec3(-0.4, 0.7, 0.5));
    stars[30] = normalize(vec3(0.8, 0.4, -0.3));
    stars[31] = normalize(vec3(-0.5, 0.8, 0.2));
    stars[32] = normalize(vec3(0.4, 0.6, -0.5));
    stars[33] = normalize(vec3(-0.8, 0.5, 0.1));
    stars[34] = normalize(vec3(0.7, 0.7, 0.1));
    stars[35] = normalize(vec3(-0.3, 0.6, -0.6));
    stars[36] = normalize(vec3(0.5, 0.9, 0.1));
    stars[37] = normalize(vec3(-0.6, 0.4, 0.6));
    stars[38] = normalize(vec3(0.2, 0.7, -0.6));
    stars[39] = normalize(vec3(-0.9, 0.3, 0.2));
    
    for (int i = 0; i < NUM_STARS; i++) {
        float dist = distance(dir, stars[i]);
        min_dist = min(min_dist, dist);
    }
    
    return min_dist;
}

float star_cylinder(float dist, float size) {
    return smoothstep(size, size * 0.5, dist);
}

vec3 calculate_lens_flare(vec3 view_dir, vec3 sun_dir, float sun_visibility) {
    if (!enable_lens_flare || sun_visibility < 0.1) return vec3(0.0);
    
    vec3 flare = vec3(0.0);
    float sun_amount = dot(view_dir, sun_dir);
    
    float glow = pow(max(sun_amount, 0.0), 2.0) * 0.8;
    flare += glow * flare_color;
    
    float glow2 = pow(max(sun_amount, 0.0), 4.0) * 0.5;
    flare += glow2 * flare_color * vec3(1.0, 0.9, 0.7);
    
    float spike = pow(max(sun_amount, 0.0), 50.0) * 2.0;
    flare += spike * vec3(1.0, 1.0, 0.9);
    
    for (int i = 1; i <= 4; i++) {
        float fi = float(i);
        float offset = fi * 0.15;
        float ghost_dot = dot(view_dir, sun_dir) - offset;
        float ghost = pow(max(ghost_dot, 0.0), 8.0) * (0.3 / fi);
        
        vec3 ghost_color = flare_color;
        if (i == 2) ghost_color *= vec3(0.8, 0.9, 1.0);
        if (i == 3) ghost_color *= vec3(1.0, 0.8, 0.9);
        if (i == 4) ghost_color *= vec3(0.9, 1.0, 0.8);
        
        flare += ghost * ghost_color;
    }
    
    return flare * flare_intensity * sun_visibility;
}

void vertex() {
    VERTEX = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX += CAMERA_POSITION_WORLD;
    VERTEX = (inverse(MODEL_MATRIX) * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 view_dir = -normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
    
    // Time is set directly by script via current_time parameter
    float time_cycle = current_time;
    
    // Calculate sun direction with adjustable rise angle
    float angle = time_cycle * 3.14159 * 2.0;
    float rise_rad = radians(sun_rise_angle);
    
    float base_x = cos(angle);
    float base_y = sin(angle);
    
    // Rotate sun path around Y axis
    vec3 sun_direction = normalize(vec3(
        base_x * cos(rise_rad) - sun_tilt * sin(rise_rad),
        base_y,
        base_x * sin(rise_rad) + sun_tilt * cos(rise_rad)
    ));
    
    // Calculate if we're at sunset/sunrise (sun near horizon)
    float sunset_amount = smoothstep(0.3, -0.1, abs(sun_direction.y));
    
    // Day/night calculation
    float day_night = smoothstep(-0.2, 0.2, sun_direction.y);
    
    // Blend between day colors and sunset colors based on sun height
    vec3 current_day_horizon = mix(day_horizon_color, sunset_horizon_color, sunset_amount);
    vec3 current_day_zenith = mix(day_zenith_color, sunset_zenith_color, sunset_amount);
    
    vec3 clear_horizon = mix(night_horizon_color, current_day_horizon, day_night);
    vec3 clear_zenith = mix(night_zenith_color, current_day_zenith, day_night);
    vec3 clear_ground = mix(night_ground_color, day_ground_color, day_night);
    
    float storm_blend = storm_active ? storm_intensity : 0.0;
    vec3 horizon_color = mix(clear_horizon, storm_horizon_color, storm_blend);
    vec3 zenith_color = mix(clear_zenith, storm_zenith_color, storm_blend);
    vec3 ground_color = mix(clear_ground, storm_ground_color, storm_blend);
    
    float height = view_dir.y;
    
    vec3 sky_color;
    if (height > 0.0) {
        sky_color = mix(horizon_color, zenith_color, pow(height, 0.5));
    } else {
        sky_color = mix(horizon_color, ground_color, pow(-height, 0.8));
    }
    
    float sun_amount = dot(view_dir, sun_direction);
    float sun = smoothstep(1.0 - sun_size, 1.0 - sun_size + 0.01, sun_amount);
    sun += pow(max(sun_amount, 0.0), sun_sharpness) * 0.3;
    float sun_visibility = day_night * (1.0 - storm_blend * 0.7);
    sun *= sun_visibility;
    
    vec3 final_color = sky_color;
    final_color = mix(final_color, sun_color, clamp(sun, 0.0, 1.0));
    
    // Add lens flare
    vec3 lens_flare = calculate_lens_flare(view_dir, sun_direction, sun_visibility);
    final_color += lens_flare;
    
    if (show_stars && height > 0.0) {
        float star_dist = get_star_distance(view_dir);
        float star = star_cylinder(star_dist, star_size);
        float star_visibility = (1.0 - day_night) * (1.0 - storm_blend) * 0.8;
        final_color += vec3(star * star_brightness * star_visibility);
    }
    
    if (lightning_flash > 0.0) {
        vec3 lightning_color = vec3(0.9, 0.95, 1.0);
        final_color = mix(final_color, lightning_color, lightning_flash * 0.7);
    }
    
    ALBEDO = final_color;
}
