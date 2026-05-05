// Aurora Borealis -- shimmering curtains of green and purple light
// drift across the upper sky behind terminal text.

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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.1;
        a *= 0.48;
    }
    return v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec3 col = texture(iChannel0, uv).rgb;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float darkMask = 1.0 - smoothstep(0.03, 0.18, lum);

    // Aurora curtains -- vertical ribbons that sway horizontally
    float t = iTime * 0.06;
    float curtain1 = fbm(vec2(uv.x * 3.0 + t, uv.y * 0.8 + t * 0.3));
    float curtain2 = fbm(vec2(uv.x * 2.5 - t * 0.7, uv.y * 1.2 + t * 0.2 + 5.0));
    float curtain3 = fbm(vec2(uv.x * 4.0 + t * 0.4, uv.y * 0.6 - t * 0.1 + 10.0));

    // Curtains strongest in upper half, fading down
    float heightFade = smoothstep(0.15, 0.85, uv.y);
    heightFade *= smoothstep(1.0, 0.75, uv.y);

    // Color the curtains -- green core, purple edges, teal accents
    vec3 green  = vec3(0.15, 0.85, 0.35);
    vec3 purple = vec3(0.45, 0.15, 0.65);
    vec3 teal   = vec3(0.10, 0.60, 0.55);

    vec3 aurora = vec3(0.0);
    aurora += green  * curtain1 * 0.50;
    aurora += purple * curtain2 * 0.35;
    aurora += teal   * curtain3 * 0.25;

    // Shimmer -- fast flicker within the curtains
    float shimmer = noise(vec2(uv.x * 20.0, uv.y * 8.0 + iTime * 0.8));
    aurora *= 0.85 + 0.30 * shimmer;

    aurora *= heightFade;
    col += aurora * darkMask * 0.20;

    // Starfield -- tiny pinpoints in dark areas
    float starGrid = 80.0;
    vec2 starCell = floor(uv * starGrid);
    float starVal = hash(starCell);
    float isStar = step(0.97, starVal);
    float twinkle = 0.5 + 0.5 * sin(iTime * (2.0 + starVal * 4.0) + starVal * 50.0);
    vec2 starLocal = fract(uv * starGrid) - 0.5;
    float starDot = smoothstep(0.12, 0.0, length(starLocal));
    col += vec3(0.7, 0.8, 1.0) * starDot * isStar * twinkle * darkMask * 0.4;

    // Soft bloom
    vec3 bloom = vec3(0.0);
    bloom += texture(iChannel0, uv + vec2( 0.0020, 0.0)).rgb;
    bloom += texture(iChannel0, uv + vec2(-0.0020, 0.0)).rgb;
    bloom += texture(iChannel0, uv + vec2(0.0,  0.0025)).rgb;
    bloom += texture(iChannel0, uv + vec2(0.0, -0.0025)).rgb;
    bloom *= 0.25;
    col += bloom * 0.15 * vec3(0.3, 0.8, 0.5);

    // Gentle vignette
    vec2 vu = uv - 0.5;
    float vig = 1.0 - dot(vu, vu) * 0.50;
    col *= clamp(vig, 0.0, 1.0);

    // Faint grain
    float n = hash(fragCoord.xy + fract(iTime) * 91.0);
    col += (n - 0.5) * 0.018;

    fragColor = vec4(col, 1.0);
}
