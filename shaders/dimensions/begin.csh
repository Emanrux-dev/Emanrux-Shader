#include "/lib/settings.glsl"
#include "/lib/SSBOs.glsl"
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#include "/lib/scene_controller.glsl"

uniform int worldDay;
uniform bool worldTimeChangeCheck;
uniform float frameTime;
uniform int frameCounter;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform float rainStrength;
uniform float thunderStrength;
uniform vec2 texelSize;
uniform float moonElevation;
uniform float sunElevation;
uniform float noPuddleAreas;
uniform float eyeAltitude;

uniform mat4 gbufferModelViewInverse;
uniform vec3 moonPosition;
uniform vec3 sunPosition;

uniform vec3 cameraPosition;

float hash11(float p)
{
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
vec3 rodSample(vec2 Xi)
{
	float r = sqrt(1.0 - Xi.x*Xi.y);
    float phi = 2.0 * 3.14159265359 * Xi.y;

    return normalize(vec3(cos(phi) * r, sin(phi) * r, Xi.x)).xzy;
}
//Low discrepancy 2D sequence, integration error is as low as sobol but easier to compute : http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * float(n));
}

#define interpolateValue(old_value, new_value, mixhistory) clamp(mix(old_value, new_value, clamp(mixhistory,0.0,1.0)),0.0,65000.)

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

#include "/lib/util.glsl"

#ifdef CUSTOM_MOON_ROTATION
    uniform mat4 shadowModelView;
    uniform int worldTime;
    uniform float worldTimeSmooth;
    // uniform float frameTimeCounter;
    uniform vec4 lightningBoltPosition;

    vec3 moonDirection(float worldTime, float latitude, float pathRotation) {
        float phi = radians(-latitude);
        float del = radians(pathRotation);
        
        float t = worldTime / 24000.0;

        t *= 1.0 + 1.0 / float(MONTH_LENGTH);

        float H = t * 2.0 * PI - PI; // hour angle
        
        float sin_h = sin(phi)*sin(del) + cos(phi)*cos(del)*cos(H);
        float h     = asin(sin_h); // height
        float cos_h = cos(h);
        
        float cosA = (sin(del) - sin(phi)*sin_h) / (cos(phi)*cos_h);

        cosA = clamp(cosA, -1.0, 1.0); // otherwise it bugs out...

        float A = acos(cosA);  // Azimuth
        if (sin(H) > 0.0) A = 2.0 * PI - A; // mirror onto other hemisphere

        return vec3(cos_h * sin(A), sin_h, cos_h * cos(A));
    }
#endif

#if (defined CUSTOM_MOON_ROTATION && defined OVERWORLD_SHADER) || (defined END_ISLAND_LIGHT && defined END_SHADER)
    #if defined END_ISLAND_LIGHT && defined END_SHADER
        const float NEAR = 15.0;
        const float FAR = 256.0;

        mat4 createPerspectiveMatrix() {
            float yScale = 1.0 / tan(radians(END_LIGHT_FOV) * 0.5);

            return mat4(
                    yScale, 0.0, 0.0, 0.0,
                    0.0, yScale, 0.0, 0.0,
                    0.0, 0.0, (FAR + NEAR) / (NEAR - FAR), -1.0,
                    0.0, 0.0, 2.0 * FAR * NEAR / (NEAR - FAR), 1.0
                );

        }
    #endif

    // these matrices are from old experiments with custom light directions from Xonk
    // thanks to Null for providing these to him

    mat4 BuildTranslationMatrix(vec3 delta) {
        return mat4(
            vec4(1.0, 0.0, 0.0, 0.0),
            vec4(0.0, 1.0, 0.0, 0.0),
            vec4(0.0, 0.0, 1.0, 0.0),
            vec4(delta,         1.0));
    }

    mat4 BuildShadowViewMatrix(vec3 localLightDir) {
        #if !defined CAELUM_SUPPORT && (!defined SMOOTH_SUN_ROTATION || (daySpeed >= 1.0 && nightSpeed >= 1.0 && defined SMOOTH_SUN_ROTATION))
            #ifdef OVERWORLD_SHADER
                #if LIGHTNING_SHADOWS > 1
                    if (sunElevation > 0.0 && lightningBoltPosition.w == 0.0) return shadowModelView;
                #else
                    if (sunElevation > 0.0) return shadowModelView;
                #endif
            #endif
        #endif

        vec3 worldUp = vec3(0.0, 1.0, 0.0);
        if (localLightDir == vec3(0.0, 1.0, 0.0)) worldUp = normalize(vec3(1.0, 0.0, 0.0));

        vec3 zaxis = localLightDir;

        vec3 xaxis = normalize(cross(worldUp, zaxis));
        vec3 yaxis = normalize(cross(zaxis, xaxis));

        mat4 shadowModelViewEx = mat4(1.0);
        shadowModelViewEx[0].xyz = vec3(xaxis.x, yaxis.x, zaxis.x);
        shadowModelViewEx[1].xyz = vec3(xaxis.y, yaxis.y, zaxis.y);
        shadowModelViewEx[2].xyz = vec3(xaxis.z, yaxis.z, zaxis.z);

        #ifdef OVERWORLD_SHADER
            vec3 intervalOffset = -100.0 * localLightDir;
        #else
            vec3 intervalOffset = (-vec3(END_LIGHT_POS) + cameraPosition);
        #endif
        mat4 translation = BuildTranslationMatrix(intervalOffset);
        
        return shadowModelViewEx * translation;
    }
#endif

#include "/lib/sky_gradient.glsl"
#include "/lib/ROBOBO_sky.glsl"

void main() {
    #if defined SMOOTH_SUN_ROTATION && (daySpeed < 1.0 || nightSpeed < 1.0)
        vec3 WsunVec = WsunVecSmooth;
    #else
        vec3 WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    #endif

    #if defined CUSTOM_MOON_ROTATION && defined OVERWORLD_SHADER

        #ifdef CAELUM_SUPPORT
            customMoonVecSSBO = -normalize(mat3(gbufferModelViewInverse) * moonPosition); //idk why it's negative
        #else
            // ensure the world time gets reset at a multiple of the month length
            #ifdef SMOOTH_MOON_ROTATION
                float time = worldTimeSmooth;
            #else
                float time = worldTime;
            #endif

            float absWorldTime = worldTimeSmooth  + mod(worldDay, 100 - mod(100, MONTH_LENGTH))*24000.0 - 48000.0; // offset by two days to align to vanilla moon phases by default

            float yearLengthTicks = float(MONTH_LENGTH) * 12.0 * 24000.0;
            float timeInYear = mod(absWorldTime, yearLengthTicks)/(yearLengthTicks);

            float moon_offset = 2.0 * EARTH_ROTATION_TILT * smoothstep(0.0, 0.5, timeInYear) * smoothstep(1.0, 0.5, timeInYear) - EARTH_ROTATION_TILT;

            customMoonVecSSBO = normalize(moonDirection(absWorldTime - MOON_TIME_OFFSET, MOON_LATITUDE, moon_offset));
        #endif

        #if LIGHTNING_SHADOWS > 0
            customMoonVec2SSBO = customMoonVecSSBO;

            if (lightningBoltPosition.w > 0.0) {
                vec4 lightningBoltPosition= lightningBoltPosition;
                lightningBoltPosition.y = max(lightningBoltPosition.y, cameraPosition.y);
                customMoonVecSSBO = normalize(lightningBoltPosition.xyz);
            }
        #endif

        #if defined CAELUM_SUPPORT || (defined SMOOTH_SUN_ROTATION && (daySpeed < 1.0 || nightSpeed < 1.0))
            #if LIGHTNING_SHADOWS > 1
            if (sunElevation > 0.0 && lightningBoltPosition.w == 0.0) 
            #else
            if (sunElevation > 0.0)
            #endif
            {
                customShadowMatrixSSBO = BuildShadowViewMatrix(WsunVec); //replace only the matrix
            } else {
                customShadowMatrixSSBO = BuildShadowViewMatrix(customMoonVecSSBO);
            }
        #else
            customShadowMatrixSSBO = BuildShadowViewMatrix(customMoonVecSSBO);
        #endif
    #endif

    #if defined END_ISLAND_LIGHT && defined END_SHADER
        customShadowMatrixSSBO = BuildShadowViewMatrix(normalize(END_LIGHT_POS));
        customShadowPerspectiveSSBO = createPerspectiveMatrix();
    #endif

    #ifdef PHOTONICS
        customShadowMatrixInverseSSBO = inverse(customShadowMatrixSSBO);
    #endif
    
    #ifdef OVERWORLD_SHADER
        ////////////////////////////////
        /// --- SCENE CONTROLLER --- ///
        ////////////////////////////////
        float mixhistory = 0.06;
        if(worldTimeChangeCheck) mixhistory = 1.0;

        vec2 smallCumulus = vec2(CloudLayer0_coverage, CloudLayer0_density);
        vec2 largeCumulus = vec2(CloudLayer1_coverage, CloudLayer1_density);
        vec2 altostratus = vec2(CloudLayer2_coverage, CloudLayer2_density);
        vec2 cirrus = vec2(CloudLayer3_coverage, CloudLayer3_density);
        vec2 fog = vec2(1.0);

        #ifdef Daily_Weather
            #ifdef CHOOSE_RANDOM_WEATHER_PROFILE
                int dayCounter = int(clamp(hash11(float(mod(worldDay, 1000))) * 10.0, 0,10));
            #else
                int dayCounter = int(mod(worldDay, 10));
            #endif
            
            //----------- cloud coverage
            vec4 weatherProfile_cloudCoverage[10] = vec4[](
                vec4(DAY0_l0_coverage, DAY0_l1_coverage, DAY0_l2_coverage, DAY0_l3_coverage),
                vec4(DAY1_l0_coverage, DAY1_l1_coverage, DAY1_l2_coverage, DAY1_l3_coverage),
                vec4(DAY2_l0_coverage, DAY2_l1_coverage, DAY2_l2_coverage, DAY2_l3_coverage),
                vec4(DAY3_l0_coverage, DAY3_l1_coverage, DAY3_l2_coverage, DAY3_l3_coverage),
                vec4(DAY4_l0_coverage, DAY4_l1_coverage, DAY4_l2_coverage, DAY4_l3_coverage),
                vec4(DAY5_l0_coverage, DAY5_l1_coverage, DAY5_l2_coverage, DAY5_l3_coverage),
                vec4(DAY6_l0_coverage, DAY6_l1_coverage, DAY6_l2_coverage, DAY6_l3_coverage),
                vec4(DAY7_l0_coverage, DAY7_l1_coverage, DAY7_l2_coverage, DAY7_l3_coverage),
                vec4(DAY8_l0_coverage, DAY8_l1_coverage, DAY8_l2_coverage, DAY8_l3_coverage),
                vec4(DAY9_l0_coverage, DAY9_l1_coverage, DAY9_l2_coverage, DAY9_l3_coverage)
            );

            //----------- cloud density
            vec4 weatherProfile_cloudDensity[10] = vec4[](
                vec4(DAY0_l0_density, DAY0_l1_density, DAY0_l2_density, DAY0_l3_density),
                vec4(DAY1_l0_density, DAY1_l1_density, DAY1_l2_density, DAY1_l3_density),
                vec4(DAY2_l0_density, DAY2_l1_density, DAY2_l2_density, DAY2_l3_density),
                vec4(DAY3_l0_density, DAY3_l1_density, DAY3_l2_density, DAY3_l3_density),
                vec4(DAY4_l0_density, DAY4_l1_density, DAY4_l2_density, DAY4_l3_density),
                vec4(DAY5_l0_density, DAY5_l1_density, DAY5_l2_density, DAY5_l3_density),
                vec4(DAY6_l0_density, DAY6_l1_density, DAY6_l2_density, DAY6_l3_density),
                vec4(DAY7_l0_density, DAY7_l1_density, DAY7_l2_density, DAY7_l3_density),
                vec4(DAY8_l0_density, DAY8_l1_density, DAY8_l2_density, DAY8_l3_density),
                vec4(DAY9_l0_density, DAY9_l1_density, DAY9_l2_density, DAY9_l3_density)
            );

            vec4 getWeatherProfile_coverage = weatherProfile_cloudCoverage[dayCounter];
            vec4 getWeatherProfile_density = weatherProfile_cloudDensity[dayCounter];
            
            smallCumulus = vec2(getWeatherProfile_coverage.r, getWeatherProfile_density.r);
            largeCumulus = vec2(getWeatherProfile_coverage.g, getWeatherProfile_density.g);
            altostratus =  vec2(getWeatherProfile_coverage.b, getWeatherProfile_density.b);
            cirrus =  vec2(getWeatherProfile_coverage.a, getWeatherProfile_density.a);

            //----------- fog density
            vec2 weatherProfile_fogDensity[10] = vec2[](
                vec2(DAY0_ufog_density, DAY0_cfog_density),
                vec2(DAY1_ufog_density, DAY1_cfog_density),
                vec2(DAY2_ufog_density, DAY2_cfog_density),
                vec2(DAY3_ufog_density, DAY3_cfog_density),
                vec2(DAY4_ufog_density, DAY4_cfog_density),
                vec2(DAY5_ufog_density, DAY5_cfog_density),
                vec2(DAY6_ufog_density, DAY6_cfog_density),
                vec2(DAY7_ufog_density, DAY7_cfog_density),
                vec2(DAY8_ufog_density, DAY8_cfog_density),
                vec2(DAY9_ufog_density, DAY9_cfog_density)
            );

            fog = weatherProfile_fogDensity[dayCounter];
        #endif

        float SCmixhistory = 0.1*frameTime;
        if(frameCounter < 4) SCmixhistory = 1.0;
        SC_smallCumulus = interpolateValue(SC_smallCumulus, smallCumulus, SCmixhistory);
        SC_largeCumulus = interpolateValue(SC_largeCumulus, largeCumulus, SCmixhistory);
        SC_altostratus = interpolateValue(SC_altostratus, altostratus, SCmixhistory);
        SC_cirrus = interpolateValue(SC_cirrus, cirrus, SCmixhistory);
        SC_fog = interpolateValue(SC_fog, fog, SCmixhistory);

        ///////////////////////////////////
        /// --- AMBIENT LIGHT STUFF --- ///
        ///////////////////////////////////

        vec3 averageSkyCol_Clouds = vec3(0.0);
        vec3 averageSkyCol = vec3(0.0);

        vec2 sample3x3[9] = vec2[](

            vec2(-1.0, -0.3),
            vec2( 0.0,  0.0),
            vec2( 1.0, -0.3),

            vec2(-1.0, -0.5),
            vec2( 0.0, -0.5),
            vec2( 1.0, -0.5),

            vec2(-1.0, -1.0),
            vec2( 0.0, -1.0),
            vec2( 1.0, -1.0)
        );

        // sample in a 3x3 pattern to get a good area for average color
        
        // int maxIT = 9;
        // for (int i = 0; i < maxIT; i++) {
        // 	vec3 pos = vec3(0.0,1.0,0.0);
        // 	pos.xy += normalize(sample3x3[i]) * vec2(0.3183,0.9000);

        // 	averageSkyCol_Clouds += skyCloudsFromTex(pos,colortex4).rgb/maxIT/150.0;
        // 	averageSkyCol += skyFromTex(pos,colortex4).rgb/maxIT/150.0;
        // }
        float maxIT = 20.0;
        for (int i = 0; i < int(maxIT); i++) {
            vec2 ij = R2_samples(((i*50+1)%1000)*int(maxIT)+i) * vec2(1.0,0.9000);
            vec3 pos = normalize(rodSample(ij)) * vec3(1.0,0.5,1.0) + vec3(0.0,0.5,0.0);

            averageSkyCol_Clouds += skyCloudsFromTex(pos,colortex4).rgb/maxIT/150.0;
            averageSkyCol += 1.5 * skyFromTex(pos,colortex4).rgb/maxIT/150.0;
        }


        // vec3 minimumlight =  vec3(1.0) * 0.01 * MIN_LIGHT_AMOUNT + nightVision * 0.05;

        // luminance based reinhard is useful ouside of tonemapping too.
        averageSkyCol_Clouds = averageSkyCol_Clouds / (1.0+luma(averageSkyCol_Clouds)*0.2);

        averageSkyCol = max(averageSkyCol, 0.0); // + minimumlight;

        #ifdef USE_CUSTOM_SKY_GROUND_LIGHTING_COLORS
            averageSkyCol = luma(averageSkyCol) * vec3(SKY_GROUND_R,SKY_GROUND_G,SKY_GROUND_B);
        #endif

        averageSkyColSSBO = averageSkyCol;

        ////////////////////////////////////////
        /// --- SUNLIGHT/MOONLIGHT STUFF --- ///
        ////////////////////////////////////////

        vec2 planetSphere = vec2(0.0);

        float sunVis = clamp(sunElevation,0.0,0.04)/0.04*clamp(sunElevation,0.0,0.04)/0.04;
        float moonVis = clamp(-moonElevation,0.0,0.04)/0.04*clamp(-moonElevation,0.0,0.04)/0.04;

        vec3 skyAbsorb = vec3(0.0);
        vec3 sunColor = calculateAtmosphere(vec3(0.0), WsunVec, vec3(0.0,1.0,0.0), WsunVec, -WsunVec, planetSphere, skyAbsorb, 25,0.0);
        sunColor = sunColorBase/4000.0 * skyAbsorb;
        vec3 moonColor = moonColorBase/4000.0;

        #ifdef CUSTOM_MOON_ROTATION
            #if LIGHTNING_SHADOWS > 0
                vec3 WmoonVec = customMoonVec2SSBO;
            #else
                vec3 WmoonVec = customMoonVecSSBO;
            #endif

            float moonPhase = 1.0 - 0.5 * (dot(WsunVec, WmoonVec) + 1.0);
            moonVis = smoothstep(0.08, -0.03, -WmoonVec.y);
            moonColor *= moonPhase;
            
        #endif

        // lightSourceColor = sunVis >= 1e-5 ? sunColor * sunVis : moonColor * moonVis;
        vec3 lightSourceColor = sunColor * sunVis + moonColor * moonVis;
        #ifdef CUSTOM_MOON_ROTATION
            lightSourceColor *= smoothstep(0.005, 0.09, length(WmoonVec - WsunVec));
        #endif

        #if defined TWILIGHT_FOREST_FLAG
            vec3 lightSourceColor = vec3(0.0);
            vec3 moonColor = vec3(0.0);
        #endif

        /////////////////////////////////
        ///// --- STORE COLOR LUT --- ///
        /////////////////////////////////

        #ifdef SeparateAmbientColorRain
            vec3 AmbientLightTint = mix(vec3(AmbientLight_R, AmbientLight_G, AmbientLight_B), mix(vec3(AmbientLightRain_R, AmbientLightRain_G, AmbientLightRain_B), vec3(AmbientLightThunder_R, AmbientLightThunder_G, AmbientLightThunder_B), thunderStrength), rainStrength*noPuddleAreas);
        #else
            vec3 AmbientLightTint = vec3(AmbientLight_R, AmbientLight_G, AmbientLight_B);
        #endif
        // --- the color of the atmosphere + the average color of the atmosphere.
        vec3 skyGroundCol = skyFromTex(vec3(0, -1 ,0), colortex4).rgb * AmbientLightTint;


        /// --- Save light values
        averageSkyCol_CloudsSSBO = interpolateValue(averageSkyCol_CloudsSSBO, averageSkyCol_Clouds * AmbientLightTint * 150.0, mixhistory);

        skyGroundColSSBO = interpolateValue(skyGroundColSSBO, skyGroundCol, mixhistory);

        #ifdef AMBIENT_LIGHT_ONLY
            lightSourceColorSSBO = vec3(0.0);

            sunColorSSBO = vec3(0.0);

            moonColorSSBO = vec3(0.0);
        #else
            lightSourceColorSSBO = interpolateValue(lightSourceColorSSBO, lightSourceColor*150.0, mixhistory);

            sunColorSSBO = interpolateValue(sunColorSSBO, sunColor*150.0, mixhistory);

            moonColorSSBO = interpolateValue(moonColorSSBO, moonColor*150.0, mixhistory);
        #endif
    #else
            lightSourceColorSSBO = vec3(0.0);

            sunColorSSBO = vec3(0.0);

            moonColorSSBO = vec3(0.0);
    #endif

    #if defined FLASHLIGHT && defined FLASHLIGHT_BOUNCED_INDIRECT
    	// sample center pixel of albedo color, and interpolate it overtime.

        vec3 data = texelFetch(colortex1, ivec2(0.5/texelSize), 0).rgb;
        vec3 decodeAlbedo = vec3(decodeVec2(data.x).x,decodeVec2(data.y).x, decodeVec2(data.z).x);
        vec3 albedo = toLinear(decodeAlbedo);

        albedo = normalize(albedo + 1e-7) * (dot(albedo,vec3(0.21, 0.72, 0.07))*0.5+0.5);

        albedoSmoothSSBO = interpolateValue(albedoSmoothSSBO, albedo*150.0, 0.01);
    #endif
}
