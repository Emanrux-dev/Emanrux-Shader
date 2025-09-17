// from https://www.shadertoy.com/view/XtGGRt, edited

// Auroras by nimitz 2017 (twitter: @stormoid)
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
// Contact the author for other licensing options

/*
	
	There are two main hurdles I encountered rendering this effect. 
	First, the nature of the texture that needs to be generated to get a believable effect
	needs to be very specific, with large scale band-like structures, small scale non-smooth variations
	to create the trail-like effect, a method for animating said texture smoothly and finally doing all
	of this cheaply enough to be able to evaluate it several times per fragment/pixel.

	The second obstacle is the need to render a large volume while keeping the computational cost low.
	Since the effect requires the trails to extend way up in the atmosphere to look good, this means
	that the evaluated volume cannot be as constrained as with cloud effects. My solution was to make
	the sample stride increase polynomially, which works very well as long as the trails are lower opcaity than
	the rest of the effect. Which is always the case for auroras.

	After that, there were some issues with getting the correct emission curves and removing banding at lowered
	sample densities, this was fixed by a combination of sample number influenced dithering and slight sample blending.

	N.B. the base setup is from an old shader and ideally the effect would take an arbitrary ray origin and
	direction. But this was not required for this demo and would be trivial to fix.
*/

float hash_aurora(float p)
{
	p = fract(p * .1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

mat2 mm2(in float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

const mat2 m2 = mat2(0.95534, 0.29552, -0.29552, 0.95534);

float tri(in float x) {
    return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}

vec2 tri2(in vec2 p) {
    float triX = tri(p.x);
    float triY = tri(p.y);
    return vec2(triX + triY, tri(triX + p.y));
}

float triNoise2d(in vec2 p) {
    float z = 1.8;
    float z2 = 2.5;
    float rz = 0.0;
    p *= mm2(p.x * 0.06);
    vec2 bp = p;
    mat2 rotation = mm2(frameTimeCounter * 0.06);
    
    for (int i = 0; i < 3; i++) {
        vec2 dg = tri2(bp * 1.75) * 0.75;
        dg *= rotation;
        p -= dg / z2;

        bp *= 1.3;
        z2 *= 0.45;
        z *= 0.42;
        p *= 1.21 + (rz - 1.0) * 0.02;
        
        rz += tri(p.x + tri(p.y)) * z;
        p *= -m2;
    }
    return clamp(1.0 / pow(rz * 29.0, 1.6), 0.0, 0.55);
}

vec3 aurora(vec3 dir, int samples, float noise, float WmoonVecY, float WsunVecY) {
    vec3 col = vec3(0.0);
    vec3 avgCol = vec3(0.0);
    float hash = 0.05 * noise;
    float fade = dir.y * 2.0 + 0.4;

    float atmosphereGround = 1.0 - exp2(-50.0 * pow(clamp(dir.y+0.025,0.0,1.0),2.0));

    #ifdef LUT
        float mult = 6.0;
    #else
        float mult = 3.0;
    #endif
    
    for (int i = 0; i < samples; i++) {
        float mI = mult * float(i);
        float of = hash * smoothstep(0.0, 12.0, mI);
        float pt = (0.8 + pow(mI, 1.4) * 0.0016) / fade - of;
        vec3 bpos = pt * dir;
        float rzt = triNoise2d(bpos.zx);
        vec3 col2 = vec3(0.0, 0.0, 0.0);
        col2 = (sin(vec3(AURORA_R, AURORA_G, AURORA_B) + mI * 0.063) * 0.5 + 0.5) * rzt;
        avgCol = mix(avgCol, col2, 0.1);
        col += avgCol * exp2(-mI * 0.05 - 2.5);
    }

    vec3 auroraCol = 14.5*pow(col, vec3(1.45));

    #ifdef AURORA_MOON
        auroraCol *= smoothstep(0.1, 0.0, WmoonVecY);
    #endif

    auroraCol *= smoothstep(0.0, -0.1, WsunVecY);

    return auroraCol * atmosphereGround * auroraAmount * AURORA_BRIGHTNESS;
}
