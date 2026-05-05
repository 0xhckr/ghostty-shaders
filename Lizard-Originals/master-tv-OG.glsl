//\\Master-TV Shader for Ghostty//\\
   \\Written by GrangBIRDLizard// 	

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
   	vec2 uv = fragCoord / iResolution.xy;
    float t = iTime;

    // (Turn-On Animation)
    // Old tube tv turning on.
    float vPinch = smoothstep(0.0, 0.2, t);   // Opens vertically 0.0-0.2s
    float hPinch = smoothstep(0.1, 0.4, t);   // Opens horizontally 0.1-0.4s
    
    vec2 pinchedUV = uv;
    pinchedUV.y = (pinchedUV.y - 0.5) / max(vPinch, 0.001) + 0.5;
    pinchedUV.x = (pinchedUV.x - 0.5) / max(hPinch, 0.001) + 0.5;

    // 2.(Barrel Distortion)
    // Warps the coordinates to look like a glass bulb
    vec2 warpedUV = pinchedUV * 2.0 - 1.0;
    warpedUV *= 1.0 + pow(length(warpedUV) * 0.18, 2.0); // Adjust 0.22 for "curviness"
    warpedUV = (warpedUV + 1.0) / 2.0;

    // 3. SAMPLING & BOUNDS
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    if (warpedUV.x >= 0.0 && warpedUV.x <= 1.0 && warpedUV.y >= 0.0 && warpedUV.y <= 1.0) {
        color = texture(iChannel0, warpedUV);
    }

	// 4. SOFT SCANLINES (Anti-aliased)
    //  I used a high frequency but a much lower intensity to stop the 'strobe'
    // 'iResolution.y * 1.0' ensures one line per physical pixel row roughly
    float scanlineValue = warpedUV.y * iResolution.y;
    
    // Instead of a raw sin, we use a smoothed sine wave to prevent moiré
    float scanline = 0.04 * sin(scanlineValue * 1.5); // Dropped from 0.1 to 0.04
    
    // 5. THE "SHADOW MASK" (The fix for the circles)
    // Adding a subtle horizontal 'grille' breaks up the moiré patterns
    float mask = 0.02 * sin(warpedUV.x * iResolution.x * 0.8);
    
    color.rgb -= scanline;
    color.rgb -= mask;

    // 6. STEADY LUMINESCENCE (No more strobe)
    // I replaced the aggressive flicker seen in CRt shaders with a  
	// frequency 'grain', This makes the screen feel 'analog' 
	// without making your eyes bleed.
    float grain = (fract(sin(dot(warpedUV + t, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.015;
    color.rgb += grain;

    fragColor = color;
}
