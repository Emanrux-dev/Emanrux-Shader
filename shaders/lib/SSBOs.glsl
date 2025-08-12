layout(binding = 0) buffer customMoonSSBO {
    mat4 customShadowMatrixSSBO; // 64 bytes

    vec3 customMoonVecSSBO; // 16 bytes

    vec3 customMoonVec2SSBO; // 16 bytes

    mat4 customShadowPerspectiveSSBO; // 64 bytes
};