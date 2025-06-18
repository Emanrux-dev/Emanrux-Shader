// RIPPLE CODE FROM https://www.shadertoy.com/view/ldfyzl

/*

A quick experiment with rain drop ripples.

This effect was written for and used in the launch scene of the
64kB PC intro "H - Immersion", by Ctrl-Alt-Test.

 > http://www.ctrl-alt-test.fr/productions/h-immersion/
 > https://www.youtube.com/watch?v=27PN1SsXbjM

-- 
Zavie / Ctrl-Alt-Test

*/

// Return random noise in the range [0.0, 1.0], as a function of x.
float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+19.19);
    return fract((p3.xx+p3.yz)*p3.zy);

}

vec3 ripples(vec2 fragCoord) {
    float cell_density = 5 * RIPPLE_INTENSITY;

    float size_compensation = cell_density / 5.0;
    
    vec2 uv = fragCoord * cell_density;
    vec2 p0 = floor(uv);

    int MAX_RADIUS = 1;

	float wave_frequency = 21;

    vec2 circles = vec2(0.);
    for (int j = -MAX_RADIUS; j <= MAX_RADIUS; ++j) {
        for (int i = -MAX_RADIUS; i <= MAX_RADIUS; ++i) {
            vec2 pi = p0 + vec2(i, j);
            
            vec2 hsh = pi;
            
            vec2 p = pi + hash22(hsh);

            float t = fract(0.9 * frameTimeCounter + hash12(hsh));
            vec2 v = p - uv;
            
            float d = length(v) - ( (float(MAX_RADIUS) + 1.) * t ) * size_compensation;

            float h = 1e-2;
            float d1 = d - h;
            float d2 = d + h;
            float p1 = sin(wave_frequency*d1) * smoothstep(-0.6, -0.3, d1) * smoothstep(0., -0.3, d1);
            float p2 = sin(wave_frequency*d2) * smoothstep(-0.6, -0.3, d2) * smoothstep(0., -0.3, d2);
            circles += 0.5 * normalize(v) * ((p2 - p1) / (2. * h) * (1. - t) * (1. - t));
        }
    }
    circles /= float((MAX_RADIUS*2+1)*(MAX_RADIUS*2+1));

    vec3 n = vec3(circles, sqrt(1.0 - dot(circles, circles)));
    return n;
}