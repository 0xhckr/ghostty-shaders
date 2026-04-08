// Created by Paul Robello
// Modified to track terminal cursor position

const float SPOTLIGHT_RADIUS = 0.25;
const float EDGE_SOFTNESS    = 0.05;
const float AMBIENT_LIGHT    = 0.5;
const float FOLLOW_SPEED     = 0.15;

vec2 cursorCenterUV() {
    vec4 cur = iCurrentCursor;
    vec4 prv = iPreviousCursor;
    if (cur.z <= 0.0 || cur.w <= 0.0)
        return vec2(0.5);

    vec2 c0 = vec2(prv.x + 0.5 * prv.z, prv.y - 0.5 * prv.w) / iResolution.xy;
    vec2 c1 = vec2(cur.x + 0.5 * cur.z, cur.y - 0.5 * cur.w) / iResolution.xy;

    float t = clamp((iTime - iTimeCursorChange) / FOLLOW_SPEED, 0.0, 1.0);
    return mix(c0, c1, t);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 ratio = vec2(iResolution.x / iResolution.y, 1.0);

    vec4 texColor = texture(iChannel0, uv);

    vec2 spotlightCenter = cursorCenterUV();
    float distanceToCenter = length((uv - spotlightCenter) * ratio);

    float spotlightIntensity = 1.0 - smoothstep(SPOTLIGHT_RADIUS, SPOTLIGHT_RADIUS + EDGE_SOFTNESS, distanceToCenter);

    vec3 spotlightEffect = texColor.rgb * mix(vec3(AMBIENT_LIGHT), vec3(1.0), spotlightIntensity);

    fragColor = vec4(spotlightEffect, texColor.a);
}