// Reactive-Cursor Written by GrandBIRDLizard 
// For use with and optimized for Ghostty 1.3.x+
// BSD-3-Clause ALL RIGHTS RESERVED  

#define DURATION 0.5
#define DRAW_THRESHOLD 1.5
#define HIDE_TRAILS_ON_THE_SAME_LINE 0 // Use 1 to hide, 0 to show

// Toggle Switches (GLSL compliance)
#define ENABLE_TRAIL 1
#define ENABLE_PULSE 1

// Pulse Settings
#define PULSE_DURATION 0.35
#define PULSE_MAX_RADIUS 0.06
#define PULSE_THICKNESS 0.008

const vec4 TRAIL_COLOR_ACCENT = vec4(0.45, 0.20, 0.75, 1.0);

vec2 normalizeCoord(vec2 coord, float includeAspect)
{
    vec2 result = coord / iResolution.xy;

    if (includeAspect > 0.5)
    {
        result.x *= iResolution.x / iResolution.y;
    }

    return result;
}

float blend(float t)
{
    return pow(1.0 - t, 10.0);
}

float easeOutSine(float t)
{
    return sin(t * 1.5707963);
}

vec2 getRectangleCenter(vec4 rect)
{
    return rect.xy + vec2(rect.z * 0.5, -rect.w * 0.5);
}

float determineStartVertexFactor(vec2 current, vec2 previous)
{
    return step(previous.x, current.x);
}

float getSdfParallelogram(
    vec2 p,
    vec2 v0,
    vec2 v1,
    vec2 v2,
    vec2 v3
)
{
    vec2 e0 = v1 - v0;
    vec2 e1 = v3 - v0;

    vec2 q = p - v0;

    mat2 basis = mat2(e0, e1);

    vec2 uv = inverse(basis) * q;

    vec2 d = abs(uv - 0.5) - 0.5;

    float outside = length(max(d, 0.0));
    float inside  = min(max(d.x, d.y), 0.0);

    return outside + inside;
}

// Hollow Rectangle SDF
float getSdfRectRing(vec2 p, vec2 center, vec2 halfSize, float thickness)
{
    vec2 d = abs(p - center) - halfSize;
    float outsideSdf = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    return abs(outsideSdf) - thickness * 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec4 baseTex = texture(iChannel0, fragCoord / iResolution.xy);
    vec3 finalColor = baseTex.rgb;
    float originalAlpha = baseTex.a;

    vec2 vu = normalizeCoord(fragCoord, 1.0);

    vec4 currentCursor = vec4(
        normalizeCoord(iCurrentCursor.xy, 1.0),
        normalizeCoord(iCurrentCursor.zw, 0.0)
    );
    vec4 previousCursor = vec4(
        normalizeCoord(iPreviousCursor.xy, 1.0),
        normalizeCoord(iPreviousCursor.zw, 0.0)
    );

    vec2 centerCC = getRectangleCenter(currentCursor);
    vec2 centerPC = getRectangleCenter(previousCursor);

    float lineLength = distance(centerCC, centerPC);
    float trailThreshold = DRAW_THRESHOLD * currentCursor.w;

    float isFarEnough = step(trailThreshold, lineLength);
    
    #if HIDE_TRAILS_ON_THE_SAME_LINE == 1
    float isOnSeparateLine = step(0.0001, abs(currentCursor.y - previousCursor.y));
    #else
    float isOnSeparateLine = 1.0;
    #endif

    //  TRAIL
    #if ENABLE_TRAIL == 1
    float trailProgress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    float easedTrailProgress = blend(trailProgress);
    float safeLineLength = max(lineLength * easedTrailProgress, 0.00001);

    float trailActive = isFarEnough * isOnSeparateLine * step(0.001, easedTrailProgress);

    float vertexFactor = determineStartVertexFactor(currentCursor.xy, previousCursor.xy);
    float invertedVertexFactor = 1.0 - vertexFactor;

    vec2 v0 = vec2(currentCursor.x + currentCursor.z * vertexFactor,         currentCursor.y - currentCursor.w);
    vec2 v1 = vec2(currentCursor.x + currentCursor.z * invertedVertexFactor, currentCursor.y);
    vec2 v2 = vec2(previousCursor.x + previousCursor.z * invertedVertexFactor, previousCursor.y);
    vec2 v3 = vec2(previousCursor.x + previousCursor.z * vertexFactor,        previousCursor.y - previousCursor.w);

    float sdfTrail = getSdfParallelogram(vu, v0, v1, v2, v3);
    float trailMask = 1.0 - smoothstep(-0.01, 0.001, sdfTrail);

    float distanceToEnd = distance(vu.xy, centerCC);
    float alphaModifier = clamp(distanceToEnd / safeLineLength, 0.0, 1.0);

    float trailIntensity = (1.0 - alphaModifier) * trailMask * trailActive;

    finalColor = mix(finalColor, iCursorColor.rgb, trailIntensity * 0.35);
    finalColor = mix(finalColor, TRAIL_COLOR_ACCENT.rgb, trailIntensity);
    #endif

    // RECTANGLE PULSE
    #if ENABLE_PULSE == 1
    float pulseProgress = clamp((iTime - iTimeCursorChange) / PULSE_DURATION, 0.0, 1.0);
    float pulseActive = isFarEnough * isOnSeparateLine * step(pulseProgress, 0.999);
    float pulseFade = 1.0 - pulseProgress;
    
    float expansionFactor = easeOutSine(pulseProgress) * PULSE_MAX_RADIUS;

    vec2 currentHalfBounds = vec2(currentCursor.z, currentCursor.w) * 0.5;

    float isBar = step(currentCursor.z / currentCursor.w, 0.25); 
   
    float isUnderline = step(iCurrentCursor.w / iCurrentCursor.z, 0.25);
 
    vec2 expansionDirection = vec2(1.0, 1.0);
    expansionDirection = mix(expansionDirection, vec2(1.0, 0.2), isUnderline);
    expansionDirection = mix(expansionDirection, vec2(0.2, 1.0), isBar);

    // Form Final Profile
    vec2 animatedHalfBounds = currentHalfBounds + (vec2(expansionFactor) * expansionDirection);

    float sdfRect = getSdfRectRing(vu, centerCC, animatedHalfBounds, PULSE_THICKNESS);

    float pulseMask = 1.0 - smoothstep(-0.01, 0.001, sdfRect);
    float pulseIntensity = pulseMask * pulseFade * pulseActive;

    finalColor = mix(finalColor, TRAIL_COLOR_ACCENT.rgb, pulseIntensity * 0.80);
    #endif

    fragColor = vec4(finalColor, originalAlpha);
}
