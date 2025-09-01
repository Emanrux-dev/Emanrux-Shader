layout(binding = 0) buffer SSBO1 {
    mat4 customShadowMatrixSSBO; // 64 bytes

    vec3 customMoonVecSSBO; // 12 bytes

    vec3 customMoonVec2SSBO; // 12 bytes

    mat4 customShadowPerspectiveSSBO; // 64 bytes

    vec3 customSunVecSSBO; // 12 bytes

    bool onWaterSurface; // 1 byte

    bool inBoat; // 1 byte

    bool inBoatCurrentFrame; // 1 byte

    bool inBoatLastFrame; // 1 byte

    bool inShip; // 1 byte

    bool inShipCurrentFrame; // 1 byte

    bool inShipLastFrame; // 1 byte

    float lastFrameTimeCount; // 4 bytes

    vec3 previousCameraPositionWave; // 12 bytes

    vec3 previousCameraPositionWave2; // 12 bytes

    bool noSimOngoing; // 1 byte

    bool noSimOngoingCheck; // 1 byte
};