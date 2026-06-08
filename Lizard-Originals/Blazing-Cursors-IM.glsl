#define DURATION 0.5
#define DRAW_THRESHOLD 1.5
#define HIDE_TRAILS_ON_THE_SAME_LINE false

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

    float outside =
        length(max(d, 0.0));

    float inside =
        min(max(d.x, d.y), 0.0);

    return outside + inside;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    #if !defined(WEB)
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
    #endif

    vec2 vu = normalizeCoord(fragCoord, 1.0);

    vec4 currentCursor = vec4(
        normalizeCoord(iCurrentCursor.xy, 1.0),
        normalizeCoord(iCurrentCursor.zw, 0.0)
    );

    vec4 previousCursor = vec4(
        normalizeCoord(iPreviousCursor.xy, 1.0),
        normalizeCoord(iPreviousCursor.zw, 0.0)
    );

    vec2 centerCC =
        getRectangleCenter(currentCursor);

    vec2 centerPC =
        getRectangleCenter(previousCursor);

    float lineLength =
        distance(centerCC, centerPC);

    float trailThreshold =
        DRAW_THRESHOLD * currentCursor.w;

    float progress =
        clamp(
            (iTime - iTimeCursorChange) / DURATION,
            0.0,
            1.0
        );

    float easedProgress =
        blend(progress);

    float safeLineLength =
        max(lineLength * easedProgress, 0.00001);

    float isFarEnough =
        step(trailThreshold, lineLength);

    float isOnSeparateLine =
        HIDE_TRAILS_ON_THE_SAME_LINE
        ? step(
            0.0001,
            abs(currentCursor.y - previousCursor.y)
          )
        : 1.0;

    float animationActive =
        isFarEnough
        * isOnSeparateLine
        * step(0.001, easedProgress);

    float vertexFactor =
        determineStartVertexFactor(
            currentCursor.xy,
            previousCursor.xy
        );

    float invertedVertexFactor =
        1.0 - vertexFactor;

    vec2 v0 = vec2(
        currentCursor.x +
        currentCursor.z * vertexFactor,

        currentCursor.y -
        currentCursor.w
    );

    vec2 v1 = vec2(
        currentCursor.x +
        currentCursor.z * invertedVertexFactor,

        currentCursor.y
    );

    vec2 v2 = vec2(
        previousCursor.x +
        previousCursor.z * invertedVertexFactor,

        previousCursor.y
    );

    vec2 v3 = vec2(
        previousCursor.x +
        previousCursor.z * vertexFactor,

        previousCursor.y -
        previousCursor.w
    );

    float sdfTrail =
        getSdfParallelogram(
            vu,
            v0,
            v1,
            v2,
            v3
        );

    float trailMask =
        1.0 -
        smoothstep(
            -0.01,
            0.001,
            sdfTrail
        );

    float distanceToEnd =
        distance(vu.xy, centerCC);

    float alphaModifier =
        clamp(
            distanceToEnd / safeLineLength,
            0.0,
            1.0
        );

    vec3 color = fragColor.rgb;

    float trailIntensity =
        (1.0 - alphaModifier)
        * trailMask
        * animationActive;

	color = mix(
		color,
		iCursorColor,
		trailIntensity * 0.35
	);
    color = mix(
        color,
        TRAIL_COLOR_ACCENT.rgb,
        trailIntensity
    );

    fragColor = vec4(color, 1.0);
}
