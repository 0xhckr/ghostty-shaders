// Ghostty 1.3.0+ Static Shadery
// Written by GrandBirdLizard
// iChannel0: Terminal Text/UI
// iTime: Seconds since the terminal opened

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime;

    // 1. Physical Jitter (only happens during the first 0.2 seconds)
    float jitter = (sin(t * 100.0) * 0.02) * smoothstep(0.2, 0.0, t);
    uv.x += jitter;

    // 2. The Static (Your idea, tuned for grain)
    float noise = fract(sin(dot(uv + t, vec2(12.9898, 78.233))) * 43758.5453);
    
    // 3. The "Channel Tuning" Fade
    // We use your idea of the static being the 'boot' state
    vec4 terminal = texture(iChannel0, uv);
    float intensity = clamp(2.0 - t, 0.0, 1.0);
    
    // 4. Final Output
    vec3 color = mix(terminal.rgb, vec3(noise), intensity);
    fragColor = vec4(color, 1.0);
}
