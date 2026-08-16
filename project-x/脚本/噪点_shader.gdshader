shader_type canvas_item;

uniform float radiation_level : hint_range(0.0, 200.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 基底噪点
uniform float base_noise_intensity : hint_range(0.0, 1.0) = 0.25;
// 高亮闪烁
uniform float spark_density : hint_range(0.5, 3.0) = 1.5;
uniform float spark_size : hint_range(1.0, 10.0) = 2.5;
uniform float spark_brightness : hint_range(0.5, 2.0) = 1.2;
// 整体变暗程度 (建议0.2~0.5)
uniform float darken_amount : hint_range(0.0, 1.0) = 0.2;
// 暗角强度 (0=无暗角, 1=极黑边缘)
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.7;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
    vec4 scene = texture(SCREEN_TEXTURE, SCREEN_UV);
    float intensity = clamp(radiation_level / 200.0, 0.0, 1.0);

    if (intensity <= 0.0) {
        COLOR = scene;
    } else {
        // 1. 基底噪声 (细微暗颗粒)
        vec2 base_uv = SCREEN_UV * 300.0;
        float base_noise = hash(floor(base_uv + TIME * 0.4));
        float base_dark = base_noise * 0.15 + 0.05;
        float base_blend = intensity * base_noise_intensity;
        vec3 darkened_scene = mix(scene.rgb, vec3(base_dark), base_blend);

        // 2. 高亮闪烁点
        vec2 cell_uv = SCREEN_UV * (800.0 / spark_size);
        vec2 cell_id = floor(cell_uv);
        vec2 cell_center = (cell_id + 0.5) / (800.0 / spark_size);

        float event_time = hash(cell_id + 0.1);
        float duration = hash(cell_id + 0.2) * 0.15 + 0.03;
        float time = mod(TIME * 2.5 + event_time * 8.0, 1.0);
        float event = step(time, duration);
        float elapsed = time / max(duration, 0.001);
        float spark_alpha = exp(-elapsed * 3.0);
        float rare = hash(cell_id + 0.3);
        spark_alpha *= mix(0.5, 1.5, step(0.9, rare));

        vec2 delta = (SCREEN_UV - cell_center) * (800.0 / spark_size);
        float dist = length(delta) * 2.0;
        float falloff = clamp(1.0 - dist, 0.0, 1.0);
        spark_alpha *= falloff;

        float spark = event * spark_alpha * intensity * spark_brightness;
        vec3 with_sparks = darkened_scene + vec3(1.0) * spark;

        // 3. 整体压暗
        float final_darken = intensity * darken_amount;
        vec3 darkened = mix(with_sparks, vec3(0.0), final_darken);

        // 4. 暗角 (辐射越强，边缘越暗)
        float vignette = 1.0 - length(SCREEN_UV - 0.5) * 1.8; // 中心1，边缘趋近0
        vignette = clamp(vignette, 0.0, 1.0);
        // 辐射强度控制暗角深度
        vignette = mix(1.0, vignette, intensity * vignette_strength);
        vec3 final_color = darkened * vignette;

        final_color = clamp(final_color, 0.0, 1.0);
        COLOR.rgb = final_color;
        COLOR.a = 1.0;
    }
}