/*
Ghostty 1.3.0+ Off-the-Air
Written by GrandBirdLizard
Channel0: Terminal Text/UI
iTime: Seconds since the terminal opened
*/

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord.xy / iResolution.xy;
    
    float vScale = 1.0;
    float hScale = 1.0;
    vec3 flash = vec3(0.0);

    // --- ENTRANCE: The Warmup ---
    // Fast expansion to beat picom's fade-in
    if (iTime < 0.5) {
        float t = iTime / 0.5;
        vScale = mix(0.001, 1.0, pow(t, 0.2));
        hScale = mix(0.01, 1.0, pow(t, 0.1));
        flash = vec3(3.0) * smoothstep(0.05, 0.0, abs(q.y - 0.5)) * (1.0 - t);
    }

    // --- EXIT: The Ender ---
    // Safe Ratio Trigger: Only active after 1s of uptime
    if (iTime > 1.0 && (iResolution.x / iResolution.y > 10.0)) {
        vScale = 0.01;
        hScale = 0.05;
        float dist = abs(q.y - 0.5);
        flash = vec3(5.0) * smoothstep(0.03, 0.0, dist); 
        flash += vec3(0.6, 0.2, 0.9) * smoothstep(0.15, 0.0, dist) * 3.0; 
    }

    vec2 uv = (q - 0.5) / vec2(hScale, vScale) + 0.5;
    vec3 col = texture(iChannel0, uv).rgb;
    
    // Final Composite
    col += flash;

    // The Hardware Mask
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) col = vec3(0.0);

    fragColor = vec4(col, 1.0);
}
