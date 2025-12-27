#define TAU 6.28318530718
#define MAX_ITER 6

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float time = iTime * 0.8 + 23.0; // Faster time multiplier
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    vec2 center = uv - 0.5;
    float angle = atan(center.y, center.x);
    float radius = length(center);
    
    vec2 p = mod(uv*TAU, TAU)-250.0;
    vec2 i = vec2(p);
    float c = 1.0;
    float inten = 0.005;

    for (int n = 0; n < MAX_ITER; n++) {
        float t = time * (1.0 - (3.5/float(n+1)));
        i = p + vec2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        c += 1.0/length(vec2(p.x/(sin(i.x+t)/inten), p.y/(cos(i.y+t)/inten)));
    }
    c /= float(MAX_ITER);
    c = 1.17 - pow(c, 1.4);
    
    float hue = fract(angle/TAU + time*0.5 + radius*1.5);
    vec3 rainbow = hsv2rgb(vec3(hue, 0.9, 1.0));
    
    float intensity = pow(abs(c), 10.0) * 2.0;
    vec3 color = rainbow * intensity;
    color = clamp(color, 0.0, 1.0);

    vec2 tc = vec2(cos(c)-0.75, sin(c)-0.75) * 0.04;
    uv = clamp(uv + tc, 0.0, 1.0);

    fragColor = texture(iChannel0, uv);
    if (fragColor.a == 0.0) fragColor = vec4(1.0);
    fragColor *= vec4(color, 1.0);
}
