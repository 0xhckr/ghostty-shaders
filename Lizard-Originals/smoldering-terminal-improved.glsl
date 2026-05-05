//GSIM Smoldering Terminal (Optimized)\\
//\\Revised By GrandBirdLizard 2026//\\
//Ghostty 1.3+ / Mesa Compliant\\

//To get this running smoothly  under current Mesa drivers, I needed to completely rethink the mathematics //of how the smoke is generated.\\

/*The original code usesd a Gather Approach with nested for loops. For every single pixel on your screen, it searches an 
×8 grid around it to see if there is a "target color," and if so, it draws smoke. 
At 1440p running at 120Hz, your GPU is performing millions of unnecessary texture samples per frame, which is why it cho
es.

Here is the GSIM Optimized "Smoldering Terminal".I replaced the O(N2) radial search with an O(N) Directional Noise Warp
Since smoke rises, a pixel only needs to look downward to see if there is a source beneath it.*/

// Settings
// Note: If you want your TEXT to smoke instead of the background, 
// change TARGET_COLOR to match your font color.
const vec3 TARGET_COLOR = vec3(0.0, 0.0, 0.0); 
const float COLOR_TOLERANCE = 0.05;
const vec3 SMOKE_COLOR = vec3(0.6, 0.7, 0.8);

// High-Speed Mesa-friendly Noise
// Replaces the heavy dot-product noise with a faster 2D hash
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 baseColor = texture(iChannel0, uv);

    // Generate Wind
    vec2 smokeUV = uv * 20.0;
    smokeUV.y -= iTime * 1.5;
    smokeUV.x += sin(uv.y * 10.0 + iTime) * 0.5;e

    // Layer two octaves to achieve similar "whisp" as smoke
    float n = noise(smokeUV) * 0.5 + noise(smokeUV * 2.0) * 0.25;

    // Optimized Directional *Mesa Fix*
    // Instead of a nested loop, we only sample DOWNWARDS.
    float smokeAccum = 0.0;
    
    // Mesa requires loop limits to be constant integers for unrolling
    const int STEPS = 8; 
    float maxRise = 0.15; 

    for(int i = 0; i < STEPS; i++) {
        float dist = float(i) / float(STEPS) * maxRise;

        // Offset the sample downward, and warp it horizontally with noise
        vec2 sampleUV = uv + vec2((n - 0.5) * 0.03, -dist);

        // Bounds check
        if (sampleUV.y > 0.0 && sampleUV.x > 0.0 && sampleUV.x < 1.0) {
            vec3 sColor = texture(iChannel0, sampleUV).rgb;

            // Use step() instead of if() logic to prevent warp divergence
            vec3 diff = abs(sColor - TARGET_COLOR);
            float isTarget = step(diff.r, COLOR_TOLERANCE) * step(diff.g, COLOR_TOLERANCE) * step(diff.b, COLOR_TOLERANCE);

           
            float falloff = 1.0 - (float(i) / float(STEPS));

            smokeAccum += isTarget * falloff * n;
        }
    }

    // Normalize the accumulated smoke
    float smokePresence = clamp(smokeAccum / float(STEPS) * 3.5, 0.0, 1.0);

    // Blend the terminal text with the smoke
    vec3 finalColor = mix(baseColor.rgb, SMOKE_COLOR, smokePresence * 0.7);

    fragColor = vec4(finalColor, 1.0);
}
