float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Terminal pixel
    vec3 termCol = texture(iChannel0, uv).rgb;
    float termLum = dot(termCol, vec3(0.299, 0.587, 0.114));

    // === Matrix rain -- procedural glyphs falling in long ribbons ===
    float colW = 12.0;
    float chH  = 16.0;
    vec2 grid       = vec2(iResolution.x / colW, iResolution.y / chH);
    vec2 cell       = floor(uv * grid);
    vec2 cellLocal  = fract(uv * grid);

    // Per-column random parameters -- everything varies between columns
    float colSeed1 = hash(vec2(cell.x,  7.0));
    float colSeed2 = hash(vec2(cell.x, 31.0));
    float colSeed3 = hash(vec2(cell.x, 53.0));
    float colSeed4 = hash(vec2(cell.x, 79.0));

    // Per-column GLYPH SIZE -- some columns use a finer pixel grid (smaller
    // glyphs), others a coarser one (bigger, chunkier glyphs).
    vec2 glyphRes = mix(vec2(3.0, 5.0), vec2(6.0, 8.0), colSeed4);
    vec2 glyphPix = floor(cellLocal * glyphRes);

    // Per-column glyph FILL DENSITY -- some columns thin/wispy, some fat/solid
    float fillThreshold = mix(0.40, 0.70, colSeed3);

    // Per-column glyph MUTATION RATE
    float glyphRate  = 4.0 + colSeed2 * 8.0;
    float glyphFrame = floor(iTime * glyphRate + cell.y * 0.4);
    float glyphId    = hash(cell + glyphFrame * 7.13);
    float pixelOn    = step(fillThreshold, hash(glyphPix + glyphId * 117.0));

    // Inner padding so glyphs don't touch
    float pad = step(0.08, cellLocal.x) * step(cellLocal.x, 0.92)
              * step(0.08, cellLocal.y) * step(cellLocal.y, 0.92);
    pixelOn *= pad;

    // Fully dense -- every column is active
    float colActive = 1.0;

    // Per-column SPEED -- wide range, some drift, some race
    float speed  = 0.25 + colSeed1 * 1.8;

    // Per-column TRAIL LENGTH -- huge range, from short bursts to long ribbons
    float trail  = 6.0 + colSeed2 * 40.0;

    // Per-column tail FADE RATE -- some fade fast, some linger forever
    float fadeRate = mix(0.08, 0.32, colSeed3);

    float offset  = colSeed1 * 200.0;

    float t       = iTime * speed * 6.0 + offset;
    float headRow = mod(t, grid.y + trail + 8.0);

    // uv.y=0 at top -- head falls DOWN
    float dist = headRow - cell.y;

    // Tail brightness with per-column fade rate
    float bright = 0.0;
    if (dist >= 0.0) {
        bright = exp(-dist * fadeRate);
    }

    // Sharp head pulse
    float head = exp(-dist * dist * 2.5) * step(-0.5, dist) * step(dist, 1.5);

    // Per-column DIMNESS -- huge range, many columns barely visible
    float colIntensity = mix(0.15, 1.0, colSeed4 * colSeed4);

    vec3 tailColor = vec3(0.0,  0.90, 0.22);
    vec3 headColor = vec3(0.85, 1.0,  0.92);

    vec3 rain = tailColor * bright * colIntensity;
    rain     += headColor * head   * colIntensity;

    rain *= pixelOn;
    rain *= colActive;

    // Master visibility -- faint, recessed
    rain *= 0.58;

    // Fade in from top
    rain *= smoothstep(0.0, 0.10, uv.y);

    // Composite -- additive but heavily suppressed where text exists
    vec3 col = termCol + rain * (1.0 - termLum * 0.95);

    // Soft bloom on terminal text (phosphor glow)
    vec3 bloom = vec3(0.0);
    bloom += texture(iChannel0, uv + vec2( 0.0022, 0.0)).rgb;
    bloom += texture(iChannel0, uv + vec2(-0.0022, 0.0)).rgb;
    bloom += texture(iChannel0, uv + vec2( 0.0,  0.0028)).rgb;
    bloom += texture(iChannel0, uv + vec2( 0.0, -0.0028)).rgb;
    bloom *= 0.25;
    col += bloom * 0.45 * vec3(0.0, 1.0, 0.25);

    // Scanlines (lighter than Pip-Boy -- Matrix is digital, not analog)
    float scan = sin(uv.y * iResolution.y * 1.6) * 0.5 + 0.5;
    col *= mix(0.9, 1.0, scan);

    // Vignette
    vec2 vu = uv - 0.5;
    float vig = 1.0 - dot(vu, vu) * 0.55;
    col *= clamp(vig, 0.0, 1.0);

    // Subtle flicker
    col *= 0.97 + 0.03 * sin(iTime * 7.0);

    // Faint grain
    float n = hash(fragCoord.xy + iTime);
    col += (n - 0.5) * 0.02;

    fragColor = vec4(col, 1.0);
}
