// How far light propagates (block, sky)
const vec2 LpvBlockSkyRange = vec2(15.0, 24.0);

#if defined IS_LPV_ENABLED || defined SHADER_GRASS
	const uint LpvSize = uint(exp2(LPV_SIZE));
	const uvec3 LpvSize3 = uvec3(LpvSize);
#else
	const uint LpvSize = uint(5);
	const uvec3 LpvSize3 = uvec3(LpvSize);
#endif

vec3 GetLpvPosition(vec3 playerPos) {
    vec3 cp = cameraPosition;
    #if !defined IS_LPV_ENABLED && !defined SHADER_GRASS
    cp -= relativeEyePosition;
    #endif
    
    vec3 offset = fract(cp);
    vec3 center = vec3(LpvSize3) * 0.5;
    
    return playerPos + offset + center;
}
