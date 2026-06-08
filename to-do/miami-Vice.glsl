//Miami Vice 2026 GramdBIRDLizard
//Ghostty v1.3.x+ compatable 

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float hash1(float n) {
    return fract(sin(n) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Jitter.
    float wobble = sin(uv.y * 220.0 + iTime * 2.1) * 0.0007
                 + sin(uv.y *  19.0 + iTime * 0.8) * 0.0014;
    uv.x += wobble;

    //  Occasional glitch 
    float gSeg = floor(iTime * 1.6);
    float gY   = hash1(gSeg);
    float gFire = step(0.92, hash1(gSeg + 7.3));
    float gBand = smoothstep(0.012, 0.0, abs(uv.y - gY));
    uv.x += gBand * gFire * (hash1(gSeg + 13.1) - 0.5) * 0.045;

    //  Chromatic aberration.
    float ca = 0.0022 + 0.0014 * sin(iTime * 0.55);
    float r = texture(iChannel0, uv + vec2(ca, 0.0)).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - vec2(ca, 0.0)).b;
    vec3 col = vec3(r, g, b);

    //  Bloom .
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float bloom = smoothstep(0.55, 1.0, lum);
    col += col * bloom * 0.45;

    // Sunset tint over dark areas — magenta at bottom, cyan at top.
    float darkMask = 1.0 - smoothstep(0.05, 0.24, lum);
    vec3 neonBottom = vec3(0.42, 0.06, 0.30);
    vec3 neonTop    = vec3(0.05, 0.28, 0.40);
    vec3 neonTint   = mix(neonBottom, neonTop, uv.y);
    col += neonTint * darkMask * 0.18;

    // Scanlines.
    float scan = 0.86 + 0.14 * sin(fragCoord.y * 3.14159);
    col *= scan;

    // Film  grain.
    float grain = hash(fragCoord + fract(iTime) * 91.0) - 0.5;
    col += grain * 0.05;

    // Vignette.
    vec2 vu = uv - 0.5;
    float vig = 1.0 - dot(vu, vu) * 0.75;
    col *= clamp(vig, 0.0, 1.0);

    fragColor = vec4(col, 1.0);
}
