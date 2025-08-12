#include "/lib/settings.glsl"
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#ifdef CUSTOM_MOON_ROTATION
    uniform float sunElevation;
    uniform mat4 shadowModelView;
    uniform int worldTime;
    uniform int worldDay;
    // uniform float frameTimeCounter;
    uniform vec4 lightningBoltPosition;

    
    #include "/lib/util.glsl"

    vec3 moonDirection(float worldTime, float latitude, float pathRotation) {
        float phi = radians(-latitude);
        float del = radians(pathRotation);
        
        float t = worldTime / 24000.0;

        t *= 1.0 + 1.0 / MONTH_LENGTH;

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
    #include "/lib/SSBOs.glsl"
    uniform vec3 cameraPosition;
    #if defined END_ISLAND_LIGHT && defined END_SHADER
        float NEAR = 15.0;
        float FAR = 256.0;

        mat4 createPerspectiveMatrix() {
            float fov = END_LIGHT_FOV;
            float yScale = 1.0 / tan(radians(fov) * 0.5);

            return mat4(
                    yScale, 0.0, 0.0, 0.0,
                    0.0, yScale, 0.0, 0.0,
                    0.0, 0.0, (FAR + NEAR) / (NEAR - FAR), -1.0,
                    0.0, 0.0, 2.0 * FAR * NEAR / (NEAR - FAR), 1.0
                );

        }
    #endif

    mat4 BuildTranslationMatrix(vec3 delta) {
        return mat4(
            vec4(1.0, 0.0, 0.0, 0.0),
            vec4(0.0, 1.0, 0.0, 0.0),
            vec4(0.0, 0.0, 1.0, 0.0),
            vec4(delta,         1.0));
    }

    mat4 BuildShadowViewMatrix(vec3 localLightDir) {
        #ifndef CAELUM_SUPPORT
            #ifdef OVERWORLD_SHADER
                #if LIGHTNING_SHADOWS > 1
                    if (sunElevation > 0.0 && lightningBoltPosition.w == 0.0) return shadowModelView;
                #else
                    if (sunElevation > 0.0) return shadowModelView;
                #endif
            #else
                localLightDir = normalize(END_LIGHT_POS);
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

uniform mat4 gbufferModelViewInverse;
uniform vec3 moonPosition;
uniform vec3 sunPosition;


void main() {
    #if defined CUSTOM_MOON_ROTATION && defined OVERWORLD_SHADER

        #ifdef CAELUM_SUPPORT
            customMoonVecSSBO = -normalize(mat3(gbufferModelViewInverse) * moonPosition); //idk why it's negative
        #else
            // ensure the world time gets reset at a multiple of the month length
            float absWorldTime = worldTime  + mod(worldDay, 100 - mod(100, MONTH_LENGTH))*24000.0;

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

        customShadowMatrixSSBO = BuildShadowViewMatrix(customMoonVecSSBO);
        #ifdef CAELUM_SUPPORT
            if (sunElevation > 0.0) customShadowMatrixSSBO = BuildShadowViewMatrix(normalize(mat3(gbufferModelViewInverse) * sunPosition)); //replace only the matrix
        #endif
    #endif

    #if defined END_ISLAND_LIGHT && defined END_SHADER
        customShadowMatrixSSBO = BuildShadowViewMatrix(vec3(0.0, 1.0, 0.0));
        customShadowPerspectiveSSBO = createPerspectiveMatrix();
    #endif
}
