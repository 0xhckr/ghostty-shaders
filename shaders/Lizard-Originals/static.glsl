// Ghostty 1.3.x Static Shadery:
// Best as a transition or game effect, but still usefull as a terminal sequence 
// Written by GrandBirdLizard

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime;

    // Physical Jitter (only happens during the first 0.2 seconds)
    float jitter = (sin(t * 100.0) * 0.02) * smoothstep(0.2, 0.0, t);
    uv.x += jitter;

    // The Static tuned for grain
    float noise = fract(sin(dot(uv + t, vec2(12.9898, 78.233))) * 43758.5453);
    
    //  Short TV opening animation
    vec4 terminal = texture(iChannel0, uv);
    float intensity = clamp(2.0 - t, 0.0, 1.0);
    
    //  Final Output
    vec3 color = mix(terminal.rgb, vec3(noise), intensity);
    fragColor = vec4(color, 1.0);
}
