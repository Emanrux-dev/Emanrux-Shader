#ifndef STARS_GLSL
#define STARS_GLSL


float hash13(vec3 p3)
{
	p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float NoisyStarField( in vec3 vSamplePos, float fThreshhold )
{
    float StarVal = hash13( vSamplePos );
    StarVal = clamp(StarVal/(1.0 - fThreshhold) - fThreshhold/(1.0 - fThreshhold),0.0,1.0);

    return StarVal;
}

float StableStarField( in vec3 vSamplePos, float fThreshhold )
{
    // Linear interpolation between four samples.
    // Note: This approach has some visual artifacts.
    // There must be a better way to "anti alias" the star field.
    float fractX = fract( vSamplePos.x );
    float fractY = fract( vSamplePos.y );
    vec3 floorSample = floor( vSamplePos.xyz );

    float v1 = NoisyStarField( floorSample, fThreshhold);
    float v2 = NoisyStarField( floorSample + vec3( 0.0, 1.0, 0.0), fThreshhold );
    float v3 = NoisyStarField( floorSample + vec3( 1.0, 0.0, 0.0), fThreshhold );
    float v4 = NoisyStarField( floorSample + vec3( 1.0, 1.0, 0.0), fThreshhold );

    float StarVal =   v1 * ( 1.0 - fractX ) * ( 1.0 - fractY )
        			+ v2 * ( 1.0 - fractX ) * fractY
        			+ v3 * fractX * ( 1.0 - fractY )
        			+ v4 * fractX * fractY;

	return StarVal;
}

float hash12_alt(vec2 co) { return fract(sin(2.0*PI*fract(dot(co.xy, vec2(12.9898,78.233)))) * 43758.5453); }

float starTemp(float hash) {
    return hash * hash * hash * (19000.0 - 5500.0) + 5500.0;
}

float starplane(vec3 dir, out vec3 starColor) { 
    float scale = 1.0/600.0;

    vec2 basePos = dir.xy * (0.4 / scale) / max(1e-3, abs(dir.z));
             	
	float color = 0.0;
    starColor = vec3(0.0);

	vec2 pos = floor(basePos);
    vec2 center = pos + vec2(0.5);
    float d = distance(basePos, center);    
    vec2 localBasePos = basePos;

    basePos = floor(basePos);

    if (hash12_alt(basePos.xy * scale) > 0.997) {
        float radius = 0.4;
        float brightness = exp(-(d*d)/(2.0*radius*radius));

        float r = hash12_alt(basePos.xy * 0.5);
        float spikeGate = smoothstep(0.82, 1.0, r);
        vec2 starDelta = localBasePos - center;
        float crossSpike = (exp(-abs(starDelta.x) * 18.0) + exp(-abs(starDelta.y) * 18.0)) * exp(-d * 2.7);
        float diagonalSpike = (exp(-abs(starDelta.x + starDelta.y) * 14.0) + exp(-abs(starDelta.x - starDelta.y) * 14.0)) * exp(-d * 3.4);
        color = r * (0.3 * sin(1 * (r * 5.0) + r) + 0.7) * brightness;
        color += spikeGate * (crossSpike * 0.26 + diagonalSpike * 0.08);

        starColor = 2.0 * blackbody(starTemp(hash12_alt(center)));
    } 
	
    return color * pow(abs(dir.z), 2);
}

float starbox(vec3 dir, out vec3 starColor) {
    vec2 starPos = vec2(0.0);
    vec3 starColor1 = vec3(0.0);
    vec3 starColor2 = vec3(0.0);
    vec3 starColor3 = vec3(0.0);

    float color = starplane(dir.xyz, starColor1) + starplane(dir.yzx, starColor2) + starplane(dir.zxy, starColor3);
    starColor = starColor1 + starColor2 + starColor3;
	return sqrt(color);
}

#ifdef GALAXY_SKY
#ifndef GALAXY_TEX_UNIFORM
#define GALAXY_TEX_UNIFORM
uniform sampler2D galaxyTex;
#endif
#endif

void CalculateGalaxy(vec3 viewPos, out float galaxyBrightness, out vec3 galaxyColor) {
    vec3 dir = normalize(viewPos);
    
    float nightFactor = clamp(sunElevation * -10.0, 0.0, 1.0); // Simple night detection
    float rainFactor = clamp(1.0 - rainStrength, 0.0, 1.0);
    
    if(nightFactor * rainFactor < 0.001) {
        galaxyColor = vec3(0.0);
        galaxyBrightness = 0.0;
        return;
    }

    #ifdef GALAXY_SKY
        float a1 = 1.25;
        float a2 = 0.65;
        float s1 = sin(a1), c1 = cos(a1);
        float s2 = sin(a2), c2 = cos(a2);
        dir.xz *= mat2(c1, s1, -s1, c1);
        dir.xy *= mat2(c2, s2, -s2, c2);

        vec3 rdir = vec3(dir.x, dir.z, dir.y);
        vec2 uv = vec2(atan(rdir.z, rdir.x) / (2.0 * PI) + 0.5, acos(rdir.y) / PI);
        vec4 tex = texture2D(galaxyTex, uv);
        galaxyColor = pow(tex.rgb, vec3(1.1)) * 0.72;

        float luminance = dot(galaxyColor, vec3(0.2126, 0.7152, 0.0722));
        galaxyBrightness = luminance * tex.a * rainFactor * nightFactor * 0.52;
        galaxyBrightness = smoothstep(0.0, 1.0, galaxyBrightness);
        galaxyBrightness = pow(galaxyBrightness, 1.1);
    #else
        galaxyColor = vec3(0.0);
        galaxyBrightness = 0.0;
    #endif
}

float stars(vec3 viewPos, out vec3 starColor){
    #ifdef GALAXY_SKY
    float gBright = 0.0;
    vec3 gCol = vec3(0.0);
    CalculateGalaxy(viewPos, gBright, gCol);
    #endif

    #ifdef OLD_STARS
        starColor = vec3(1.0);
        float stars = max(1.0 - StableStarField(viewPos*300.0 , 0.99),0.0);
        float starVal = STARS_BRIGHTNESS * exp( stars  * -20.0 * (1.0/STARS_AMOUNT));
    #else
        float stars = max(1.0 - starbox(viewPos, starColor),0.0);
        float starVal = 75.0 * STARS_BRIGHTNESS * exp( stars  * -20.0 * (1.0/STARS_AMOUNT));
    #endif

    #ifdef GALAXY_SKY
    float totalVal = starVal + gBright * 0.32;
    starColor = (starColor * starVal + gCol * gBright * 0.46) / max(totalVal, 1e-6);
    return totalVal;
    #else
    return starVal;
    #endif
}

#endif
