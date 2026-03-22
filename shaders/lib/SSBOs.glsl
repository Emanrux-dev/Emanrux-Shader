layout(std430, binding = 4) buffer SSBO1 {
    mat4 customShadowMatrixSSBO; // 64 bytes

    #ifdef PHOTONICS
    mat4 customShadowMatrixInverseSSBO;
    #endif

    vec3 customMoonVecSSBO; // 12 bytes

    vec3 customMoonVec2SSBO; // 12 bytes

    mat4 customShadowPerspectiveSSBO; // 64 bytes

    vec3 customSunVecSSBO; // 12 bytes

    #if IRIS_VERSION < 11004
    bool onWaterSurface; // 1 byte

    bool inBoatCurrentFrame; // 1 byte

    bool inBoatLastFrame; // 1 byte

    bool inShipCurrentFrame; // 1 byte

    bool inShipLastFrame; // 1 byte
    #endif

    float waterRoundSize;

    float lastFrameTimeCount; // 4 bytes

    vec3 previousCameraPositionWave; // 12 bytes

    vec3 previousCameraPositionWave2; // 12 bytes

    bool noSimOngoing; // 1 byte

    bool noSimOngoingCheck; // 1 byte

    ivec2 water_move_compensationSSBO; // 8 bytes

    vec2 water_move_compensation_counter_SSBO; // 8 bytes

    vec2 SC_smallCumulus;

    vec2 SC_largeCumulus;

    vec2 SC_altostratus;

    vec2 SC_cirrus;

    vec2 SC_fog;

    vec3 sunColorSSBO;

    vec3 moonColorSSBO;

    vec3 lightSourceColorSSBO;

    vec3 averageSkyColSSBO;

    vec3 averageSkyCol_CloudsSSBO;

    vec3 skyGroundColSSBO;

    vec3 albedoSmoothSSBO;

    float avgBrightnessSSBO;

    float avgL2SSBO;

    float exposureSSBO;

    vec2 rodExposureDepthSSBO;
};