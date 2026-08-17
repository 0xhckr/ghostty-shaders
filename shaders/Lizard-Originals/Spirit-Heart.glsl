// GSIM shader collection for use with Ghostty 1.3.x+.
// Spirit-Heart Written by GrandBIRDLizard.
// Stage 1 Prototype
//
// Foundation implementation.
// Heart + Breathing Glow
//
// BSD-3-Clause-v2 (Modified - Name Attribution Required)

#define ENABLE_BREATHING 1

#define HEART_SCALE      0.24
#define HEART_Y_OFFSET   0.02

#define BREATH_SPEED     1.35
#define BREATH_STRENGTH  0.035

const vec3 HEART_CORE  = vec3(0.86,0.78,0.98);
const vec3 HEART_GLOW  = vec3(0.55,0.38,0.88);


// Hash
float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453);
}


// Smooth heart with soft bloom rendering.
float heartSDF(vec2 p)
{
    p /= HEART_SCALE;

    p.y += HEART_Y_OFFSET;

#if ENABLE_BREATHING

    float beat =
        pow(max(0.0,
            sin(iTime * BREATH_SPEED)), 6.0);

    p /= (1.0 + beat * BREATH_STRENGTH);

#endif

    p.y -= sqrt(abs(p.x))*0.52;

    return length(p)-0.55;
}


// Glow
float bloom(float d)
{
    return exp(-10.0 * abs(d));
}


// Heart Fill
float heartFill(float d)
{
    return smoothstep(0.01,-0.01,d);
}


//------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    if(iResolution.y==0.0)
        return;

    vec2 uv = fragCoord/iResolution.xy;

    float aspect = iResolution.x/iResolution.y;

    vec3 col = texture(iChannel0,uv).rgb;

    float lum =
        dot(col,
            vec3(.299,.587,.114));

    float darkMask =
        1.0-smoothstep(.05,.20,lum);

    //--------------------------------------------------------

    vec2 p = uv-0.5;

    p.x*=aspect;

    //--------------------------------------------------------

    float d = heartSDF(p);

    float glow = bloom(d);

    float fill = heartFill(d);

    //--------------------------------------------------------

    col += HEART_GLOW
        * glow
        * 0.30
        * darkMask;

    col += HEART_CORE
        * fill
        * 0.22
        * darkMask;

    //--------------------------------------------------------

    fragColor=vec4(col,1.0);
}
