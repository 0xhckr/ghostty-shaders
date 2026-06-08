// GSIM shader collection for use with ghostty 1.3.0+.
// Durakuras-Hideout Written by GrandBIRDLizard.  

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Moon surface noise (Maria/Craters)
float moonNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Sakura Petal Shape based on durakura-pedals.png
float petalShape(vec2 p, float size) {
    p /= size;
    float r = length(p);
    float theta = atan(p.x, p.y);
    float shape = r - 0.5 * (1.0 + 0.4 * smoothstep(0.2, 1.0, p.y) * sin(abs(theta) * 3.0 - 1.57));
    shape += smoothstep(0.0, -0.4, p.y) * 0.5;
    return smoothstep(0.1, 0.0, shape);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    if (iResolution.y == 0.0) return;

    vec2 uv = fragCoord.xy / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;

    vec3 col = texture(iChannel0, uv).rgb;
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float darkMask = 1.0 - smoothstep(0.04, 0.20, lum);

    // --- FULL MOON (RIGHT SIDE) ---
    vec2 moonPos = vec2(0.85, 0.85);
    vec2 moonUV = (uv - moonPos);
    moonUV.x *= aspect; // Aspect correction for perfect circle
    float moonDist = length(moonUV);
    
    // Moonlight Glow
    float moonGlow = smoothstep(0.40, 0.0, moonDist);
    col += vec3(0.18, 0.22, 0.45) * moonGlow * darkMask * 0.2;
    
    // Moon Surface Rendering
    float moonRadius = 0.055;
    if (moonDist < moonRadius) {
        // Layered noise for "Face of the Moon" spots
        float n = moonNoise(moonUV * 50.0);
        n += moonNoise(moonUV * 100.0) * 0.5;
        n = pow(n, 2.0); // Increase contrast of spots
        
        vec3 moonBaseCol = vec3(0.95, 0.96, 1.0);
        vec3 spotCol = vec3(0.65, 0.67, 0.72); // Darker gray for Maria
        
        // Mix base moon with spots based on noise
        vec3 moonSurface = mix(moonBaseCol, spotCol, n * 0.6);
        
        // Anti-aliased edge
        float edge = smoothstep(moonRadius, moonRadius - 0.002, moonDist);
        col = mix(col, moonSurface, edge * darkMask);
    }

    // --- FALLING PETALS ---
    for (int i = 0; i < 22; i++) {
        float fi = float(i);
        float seed1 = hash(vec2(fi, 111.0));
        float seed2 = hash(vec2(fi, 222.0));
        float seed3 = hash(vec2(fi, 333.0));
        float seed4 = hash(vec2(fi, 444.0));

        float fallSpeed = 0.02 + seed1 * 0.04;
        float driftFreq = 1.2 + seed2 * 2.0;
        float driftAmp = 0.05 + seed3 * 0.07;

        float life = fract(seed2 * 7.7 + iTime * fallSpeed);
        float px = fract(seed1 + sin(life * driftFreq * 6.28 + fi) * driftAmp);
        float py = 1.05 - life * 1.1; 

        float size = 0.012 + seed4 * 0.015;
        float angle = iTime * (0.8 + seed3 * 2.5) + fi;
        float c = cos(angle), s = sin(angle);

        vec2 diff = vec2((uv.x - px) * aspect, uv.y - py);
        vec2 rotDiff = vec2(c * diff.x - s * diff.y, s * diff.x + c * diff.y);

        float petal = petalShape(rotDiff, size);
        vec3 petalCol = mix(vec3(1.0, 0.85, 0.92), vec3(0.95, 0.60, 0.75), seed4);
        float fade = smoothstep(0.0, 0.1, life) * smoothstep(1.0, 0.9, life);
        
        col += petalCol * petal * fade * darkMask * 0.6;
    }

    // Final Vignette
    vec2 vu = uv - 0.5;
    col *= clamp(1.0 - dot(vu, vu) * 0.5, 0.0, 1.0);

    fragColor = vec4(col, 1.0);
}
