// Sakura -- cherry blossom petals tumble through a midnight garden.
// Each petal spins and drifts on its own breeze. Spring doesn't wait
// for your code to compile.

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Petal shape -- an elongated soft diamond
float petalShape(vec2 p, float size) {
    p /= size;
    float d = abs(p.x) * 1.8 + abs(p.y);
    return smoothstep(1.0, 0.7, d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;

    vec3 col = texture(iChannel0, uv).rgb;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float darkMask = 1.0 - smoothstep(0.04, 0.20, lum);

    // Moonlight -- soft blue-white glow from upper-left
    vec2 moonPos = vec2(0.15, 0.88);
    float moonDist = distance(uv, moonPos);
    float moonGlow = smoothstep(0.60, 0.05, moonDist);
    col += vec3(0.15, 0.12, 0.25) * moonGlow * darkMask * 0.10;
    // Moon disc
    float moonDisc = smoothstep(0.035, 0.025, moonDist);
    col += vec3(0.6, 0.55, 0.7) * moonDisc * darkMask * 0.15;

    // Falling petals
    for (int i = 0; i < 18; i++) {
        float fi = float(i);
        float seed1 = hash(vec2(fi, 100.0));
        float seed2 = hash(vec2(fi, 200.0));
        float seed3 = hash(vec2(fi, 300.0));
        float seed4 = hash(vec2(fi, 400.0));

        // Fall speed and horizontal drift
        float fallSpeed = 0.03 + seed1 * 0.04;
        float driftFreq = 1.5 + seed2 * 2.0;
        float driftAmp = 0.04 + seed3 * 0.06;

        // Petal position -- loops vertically
        float life = fract(seed2 * 5.7 + iTime * fallSpeed);
        float px = fract(seed1 + sin(life * driftFreq * 6.28 + fi) * driftAmp);
        float py = 1.0 - life;

        // Size varies per petal
        float size = 0.008 + seed4 * 0.010;

        // Spin the petal as it falls
        float angle = iTime * (1.0 + seed3 * 2.0) + fi * 3.0;
        float c = cos(angle), s = sin(angle);

        vec2 diff = vec2((uv.x - px) * aspect, uv.y - py);
        vec2 rotDiff = vec2(c * diff.x - s * diff.y, s * diff.x + c * diff.y);

        float petal = petalShape(rotDiff, size);

        // Petal color -- varies from white-pink to deep pink
        vec3 petalCol = mix(
            vec3(0.95, 0.75, 0.82),
            vec3(0.85, 0.45, 0.60),
            seed4
        );

        // Fade in/out at top and bottom
        float fade = smoothstep(0.0, 0.1, life) * smoothstep(1.0, 0.85, life);

        col += petalCol * petal * fade * darkMask * 0.40;
    }

    // Branch silhouette hint -- a dark diagonal in the upper corner
    float branch = smoothstep(0.008, 0.0,
        abs(uv.y - (1.2 - uv.x * 0.5) - 0.02 * sin(uv.x * 20.0))
    );
    branch *= smoothstep(0.3, 0.8, uv.x);
    branch *= smoothstep(0.7, 0.9, uv.y);
    col = mix(col, vec3(0.04, 0.02, 0.06), branch * darkMask * 0.3);

    // Soft bloom -- pink-tinted
    vec3 bloom = vec3(0.0);
    bloom += texture(iChannel0, uv + vec2( 0.0020, 0.0)).rgb;
    bloom += texture(iChannel0, uv + vec2(-0.0020, 0.0)).rgb;
    bloom += texture(iChannel0, uv + vec2(0.0,  0.0025)).rgb;
    bloom += texture(iChannel0, uv + vec2(0.0, -0.0025)).rgb;
    bloom *= 0.25;
    col += bloom * 0.18 * vec3(0.7, 0.4, 0.6);

    // Night sky vignette
    vec2 vu = uv - 0.5;
    float vig = 1.0 - dot(vu, vu) * 0.55;
    col *= clamp(vig, 0.0, 1.0);

    // Faint grain
    float n = hash(fragCoord.xy + fract(iTime) * 91.0);
    col += (n - 0.5) * 0.018;

    fragColor = vec4(col, 1.0);
}
