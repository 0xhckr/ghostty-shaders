import type { BlendMode } from "./types";

export function attributionHeader(
  name: string,
  author: string,
  shaderId: string
): string {
  return `// "${name}" by ${author}
// Source: https://www.shadertoy.com/view/${shaderId}
// Converted by shadertoy2ghostty`;
}

export function proceduralNoiseGLSL(): string {
  return `
// --- Procedural noise (replaces texture lookups) ---
float _hash(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

float _valueNoise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = _hash(i);
    float b = _hash(i + vec2(1.0, 0.0));
    float c = _hash(i + vec2(0.0, 1.0));
    float d = _hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

vec4 proceduralNoise(vec2 uv) {
    float n1 = _valueNoise(uv * 64.0);
    float n2 = _valueNoise(uv * 64.0 + vec2(17.0, 31.0));
    float n3 = _valueNoise(uv * 64.0 + vec2(59.0, 83.0));
    float n4 = _valueNoise(uv * 64.0 + vec2(43.0, 67.0));
    return vec4(n1, n2, n3, n4);
}
// --- End procedural noise ---
`;
}

export function blendingCode(mode: BlendMode): string {
  switch (mode) {
    case "replace":
      return "";

    case "overlay":
      return `
    // --- Terminal blending (overlay) ---
    vec2 _termUV = fragCoord.xy / iResolution.xy;
    vec4 _terminalColor = texture(iChannel0, _termUV);
    float _mask = 1.0 - step(0.5, dot(_terminalColor.rgb, vec3(1.0)));
    vec3 _blendedColor = mix(_terminalColor.rgb, fragColor.rgb, _mask);
    fragColor = vec4(_blendedColor, _terminalColor.a);`;

    case "additive":
      return `
    // --- Terminal blending (additive) ---
    vec2 _termUV = fragCoord.xy / iResolution.xy;
    vec4 _terminalColor = texture(iChannel0, _termUV);
    fragColor = vec4(_terminalColor.rgb + fragColor.rgb, _terminalColor.a);`;

    case "multiply":
      return `
    // --- Terminal blending (multiply) ---
    vec2 _termUV = fragCoord.xy / iResolution.xy;
    vec4 _terminalColor = texture(iChannel0, _termUV);
    fragColor = vec4(_terminalColor.rgb * fragColor.rgb, _terminalColor.a);`;
  }
}
