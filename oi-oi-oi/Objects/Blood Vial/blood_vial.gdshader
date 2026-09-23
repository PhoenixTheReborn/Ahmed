shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Health Bounds & Ratio
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float fill_min_y = -0.05; 
uniform float fill_max_y = 0.05; 


uniform vec2 slosh_angle = vec2(0.0, 0.0);


uniform vec4 color_full : source_color = vec4(0.0, 1.0, 0.2, 1.0);  
uniform vec4 color_mid : source_color = vec4(1.0, 0.4, 0.0, 1.0);    
uniform vec4 color_low : source_color = vec4(1.0, 0.0, 0.0, 1.0);      
uniform vec4 liquid_color : source_color = vec4(0.25, 0.01, 0.01, 1.0); 
uniform float emission_energy : hint_range(0.0, 16.0) = 4.0;

varying vec3 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {

    float target_y = mix(fill_min_y, fill_max_y, health_ratio);
    float slosh_offset = (local_position.x * slosh_angle.x + local_position.z * slosh_angle.y);
    
    if (local_position.y > (target_y - slosh_offset)) {
        discard;
    }


    vec3 glow_color;
    if (health_ratio > 0.5) {
        float t = (health_ratio - 0.5) * 2.0;
        glow_color = mix(color_mid.rgb, color_full.rgb, t);
    } else {
        float t = clamp(health_ratio * 2.0, 0.0, 1.0);
        t = pow(t, 1.8);
        glow_color = mix(color_low.rgb, color_mid.rgb, t);
    }


    float pulse_boost = 0.0;
    if (health_ratio < 0.35) {

        float danger_factor = (0.35 - health_ratio) / 0.35;
        float pulse_speed = mix(6.0, 16.0, danger_factor);
        
        // Double-thump heartbeat wave equation
        float wave = sin(TIME * pulse_speed);
        pulse_boost = pow(max(0.0, wave), 4.0) * (1.5 + danger_factor * 3.0);
    }

    ALBEDO = liquid_color.rgb;
    EMISSION = glow_color * (emission_energy + pulse_boost);
    ROUGHNESS = 0.15;
    METALLIC = 0.0;
}