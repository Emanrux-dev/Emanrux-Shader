

vec3 modify_attenuation(
    Light light,
    vec3 to_light,
    vec3 sample_pos,
    vec3 source_pos,
    vec3 geometry_normal,
    vec3 texture_normal
) {
    // Fix light on handheld light sources being weird
    if (light.index < 0 && ph_is_hand()) return light.color;

    #ifdef SHADER_GRASS
        vec4 data = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
    
        // vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y)); // albedo, masks
        // vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w)); // normals, lightmaps
        float opaqueMasks = decodeVec2(data.w).y;
        bool isShaderGrass = abs(opaqueMasks-0.80) < 0.01;
    #else
        const bool isShaderGrass = false;
    #endif

    vec4 SpecularData = texelFetch(colortex8, ivec2(gl_FragCoord.xy), 0);
    // vec4 specdataUnpacked0 = vec4(decodeVec2(SpecularData.x),decodeVec2(SpecularData.y));
    // vec4 specdataUnpacked1 = vec4(decodeVec2(SpecularData.z),decodeVec2(SpecularData.w));
    // vec4 SpecularTex = vec4(specdataUnpacked0.xz, specdataUnpacked1.xz);
    float LabSSS = clamp((-65.0 + decodeVec2(SpecularData.z).x * 255.0) / 190.0, 0.0, 0.999);

    float distance_squared = dot(to_light, to_light);
    float light_dist_inv = inversesqrt(distance_squared);
    vec3 light_dir = to_light * light_dist_inv;

    if(!isShaderGrass && LabSSS < 0.025) {
        float NdotGN = dot(light_dir, geometry_normal);
        if (NdotGN < 0.01f) return vec3(0f);
    }

    float att = 1f / (distance_squared * light.falloff * light.attenuation.y + light.attenuation.x);
    
    if(!isShaderGrass) {
        att *= clamp(dot(ph_frag_is_hand ? geometry_normal : texture_normal, light_dir), pow(LabSSS, 1.5), 1f);
    }

    return att * light.color;
}