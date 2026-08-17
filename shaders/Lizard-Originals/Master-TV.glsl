// Ghostty 1.3.x+ Master-TV
// By GrandBIRDLizard 2026
// Optimized for high res and hrz systems

// BSD 3-Clause License (Modified - Name Attribution Required)
// Copyright (c) [2026], GrandBIRDLizard.
// All rights reserved.

vec2 curve(vec2 uv) {
    uv = (uv - 0.5) * 2.0;
    uv *= 1.1;
    // Loosened curvature by increasing denominators (less dramatic warp inwards)
    uv.x *= 1.0 + pow((abs(uv.y) / 7.5), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 6.5), 2.0);
    uv = (uv / 2.0) + 0.5;
    uv = uv * 0.92 + 0.04;
    return uv;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord.xy / iResolution.xy;
    float t = iTime;

    // THE STARTUP 
    float vPinch = smoothstep(0.0, 0.3, t);
    float hPinch = smoothstep(0.2, 0.5, t);
    
    vec2 uv = q;
    uv.y = (uv.y - 0.5) / max(vPinch, 0.001) + 0.5;
    uv.x = (uv.x - 0.5) / max(hPinch, 0.001) + 0.5;

    // Curvature
    uv = curve(uv);

    // CHROMATIC ABERRATION & JITTER (Toned down for text clarity)
    float jitter = sin(0.3*t+uv.y*21.0)*sin(0.7*t+uv.y*29.0)*sin(0.3+0.33*t+uv.y*31.0)*0.0006;
    
    vec3 col;
    // Sample with tighter, minimized offsets to prevent blurry color bleeding
    col.r = texture(iChannel0, vec2(jitter + uv.x + 0.0004, uv.y + 0.0004)).x + 0.05;
    col.g = texture(iChannel0, vec2(jitter + uv.x + 0.0000, uv.y - 0.0008)).y + 0.05;
    col.b = texture(iChannel0, vec2(jitter + uv.x - 0.0008, uv.y + 0.0000)).z + 0.05;

    // COLOR CORRECTION & VIGNETTE
    col = clamp(col*0.6 + 0.4*col*col*1.0, 0.0, 1.0);
    float vig = (16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y));
    col *= vec3(pow(vig, 0.3));
    col *= vec3(0.95, 1.05, 0.95); // Slight Green Tint (Authentic CRT)
    col *= 2.8;

    // Anti-Moiré
    // Used a fixed multiplier (2.0) to align with pixels
    float scans = clamp(0.35 + 0.35 * sin(uv.y * iResolution.y * 1.5), 0.0, 1.0);
    col *= vec3(0.4 + 0.7 * pow(scans, 1.7));

    float noise = fract(sin(dot(uv + t, vec2(12.9898, 78.233))) * 43758.5453);
    float staticIntensity = smoothstep(0.6, 0.0, t);
    col = mix(col, vec3(noise), staticIntensity);
    //Check Bounds
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        col = vec3(0.0);
    }

    fragColor = vec4(col, 1.0);
}
