//Original star code : https://www.shadertoy.com/view/Md2SR3 , optimised


//  1 out, 3 in...
float hash13(vec3 p3)
{
	p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

// Convert Noise2d() into a "star field" by stomping everthing below fThreshhold to zero.
float NoisyStarField( in vec3 vSamplePos, float fThreshhold )
{
    float StarVal = hash13( vSamplePos );
    StarVal = clamp(StarVal/(1.0 - fThreshhold) - fThreshhold/(1.0 - fThreshhold),0.0,1.0);

    return StarVal;
}

// Stabilize NoisyStarField() by only sampling at integer values.
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

// alternative star code from https://www.shadertoy.com/view/4sBXzG , edited

float hash12_alt(vec2 co) { return fract(sin(2.0*PI*fract(dot(co.xy, vec2(12.9898,78.233)))) * 43758.5453); }

float starTemp(float hash) {
    return hash * hash * hash * (19000.0 - 5500.0) + 5500.0;
}

float starplane(vec3 dir, out vec3 starColor) { 
    float scale = 1.0/600.0;

    // Project to a cube-map plane and scale with the resolution
    vec2 basePos = dir.xy * (0.4 / scale) / max(1e-3, abs(dir.z));
             	
	float color = 0.0;
    starColor = vec3(0.0);

	vec2 pos = floor(basePos);
    vec2 center = pos + vec2(0.5);
    float d = distance(basePos, center);    

    // Stabilize stars under motion by locking to a grid
    basePos = floor(basePos);

    if (hash12_alt(basePos.xy * scale) > 0.997) {
        float radius = 0.4;
        float brightness = exp(-(d*d)/(2.0*radius*radius));

        float r = hash12_alt(basePos.xy * 0.5);
        color = r * (0.3 * sin(1 * (r * 5.0) + r) + 0.7) * brightness;

        starColor = 2.0 * blackbody(starTemp(hash12_alt(center)));
    } 
	
    // Weight by the z-plane
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

float stars(vec3 viewPos, out vec3 starColor){
    #ifdef OLD_STARS
        starColor = vec3(1.0);
        float stars = max(1.0 - StableStarField(viewPos*300.0 , 0.99),0.0);
        return STARS_BRIGHTNESS * exp( stars  * -20.0 * (1.0/STARS_AMOUNT));
    #else
        float stars = max(1.0 - starbox(viewPos, starColor),0.0);
        return 75.0 * STARS_BRIGHTNESS * exp( stars  * -20.0 * (1.0/STARS_AMOUNT));
    #endif
}
