// Spotlight that follows the terminal caret (cursor) with correct bright-in/dark-out
// Fix: bright inside circle (=1.0), darkened outside by AMBIENT_LIGHT; fallback to random wander when no cursor

// ---------- Parameters ----------
const float SPOTLIGHT_RADIUS = 0.25;   // Radius (normalized distance based on short edge)
const float EDGE_WIDTH       = 0.020;  // Edge transition width (0.01~0.04 for more natural effect)
const float AMBIENT_LIGHT    = 0.50;   // Minimum brightness outside circle (0=pure black, 1=no darkening)
const float FOLLOW_DURATION  = 0.18;   // Follow transition duration (seconds)
// --------------------------

float easeOutExpo(float t) {
    return (t <= 0.0) ? 0.0 : 1.0 - pow(2.0, -10.0 * t);
}

vec2 fallbackWanderCenter() {
    float t = iTime;
    return vec2(
        0.5 + 0.4 * sin(t * 1.0 + 0.0),
        0.5 + 0.4 * sin(t * 1.3 + 3.14159265)
    );
}

// Note: cursor rect in repo defines y as "top edge" → center y = y - h/2
vec2 rectCenterPx(vec4 r) { return vec2(r.x + 0.5*r.z, r.y - 0.5*r.w); }

// Returns UV center (0..1), or vec2(-1) if invalid
vec2 cursorCenterUV_smooth() {
    vec4 cur = iCurrentCursor;
    vec4 prv = iPreviousCursor;
    bool usable = (cur.z > 0.0 && cur.w > 0.0);
    if (!usable) return vec2(-1.0);

    vec2 c0 = rectCenterPx(prv) / iResolution.xy;
    vec2 c1 = rectCenterPx(cur) / iResolution.xy;

    float t = clamp((iTime - iTimeCursorChange) / FOLLOW_DURATION, 0.0, 1.0);
    float k = easeOutExpo(t);
    vec2 c = mix(c0, c1, k);
    return clamp(c, vec2(0.0), vec2(1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 tex = texture(iChannel0, uv);

    // Calculate center: prioritize cursor, otherwise random wander
    vec2 center = cursorCenterUV_smooth();
    if (center.x < 0.0) {
        center = fallbackWanderCenter();
    }

    // "Circular distance" after aspect ratio correction
    vec2 ratio = vec2(iResolution.x / iResolution.y, 1.0);
    float d = length((uv - center) * ratio);

    // Key fix: use canonical smoothstep order to get "inside circle mask" (center=1, outside=0)
    // maskInside = 1 - smoothstep(R, R+W, d)
    float maskInside = 1.0 - smoothstep(SPOTLIGHT_RADIUS, SPOTLIGHT_RADIUS + EDGE_WIDTH, d);

    // Brightness: inside circle=1.0, outside=AMBIENT_LIGHT
    float brightness = mix(AMBIENT_LIGHT, 1.0, maskInside);

    fragColor = vec4(tex.rgb * brightness, tex.a);
}
