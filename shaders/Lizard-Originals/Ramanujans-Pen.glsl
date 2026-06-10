// GSIM shader collection for use with Ghostty 1.3.x+
// Ramanujans-Pen Written by GrandBIRDLizard
// Optimized with Space-Folding Smear Architectures 
// BSD-3-Clause-v2 (Modified - Name Attribution Required)  

//Copyright (c) 2026 GrandBIRDLizard
//ALL rights reserved.

#define DURATION 0.5
#define DRAW_THRESHOLD 1.5
#define HIDE_TRAILS_ON_THE_SAME_LINE 0 // Use 1 to hide, 0 to show


// Toggle Switches (1/0 for GLSL)
#define ENABLE_TRAIL 1
#define ENABLE_PULSE 1

// SMEAR ARCHITECTURE SETTINGS

// SMEAR_STYLE:
// 0 = Smooth Ramp (Continuous dynamic thickness)
// 1 = Block Ramp (Quantized distinct blocks)
// 2 = Pulse Blocks (Blocks scaling to a rhythmic wave)
// 3 = Pulse Circles (Circles scaling to a rhythmic wave)
#define SMEAR_STYLE 2

// SMEAR_REVERSE:
// 0 = Small -> Large (Tail is thin, Head is thick)
// 1 = Large -> Small (Tail is thick, Head is thin)
#define SMEAR_REVERSE 0

// Modifiers:
#define SMEAR_STEPS 10.0      // Amount of chunks for styles 1, 2, and 3
#define SMEAR_MIN_SIZE 0.15   // Trail starting scale
#define SMEAR_MAX_SIZE 1.2    // Trail ending scale
#define PULSE_COUNT 4.0       // Number of pulses active (Styles 2 & 3)
#define PULSE_SPEED 15.0      // Speed of the pulse wave (Styles 2 & 3)

// Pulse Settings (End-Animation)
#define PULSE_DURATION 0.35
#define PULSE_MAX_RADIUS 0.06
#define PULSE_THICKNESS 0.008

const vec4 TRAIL_COLOR_ACCENT = vec4(0.45, 0.20, 0.75, 1.0);

vec2 normalizeCoord(vec2 coord, float includeAspect) {
    vec2 result = coord / iResolution.xy;
    if (includeAspect > 0.5) {
        result.x *= iResolution.x / iResolution.y;
    }
    return result;
}

float blend(float t) {
    return pow(1.0 - t, 10.0);
}

float easeOutSine(float t) {
    return sin(t * 1.5707963);
}

vec2 getRectangleCenter(vec4 rect) {
    return rect.xy + vec2(rect.z * 0.5, -rect.w * 0.5);
}

// Hollow Rectangle SDF  End-Point Pulse
float getSdfRectRing(vec2 p, vec2 center, vec2 halfSize, float thickness) {
    vec2 d = abs(p - center) - halfSize;
    float outsideSdf = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    return abs(outsideSdf) - thickness * 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
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


    //  Dynamic Smear Trail
    #if ENABLE_TRAIL == 1
        float trailProgress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
        float easedTrailProgress = blend(trailProgress);
        float safeLineLength = max(lineLength * easedTrailProgress, 0.00001);

        float trailActive = isFarEnough * isOnSeparateLine * step(0.001, easedTrailProgress);

        //  Projection 'h' along the segment [0.0 (Tail) -> 1.0 (Head)]
        vec2 pa = vu - centerPC;
        vec2 ba = centerCC - centerPC;
        float ba2 = dot(ba, ba) + 1e-6;  // Epsilon prevents division by zero
        float h = clamp(dot(pa, ba) / ba2, 0.0, 1.0);

        // Logic for Reversal direction (Zero runtime cost)
        #if SMEAR_REVERSE == 1
            float h_dir = 1.0 - h;
        #else
            float h_dir = h;
        #endif

        // Topology Generator (Branchless Evaluation)
        float sdfTrail;
        
        #if SMEAR_STYLE == 0
            // Smooth Ramp 
            float r = mix(SMEAR_MIN_SIZE, SMEAR_MAX_SIZE, h_dir);
            vec2 currentCenter = centerPC + ba * h;
            
            vec2 dynamicHalfBounds = vec2(currentCursor.z, currentCursor.w) * 0.5 * r;
            vec2 d_rect = abs(vu - currentCenter) - dynamicHalfBounds;
            sdfTrail = length(max(d_rect, 0.0)) + min(max(d_rect.x, d_rect.y), 0.0);

        #else
            // Styles(1,2,3) Quantized Snapping (Domain Repetition)
            float h_snapped = clamp(floor(h * SMEAR_STEPS + 0.5) / SMEAR_STEPS, 0.0, 1.0);
            
            #if SMEAR_REVERSE == 1
                float h_snapped_dir = 1.0 - h_snapped;
            #else
                float h_snapped_dir = h_snapped;
            #endif

            vec2 currentCenter = centerPC + ba * h_snapped;

            #if SMEAR_STYLE == 1
                // Block Ramp
                float r = mix(SMEAR_MIN_SIZE, SMEAR_MAX_SIZE, h_snapped_dir);
                vec2 dynamicHalfBounds = vec2(currentCursor.z, currentCursor.w) * 0.5 * r;
                vec2 d_rect = abs(vu - currentCenter) - dynamicHalfBounds;
                sdfTrail = length(max(d_rect, 0.0)) + min(max(d_rect.x, d_rect.y), 0.0);

            #elif SMEAR_STYLE == 2
                // Pulse Block
                float pulse = sin(h_snapped * 3.14159 * PULSE_COUNT - iTime * PULSE_SPEED) * 0.5 + 0.5;
                float r = mix(SMEAR_MIN_SIZE, SMEAR_MAX_SIZE, h_snapped_dir) * pulse;
                vec2 dynamicHalfBounds = vec2(currentCursor.z, currentCursor.w) * 0.5 * r;
                vec2 d_rect = abs(vu - currentCenter) - dynamicHalfBounds;
                sdfTrail = length(max(d_rect, 0.0)) + min(max(d_rect.x, d_rect.y), 0.0);

            #elif SMEAR_STYLE == 3
                // Pulse Circle
                float pulse = sin(h_snapped * 3.14159 * PULSE_COUNT - iTime * PULSE_SPEED) * 0.5 + 0.5;
                float r = mix(SMEAR_MIN_SIZE, SMEAR_MAX_SIZE, h_snapped_dir) * pulse;
                float baseRadius = max(currentCursor.z, currentCursor.w) * 0.5;
                sdfTrail = length(vu - currentCenter) - (baseRadius * r * 1.5);
            #endif
        #endif

        // 4. Alpha Compositing (Smooth backround into one trail color)
        float trailMask = 1.0 - smoothstep(-0.01, 0.001, sdfTrail);
        float distanceToEnd = distance(vu, centerCC);
        float alphaModifier = clamp(distanceToEnd / safeLineLength, 0.0, 1.0);
        float trailIntensity = (1.0 - alphaModifier) * trailMask * trailActive;

        finalColor = mix(finalColor, iCursorColor.rgb, trailIntensity * 0.35);
        finalColor = mix(finalColor, TRAIL_COLOR_ACCENT.rgb, trailIntensity);
    #endif


    // Rectangle Pulse (End-Animation)
    #if ENABLE_PULSE == 1
        float pulseProgress = clamp((iTime - iTimeCursorChange) / PULSE_DURATION, 0.0, 1.0);
        float pulseActive = isFarEnough * isOnSeparateLine * step(pulseProgress, 0.999);
        float pulseFade = 1.0 - pulseProgress;
        float expansionFactor = easeOutSine(pulseProgress) * PULSE_MAX_RADIUS;

        vec2 currentHalfBounds = vec2(currentCursor.z, currentCursor.w) * 0.5;

        float isBar = step(currentCursor.z / currentCursor.w, 0.25);
        float isUnderline = step(currentCursor.w / currentCursor.z, 0.25);
     
        vec2 expansionDirection = vec2(1.0, 1.0);
        expansionDirection = mix(expansionDirection, vec2(1.0, 0.2), isUnderline);
        expansionDirection = mix(expansionDirection, vec2(0.2, 1.0), isBar);

        vec2 animatedHalfBounds = currentHalfBounds + (vec2(expansionFactor) * expansionDirection);
        float sdfRect = getSdfRectRing(vu, centerCC, animatedHalfBounds, PULSE_THICKNESS);

        float pulseMask = 1.0 - smoothstep(-0.01, 0.001, sdfRect);
        float pulseIntensity = pulseMask * pulseFade * pulseActive;

        finalColor = mix(finalColor, TRAIL_COLOR_ACCENT.rgb, pulseIntensity * 0.80);
    #endif

    fragColor = vec4(finalColor, originalAlpha);
}

/*
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without prior written permission.

4. Any derivative works, modifications, or redistributions must maintain
   the original copyright notice and attribution to the original copyright
   holder in all source code files, documentation, and materials derived
   from this software. The original copyright holder's name and attribution
   may not be removed, obscured, or modified in any derivative work.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER "AS IS" AND ANY EXPRESS
OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/ 
