#ifndef SPACE_OBJECTS_GLSL
#define SPACE_OBJECTS_GLSL

#ifdef END_SHADER
    #define SPACE_PLANET_BRIGHTNESS END_PLANET_BRIGHTNESS
    #define SPACE_PLANET_QUALITY END_PLANET_QUALITY
    #define SPACE_METEOR_COUNT END_METEOR_COUNT
    #define SPACE_METEOR_RARITY END_METEOR_RARITY
    #define SPACE_METEOR_SPEED END_METEOR_SPEED
#else
    #define SPACE_PLANET_BRIGHTNESS PLANET_BRIGHTNESS
    #define SPACE_PLANET_QUALITY PLANET_QUALITY
    #define SPACE_METEOR_COUNT METEOR_COUNT
    #define SPACE_METEOR_RARITY METEOR_RARITY
    #define SPACE_METEOR_SPEED METEOR_SPEED
#endif

float spaceHash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float spaceNoise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = spaceHash13(i + vec3(0.0, 0.0, 0.0));
    float n100 = spaceHash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = spaceHash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = spaceHash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = spaceHash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = spaceHash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = spaceHash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = spaceHash13(i + vec3(1.0, 1.0, 1.0));

    float nx00 = mix(n000, n100, f.x);
    float nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x);
    float nx11 = mix(n011, n111, f.x);
    return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

float spaceFbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;

    #if SPACE_PLANET_QUALITY == 0
        const int octaves = 2;
    #elif SPACE_PLANET_QUALITY == 2
        const int octaves = 6;
    #else
        const int octaves = 4;
    #endif

    for (int i = 0; i < 6; i++) {
        if (i < octaves) {
            v += spaceNoise3(p) * a;
            p = p * 2.03 + vec3(17.7, 9.2, 5.4);
            a *= 0.5;
        }
    }

    return v;
}

bool spaceRaySphere(vec3 ro, vec3 rd, vec3 center, float radius, out float tNear, out float tFar) {
    vec3 oc = ro - center;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float h = b * b - c;
    if (h < 0.0) return false;

    h = sqrt(h);
    tNear = -b - h;
    tFar = -b + h;
    return tFar > 0.0;
}

bool spaceRayDisc(vec3 ro, vec3 rd, vec3 center, vec3 normal, float innerRadius, float outerRadius, out float t, out vec3 rel, out float radial) {
    float denom = dot(rd, normal);
    if (abs(denom) < 0.0001) return false;

    t = dot(center - ro, normal) / denom;
    if (t <= 0.0) return false;

    rel = ro + rd * t - center;
    radial = length(rel);
    return radial > innerRadius && radial < outerRadius;
}

vec3 spaceRotateAxis(vec3 p, vec3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    return p * c + cross(axis, p) * s + axis * dot(axis, p) * (1.0 - c);
}

vec3 spacePlanetBaseDir(int id) {
    #ifdef END_SHADER
        if (id == 0) return normalize(vec3(-0.58, 0.31, 0.75));
        if (id == 1) return normalize(vec3( 0.38, 0.47, 0.79));
        if (id == 2) return normalize(vec3(-0.18, 0.70, 0.69));
        if (id == 3) return normalize(vec3( 0.70, 0.23, 0.67));
        return normalize(vec3(-0.72, 0.52, 0.46));
    #else
        if (id == 0) return normalize(vec3(-0.86, 0.20, 0.46));
        if (id == 1) return normalize(vec3( 0.64, 0.52, 0.48));
        if (id == 2) return normalize(vec3(-0.18, 0.80, 0.55));
        if (id == 3) return normalize(vec3( 0.92, 0.18, 0.34));
        return normalize(vec3(-0.62, 0.76, 0.14));
    #endif
}

float spacePlanetBaseDistance(int id) {
    #ifdef END_SHADER
        if (id == 0) return 13.5;
        if (id == 1) return 12.5;
        if (id == 2) return 18.5;
        if (id == 3) return 20.0;
        return 25.0;
    #endif
    if (id == 0) return 14.0;
    if (id == 1) return 23.5;
    if (id == 2) return 34.0;
    if (id == 3) return 47.0;
    return 62.0;
}

vec3 spacePlanetCenter(int id) {
    #ifdef END_SHADER
        float t = frameTimeCounter * 0.010;
    #else
        float t = frameTimeCounter * 0.0065;
    #endif
    float fid = float(id);
    vec3 dir = spacePlanetBaseDir(id);

    float directionSign = mod(float(id), 2.0) < 1.0 ? 1.0 : -1.0;
    vec3 axisA = normalize(vec3((0.21 + fid * 0.13) * directionSign, 0.83 - fid * 0.07, 0.48 + fid * 0.09));
    vec3 axisB = normalize(vec3((-0.54 + fid * 0.11) * -directionSign, 0.37 + fid * 0.08, 0.74 - fid * 0.05));
    float phase = fid * 2.41;
    #ifdef END_SHADER
        float speedA = (0.82 + fid * 0.22) * directionSign;
        float speedB = (0.34 + fid * 0.12) * -directionSign;
    #else
        float speedA = (0.46 + fid * 0.12) * directionSign;
        float speedB = (0.22 + fid * 0.06) * -directionSign;
        if (id == 1) {
            speedA *= 0.68;
            speedB *= 0.62;
        }
    #endif

    dir = spaceRotateAxis(dir, axisA, t * speedA + phase);
    dir = spaceRotateAxis(dir, axisB, sin(t * speedB + phase * 1.7) * 0.42);
    #ifdef END_SHADER
        dir.y = dir.y * 0.78 + 0.16 + 0.08 * sin(t * (0.75 + fid * 0.19) * directionSign + phase);
    #else
        dir.y = dir.y * 0.82 + 0.04 + 0.06 * sin(t * (0.75 + fid * 0.19) * directionSign + phase);
    #endif
    dir = normalize(dir);

    float drift = 1.0 + 0.16 * sin(t * (0.91 + fid * 0.12) + phase) + 0.07 * sin(t * (1.71 + fid * 0.06) + phase * 0.6);
    return dir * spacePlanetBaseDistance(id) * drift;
}

float spacePlanetRadius(int id) {
    #ifdef END_SHADER
        if (id == 0) return 0.20;
        if (id == 1) return 0.95;
        if (id == 2) return 0.34;
        if (id == 3) return 1.45;
        return 0.14;
    #endif
    if (id == 0) return 0.32;
    if (id == 1) return 1.08;
    if (id == 2) return 0.52;
    if (id == 3) return 1.58;
    return 0.38;
}

vec3 spacePlanetColorA(int id) {
    #ifdef END_SHADER
        if (id == 0) return vec3(0.72, 0.70, 0.52);
        if (id == 1) return vec3(0.76, 0.18, 0.92);
        if (id == 2) return vec3(0.08, 0.20, 0.66);
        if (id == 3) return vec3(0.55, 0.08, 0.58);
        return vec3(0.20, 0.12, 0.44);
    #else
        if (id == 0) return vec3(0.30, 0.38, 0.42);
        if (id == 1) return vec3(0.48, 0.40, 0.30);
        if (id == 2) return vec3(0.34, 0.42, 0.36);
        if (id == 3) return vec3(0.44, 0.30, 0.24);
        return vec3(0.42, 0.45, 0.48);
    #endif
}

vec3 spacePlanetColorB(int id) {
    #ifdef END_SHADER
        if (id == 0) return vec3(0.92, 0.88, 0.62);
        if (id == 1) return vec3(0.20, 0.06, 0.44);
        if (id == 2) return vec3(0.46, 0.22, 0.96);
        if (id == 3) return vec3(0.10, 0.38, 0.84);
        return vec3(0.82, 0.16, 0.72);
    #else
        if (id == 0) return vec3(0.58, 0.55, 0.45);
        if (id == 1) return vec3(0.68, 0.56, 0.40);
        if (id == 2) return vec3(0.58, 0.64, 0.58);
        if (id == 3) return vec3(0.62, 0.44, 0.34);
        return vec3(0.30, 0.34, 0.42);
    #endif
}

vec4 spaceBlendOver(vec4 under, vec4 over) {
    under.rgb = mix(under.rgb, over.rgb, clamp(over.a, 0.0, 1.0));
    under.a = max(under.a, over.a);
    return under;
}

float spaceCraterField(vec3 p, int id) {
    float fid = float(id);
    float craters = 0.0;

    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        vec3 c = normalize(vec3(
            spaceHash13(vec3(fid, fi, 1.7)) * 2.0 - 1.0,
            spaceHash13(vec3(fi, fid, 4.1)) * 2.0 - 1.0,
            spaceHash13(vec3(6.3, fid, fi)) * 2.0 - 1.0
        ));
        float d = length(p - c);
        float radius = mix(0.10, 0.28, spaceHash13(vec3(fi, fid, 8.8)));
        float bowl = 1.0 - smoothstep(radius * 0.20, radius, d);
        float rim = smoothstep(radius * 0.42, radius * 0.78, d) * (1.0 - smoothstep(radius * 0.78, radius * 1.05, d));
        craters += bowl * 0.42 + rim * 0.55;
    }

    return clamp(craters, 0.0, 1.0);
}

vec4 spaceRenderPlanet(vec3 ray, vec3 lightDir, int id, float visibility) {
    vec3 ro = vec3(0.0);
    vec3 center = spacePlanetCenter(id);
    float radius = spacePlanetRadius(id);
    vec3 centerDir = normalize(center);
    float planetFrontMask = smoothstep(0.0, 0.035, dot(ray, centerDir));
    float angularDist = length(cross(ray, centerDir));
    float angularRadius = radius / length(center);

    float tNear;
    float tFar;
    bool hitSphere = spaceRaySphere(ro, ray, center, radius, tNear, tFar);
    vec4 result = vec4(vec3(0.0), 0.0);

    float halo = exp(-max(angularDist - angularRadius, 0.0) * 90.0);
    halo *= 1.0 - smoothstep(angularRadius * 1.0, angularRadius * 4.2, angularDist);
    halo *= visibility * 0.055;
    halo *= planetFrontMask;
    #ifdef END_SHADER
        halo *= 0.0;
    #endif
    result.rgb += spacePlanetColorB(id) * halo * SPACE_PLANET_BRIGHTNESS;
    result.a = max(result.a, halo * 0.45);

    if (hitSphere && tNear > 0.0 && planetFrontMask > 0.0) {
        vec3 hitPos = ro + ray * tNear;
        vec3 n = normalize(hitPos - center);
        float fid = float(id);
        float spin = frameTimeCounter * (0.018 + fid * 0.004);
        vec3 pn = spaceRotateAxis(n, normalize(vec3(0.2 + fid, 1.0, 0.35 - fid * 0.08)), spin);
        float terrain = spaceFbm(pn * (4.0 + fid * 1.7) + fid * 19.31);
        float detail = spaceFbm(pn * (14.0 + fid * 2.0) + vec3(3.0, 9.0, 15.0));
        float micro = spaceFbm(pn * (34.0 + fid * 4.0) + frameTimeCounter * 0.01);
        float crater = id == 1 ? 0.0 : spaceCraterField(pn, id);
        float relief = detail * 0.22 + micro * 0.10 + crater * 0.34;
        float bands = 0.5 + 0.5 * sin((pn.y * (8.0 + fid * 1.4) + terrain * 2.6 + spin * 0.45) * 3.14159);
        float land = smoothstep(0.38, 0.64, terrain + detail * 0.18 - abs(pn.y) * 0.08);

        vec3 base = mix(spacePlanetColorA(id), spacePlanetColorB(id), mix(land, bands, id == 1 ? 0.65 : 0.25));
        base *= 0.70 + detail * 0.34 + micro * 0.14;
        base = mix(base, base * vec3(0.42, 0.43, 0.44), crater * 0.38);
        base += vec3(0.18, 0.17, 0.14) * smoothstep(0.52, 0.95, relief) * 0.18;

        #ifndef END_SHADER
            if (id == 1) {
                float longitude = atan(pn.z, pn.x);
                float goldenBands = 0.5 + 0.5 * sin(pn.y * 58.0 + terrain * 7.0 + spin * 1.4);
                float thinBands = 0.5 + 0.5 * sin(pn.y * 136.0 + detail * 9.0 - spin * 2.1);
                float cells = spaceFbm(vec3(longitude * 1.8, pn.y * 10.0, spin * 0.8) + pn * 3.5);
                float storms = pow(clamp(0.62 + 0.38 * sin(longitude * 5.0 + pn.y * 23.0 + cells * 5.0 + spin * 2.0), 0.0, 1.0), 5.0);
                float warmCaps = smoothstep(0.34, 0.92, abs(pn.y));
                vec3 ochre = vec3(1.00, 0.63, 0.22);
                vec3 cream = vec3(1.00, 0.90, 0.62);
                vec3 amber = vec3(0.72, 0.38, 0.12);
                vec3 bandCol = mix(amber, cream, goldenBands * 0.72 + thinBands * 0.28);
                base = mix(base, bandCol, 0.66);
                base = mix(base, ochre, storms * (0.18 + cells * 0.30));
                base += vec3(1.0, 0.68, 0.28) * pow(cells, 3.0) * 0.20;
                base *= 1.0 - warmCaps * 0.14;

                vec3 ringNormalShadow = normalize(vec3(0.46, 0.58, -0.68));
                vec3 lightN = normalize(lightDir);
                float nDotLShadow = clamp(dot(n, lightN), 0.0, 1.0);
                float denom = dot(lightN, ringNormalShadow);
                if (abs(denom) > 0.0001) {
                    float tPlane = dot(center - hitPos, ringNormalShadow) / denom;
                    if (tPlane > 0.0) {
                        vec3 shadowRel = hitPos + lightN * tPlane - center;
                        float shadowRad = length(shadowRel);
                        if (shadowRad > radius * 1.35 && shadowRad < radius * 2.55) {
                            float su = clamp((shadowRad - radius * 1.35) / (radius * 1.20), 0.0, 1.0);
                            float shadowBands = 0.55 + 0.45 * sin(su * 56.0 + spaceFbm(vec3(shadowRel.xz * 3.9, 1.0)) * 5.0);
                            float ringShadow = smoothstep(0.0, 0.08, su) * (1.0 - smoothstep(0.82, 1.0, su));
                            ringShadow *= mix(0.45, 1.0, shadowBands);
                            ringShadow *= 0.35 + 0.65 * smoothstep(0.0, 0.75, 1.0 - nDotLShadow);
                            base *= 1.0 - ringShadow * 0.35;
                        }
                    }
                }
            }
        #endif

        #ifdef END_SHADER
            float fissures = pow(1.0 - abs(spaceFbm(pn * 18.0 + fid * 4.7) - 0.52) * 8.0, 5.0);
            fissures = clamp(fissures, 0.0, 1.0);
            float storms = pow(clamp(0.5 + 0.5 * sin(atan(pn.z, pn.x) * (3.0 + fid) + pn.y * 11.0 + spin * 2.0), 0.0, 1.0), 4.0);
            float nebula = spaceFbm(pn * 7.0 + vec3(spin, fid, -spin * 0.7));
            if (id == 0) {
                vec3 endstoneA = vec3(0.62, 0.60, 0.44);
                vec3 endstoneB = vec3(0.94, 0.88, 0.60);
                base = mix(base, mix(endstoneA, endstoneB, nebula), fissures * 0.36);
                base += vec3(0.12, 0.08, 0.16) * storms * 0.05;
            } else {
                vec3 glowA = vec3(0.95, 0.18, 1.10);
                vec3 glowB = vec3(0.20, 0.55, 1.35);
                base = mix(base, base + mix(glowA, glowB, nebula) * 0.85, fissures * 0.72);
                base += mix(vec3(0.20, 0.04, 0.55), vec3(0.95, 0.18, 0.90), nebula) * storms * 0.28;
            }
        #endif

        float diffuse = clamp(dot(n, normalize(lightDir)), 0.0, 1.0);
        float rim = pow(1.0 - clamp(dot(n, -ray), 0.0, 1.0), 2.6);
        vec3 atmosphere = spacePlanetColorB(id) * rim * (0.35 + diffuse * 0.25);
        #ifdef END_SHADER
            atmosphere = atmosphere * 0.16 + vec3(0.42, 0.12, 1.0) * pow(rim, 1.4) * 0.045;
        #endif
        vec3 shaded = base * (0.13 + diffuse * 0.92) + atmosphere;

        result = spaceBlendOver(result, vec4(shaded * SPACE_PLANET_BRIGHTNESS, visibility));
    }

    if (!hitSphere && planetFrontMask > 0.0 && angularDist < angularRadius * 1.65) {
        vec3 up = abs(centerDir.y) > 0.92 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
        vec3 tangent = normalize(cross(up, centerDir));
        vec3 bitangent = normalize(cross(centerDir, tangent));
        vec2 discUv = vec2(dot(ray, tangent), dot(ray, bitangent)) / max(angularRadius, 1e-5);
        float r2 = dot(discUv, discUv);
        float discMask = 1.0 - smoothstep(0.88, 1.08, sqrt(r2));
        vec3 n = normalize(tangent * discUv.x + bitangent * discUv.y - centerDir * sqrt(max(1.0 - min(r2, 1.0), 0.0)));
        float fid = float(id);
        float spin = frameTimeCounter * (0.018 + fid * 0.004);
        vec3 pn = spaceRotateAxis(n, normalize(vec3(0.2 + fid, 1.0, 0.35 - fid * 0.08)), spin);
        float terrain = spaceFbm(pn * (5.5 + fid * 1.9) + fid * 19.31);
        float detail = spaceFbm(pn * (18.0 + fid * 2.0) + vec3(3.0, 9.0, 15.0));
        float bands = 0.5 + 0.5 * sin((pn.y * (9.0 + fid * 1.8) + terrain * 3.0 + spin * 0.45) * 3.14159);
        float land = smoothstep(0.36, 0.66, terrain + detail * 0.20 - abs(pn.y) * 0.08);
        vec3 base = mix(spacePlanetColorA(id), spacePlanetColorB(id), mix(land, bands, id == 1 ? 0.72 : 0.30));
        base *= 0.72 + detail * 0.42;
        #ifndef END_SHADER
            if (id == 1) {
                float thinBands = 0.5 + 0.5 * sin(pn.y * 128.0 + detail * 10.0 - spin * 2.1);
                base = mix(vec3(0.72, 0.38, 0.12), vec3(1.0, 0.88, 0.58), bands * 0.68 + thinBands * 0.32);
                base += vec3(1.0, 0.62, 0.20) * pow(detail, 3.0) * 0.18;
            }
        #endif
        #ifdef END_SHADER
            float fissures = pow(1.0 - abs(spaceFbm(pn * 18.0 + fid * 4.7) - 0.52) * 8.0, 5.0);
            base += mix(vec3(0.22, 0.08, 0.65), vec3(0.85, 0.20, 1.05), terrain) * clamp(fissures, 0.0, 1.0) * 0.46;
        #endif
        float diffuse = clamp(dot(n, normalize(lightDir)), 0.0, 1.0);
        float rim = pow(1.0 - clamp(dot(n, -ray), 0.0, 1.0), 2.4);
        vec3 shaded = base * (0.16 + diffuse * 0.88) + spacePlanetColorB(id) * rim * 0.22;
        result = spaceBlendOver(result, vec4(shaded * SPACE_PLANET_BRIGHTNESS, visibility * discMask));
    }

    #ifndef END_SHADER
    if (id == 1) {
        vec3 ringNormal = normalize(vec3(0.46, 0.58, -0.68));

        float tRing;
        vec3 rel;
        float radial;
        if (spaceRayDisc(ro, ray, center, ringNormal, radius * 1.26, radius * 2.82, tRing, rel, radial)) {
            float sphereT0;
            float sphereT1;
            bool occludedByPlanet = spaceRaySphere(ro, ray, center, radius * 1.02, sphereT0, sphereT1) && sphereT0 > 0.0 && sphereT0 < tRing;

            if (!occludedByPlanet) {
                vec3 ringPoint = ro + ray * tRing;
                float shadowT0;
                float shadowT1;
                bool inPlanetShadow = spaceRaySphere(ringPoint + normalize(lightDir) * 0.03, normalize(lightDir), center, radius * 1.07, shadowT0, shadowT1);

                float width = radius * 1.56;
                float u = clamp((radial - radius * 1.26) / width, 0.0, 1.0);
                float radialNoise = spaceFbm(vec3(normalize(rel).xz * 2.2, u * 3.0 + 4.0));
                float broadBandA = smoothstep(0.02, 0.10, u) * (1.0 - smoothstep(0.18, 0.26, u));
                float broadBandB = smoothstep(0.24, 0.34, u) * (1.0 - smoothstep(0.56, 0.66, u));
                float broadBandC = smoothstep(0.61, 0.70, u) * (1.0 - smoothstep(0.88, 0.98, u));
                float cassiniGap = 1.0 - smoothstep(0.49, 0.52, u) * (1.0 - smoothstep(0.56, 0.59, u));
                float innerGap = 1.0 - smoothstep(0.19, 0.21, u) * (1.0 - smoothstep(0.235, 0.255, u));
                float density = broadBandA * 0.42 + broadBandB * 0.78 + broadBandC * 0.54;
                density *= cassiniGap * innerGap;
                density *= mix(0.76, 1.10, radialNoise);
                density *= 1.0 - smoothstep(0.90, 1.0, u);
                density *= inPlanetShadow ? 0.20 : 1.0;

                vec3 ringCol = mix(spacePlanetColorB(id), vec3(1.0, 0.88, 0.62), 0.42);
                #ifndef END_SHADER
                    ringCol = mix(vec3(0.64, 0.51, 0.34), vec3(0.98, 0.90, 0.70), smoothstep(0.18, 0.82, u));
                    ringCol = mix(ringCol, vec3(0.76, 0.62, 0.42), radialNoise * 0.35);
                #endif
                #ifdef END_SHADER
                    ringCol = mix(vec3(0.48, 0.18, 1.35), vec3(1.0, 0.28, 0.92), u);
                    density *= 0.08;
                #endif
                result = spaceBlendOver(result, vec4(ringCol * density * SPACE_PLANET_BRIGHTNESS * 0.72, density * visibility * 0.46));
            }
        }
    }
    #endif

    result.rgb *= visibility;
    result.a *= visibility;
    return result;
}

void spaceBlendPlanet(inout vec3 color, vec3 ray, vec3 lightDir, int id, float visibility) {
    vec4 planet = spaceRenderPlanet(ray, lightDir, id, visibility);
    float alpha = clamp(planet.a, 0.0, 1.0);
    color = mix(color + planet.rgb, planet.rgb, alpha);
}

#ifndef END_SHADER
void spaceRenderHorizonPlanet(inout vec3 color, vec3 ray, vec3 lightDir, float visibility) {
    vec3 ro = vec3(0.0);
    vec3 center = normalize(vec3(-0.93, -0.015, 0.36)) * 25.5;
    float radius = 3.45;
    float tNear;
    float tFar;

    if (!spaceRaySphere(ro, ray, center, radius, tNear, tFar) || tNear <= 0.0) {
        return;
    }

    vec3 hitPos = ro + ray * tNear;
    vec3 n = normalize(hitPos - center);
    vec3 pn = spaceRotateAxis(n, normalize(vec3(0.18, 1.0, -0.28)), -0.34);
    float terrain = spaceFbm(pn * 6.8 + vec3(8.0, 17.0, 3.0));
    float detail = spaceFbm(pn * 24.0 + vec3(1.0, 5.0, 11.0));
    float micro = spaceFbm(pn * 52.0 + vec3(4.0, 13.0, 21.0));
    float storms = pow(clamp(0.5 + 0.5 * sin(atan(pn.z, pn.x) * 8.0 + pn.y * 34.0 + detail * 8.0), 0.0, 1.0), 4.0);
    float polar = smoothstep(0.48, 0.92, abs(pn.y));
    vec3 lowlands = vec3(0.28, 0.29, 0.27);
    vec3 highlands = vec3(0.52, 0.51, 0.46);
    vec3 cloud = vec3(0.72, 0.71, 0.66);
    vec3 base = mix(lowlands, highlands, smoothstep(0.38, 0.70, terrain + detail * 0.20));
    base *= 0.78 + detail * 0.28 + micro * 0.12;
    base = mix(base, cloud, storms * 0.26);
    base = mix(base, vec3(0.66, 0.64, 0.58), polar * 0.24);

    float diffuse = clamp(dot(n, normalize(lightDir)), 0.0, 1.0);
    float rim = pow(1.0 - clamp(dot(n, -ray), 0.0, 1.0), 2.1);
    vec3 shaded = base * (0.10 + diffuse * 0.78) + vec3(0.22, 0.32, 0.46) * rim * 0.22;
    color = mix(color, shaded * SPACE_PLANET_BRIGHTNESS, visibility * 0.92);
}
#endif

#if (defined METEORS_OW && METEORS_OW == 1) || (defined END_METEORS && END_METEORS == 1)
vec3 spaceMeteorBaseDir(int id, float seed) {
    float fid = float(id);
    vec3 dir = normalize(vec3(
        spaceHash13(vec3(fid, seed, 1.7)) * 2.0 - 1.0,
        0.06 + spaceHash13(vec3(seed, fid, 4.3)) * 0.92,
        spaceHash13(vec3(8.1, fid, seed)) * 2.0 - 1.0
    ));
    dir.y = max(dir.y, 0.035);
    return normalize(dir);
}

void spaceRenderMeteor(inout vec3 color, vec3 ray, int id, float visibility) {
    float fid = float(id);
    float laneRate = mix(0.80, 1.82, spaceHash13(vec3(fid, 2.7, 9.1)));
    float slotLength = (7.0 + 5.0 * spaceHash13(vec3(fid, 5.4, 1.2))) * SPACE_METEOR_RARITY;
    float meteorClock = frameTimeCounter * laneRate + fid * 19.31;
    float slot = floor(meteorClock / slotLength);
    float seed = slot * (17.0 + fid * 3.1) + fid * 31.17 + floor(frameTimeCounter / 97.0) * 11.3;
    float chance = step(0.52 + 0.18 * spaceHash13(vec3(fid, slot, 6.6)), spaceHash13(vec3(seed, fid, 9.31)));
    float localTime = fract(meteorClock / slotLength);
    float streakTime = localTime * SPACE_METEOR_SPEED * 1.18;
    float pulse = smoothstep(0.025, 0.085, streakTime) * (1.0 - smoothstep(0.78, 1.0, streakTime));
    if (pulse * chance * visibility <= 0.0001) return;

    vec3 baseDir = spaceMeteorBaseDir(id, seed);
    vec3 upSafe = abs(baseDir.y) > 0.82 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    vec3 tangent = normalize(cross(baseDir, upSafe));
    tangent = spaceRotateAxis(tangent, baseDir, (spaceHash13(vec3(seed, fid, 2.2)) - 0.5) * 1.8);
    #ifdef END_SHADER
        tangent = id == 1 || id == 3 || id == 5 || id == 7 ? -tangent : tangent;
    #else
        tangent = id == 0 || id == 3 || id == 6 ? -tangent : tangent;
    #endif

    float travel = mix(-0.90, 1.04, clamp(streakTime, 0.0, 1.0));
    vec3 headDir = normalize(baseDir + tangent * travel);
    float along = dot(ray - headDir, tangent);
    float trailMask = smoothstep(-0.44, -0.035, along) * (1.0 - smoothstep(0.035, 0.13, along));
    float width = mix(0.0060, 0.0145, spaceHash13(vec3(fid, seed, 5.6)));
    float crossDist = length(cross(ray, normalize(headDir + tangent * clamp(along, -0.42, 0.035))));
    float core = exp(-crossDist * 900.0);
    float trail = exp(-crossDist / width) * trailMask;

    #ifdef END_SHADER
        vec3 headCol = vec3(1.35, 0.72, 2.6);
        vec3 tailCol = vec3(0.45, 0.12, 1.35);
        float brightness = 0.85;
    #else
        vec3 headCol = vec3(1.0, 0.92, 0.78);
        vec3 tailCol = vec3(1.0, 0.46, 0.18);
        float brightness = 0.62;
    #endif

    float headConnect = smoothstep(-0.08, 0.02, along) * (1.0 - smoothstep(0.03, 0.11, along));
    color += (headCol * core * (1.45 + headConnect * 0.55) + tailCol * trail * 0.92) * pulse * chance * visibility * brightness;
}

void spaceRenderMeteors(inout vec3 color, vec3 ray, float visibility) {
    if (visibility <= 0.001) return;

    #if SPACE_METEOR_COUNT >= 1
        spaceRenderMeteor(color, ray, 0, visibility);
    #endif
    #if SPACE_METEOR_COUNT >= 2
        spaceRenderMeteor(color, ray, 1, visibility);
    #endif
    #if SPACE_METEOR_COUNT >= 3
        spaceRenderMeteor(color, ray, 2, visibility);
    #endif
    #if SPACE_METEOR_COUNT >= 4
        spaceRenderMeteor(color, ray, 3, visibility);
    #endif
    #if SPACE_METEOR_COUNT >= 5
        spaceRenderMeteor(color, ray, 4, visibility);
    #endif
    #if SPACE_METEOR_COUNT >= 6
        spaceRenderMeteor(color, ray, 5, visibility);
    #endif
    #if SPACE_METEOR_COUNT >= 7
        spaceRenderMeteor(color, ray, 6, visibility);
    #endif
    #if SPACE_METEOR_COUNT >= 8
        spaceRenderMeteor(color, ray, 7, visibility);
    #endif
}
#endif

#if defined END_SHADER && END_BLACK_HOLE == 1
vec3 spaceBlackHoleCenter() {
    return normalize(vec3(0.18, 0.42, -0.89)) * 9.2;
}

bool spacePlanetClearsBlackHole(int id) {
    vec3 planetDir = normalize(spacePlanetCenter(id));
    vec3 bhDir = normalize(spaceBlackHoleCenter());
    float separation = length(cross(planetDir, bhDir));
    return separation > 0.22;
}

vec3 spaceBendRayForBlackHole(vec3 ray) {
    vec3 bhDir = normalize(spaceBlackHoleCenter());
    float distToCenter = length(cross(ray, bhDir));
    float lensingRadius = 0.46 * BLACK_HOLE_SIZE;
    vec3 towardCenter = bhDir - ray * dot(ray, bhDir);
    float towardLen = length(towardCenter);

    if (towardLen < 0.0001) return ray;

    vec3 deflection = towardCenter / towardLen * (0.28 * BLACK_HOLE_LENSING);
    return normalize(ray + deflection * (1.0 - smoothstep(0.0, lensingRadius, distToCenter)));
}

void spaceRenderBlackHole(inout vec3 color, vec3 ray, vec3 lightDir) {
    vec3 ro = vec3(0.0);
    vec3 center = spaceBlackHoleCenter();
    vec3 bhDir = normalize(center);
    float horizonRadius = 0.76 * BLACK_HOLE_SIZE;
    float horizonAngularRadius = horizonRadius / length(center);
    float angularDist = length(cross(ray, bhDir));
    float bhFrontMask = smoothstep(0.02, 0.12, dot(ray, bhDir));
    vec3 diskNormal = normalize(vec3(0.10, 0.58, 0.81));
    vec3 diskSide = normalize(cross(diskNormal, bhDir));
    vec3 diskForward = normalize(cross(diskSide, diskNormal));
    float diskCoordX = dot(ray, diskSide);
    float diskCoordY = dot(ray, diskForward);
    float diskAngle = atan(diskCoordY, diskCoordX);
    float diskFlow = frameTimeCounter * 1.35;
    float swirlWave = 0.5 + 0.5 * sin(diskAngle * 9.0 - diskFlow + angularDist * 74.0);
    float lensGlow = exp(-max(angularDist - horizonAngularRadius * 1.02, 0.0) * 30.0);
    lensGlow *= 1.0 - smoothstep(horizonAngularRadius * 1.02, horizonAngularRadius * 3.05, angularDist);
    lensGlow *= bhFrontMask;
    float blueHalo = exp(-abs(angularDist - horizonAngularRadius * 1.065) * 88.0);
    blueHalo *= bhFrontMask;
    float whiteCorona = exp(-abs(angularDist - horizonAngularRadius * 1.018) * 205.0);
    whiteCorona *= bhFrontMask;
    float movingCorona = 0.72 + 0.38 * swirlWave + 0.16 * sin(diskAngle * 17.0 + diskFlow * 1.7);
    color += vec3(0.06, 0.08, 0.18) * lensGlow * (0.050 + 0.018 * swirlWave);
    color += vec3(0.58, 0.62, 0.72) * blueHalo * 0.20;
    color += vec3(1.0, 0.96, 0.86) * whiteCorona * 1.12 * movingCorona;

    float tDisc;
    vec3 rel;
    float radial;
    if (spaceRayDisc(ro, ray, center, diskNormal, horizonRadius * 1.02, horizonRadius * 4.80, tDisc, rel, radial)) {
        float u = clamp((radial - horizonRadius * 1.02) / (horizonRadius * 3.78), 0.0, 1.0);
        rel = spaceRotateAxis(rel, diskNormal, frameTimeCounter * 0.42 + u * 0.65);
        float angle = atan(rel.z, rel.x) + frameTimeCounter * 0.82;
        float noise = spaceFbm(vec3(rel.xz * 1.65 + vec2(cos(angle), sin(angle)) * 0.48, frameTimeCounter * 0.035));
        float fineNoise = spaceFbm(vec3(rel.zy * 5.0 + vec2(sin(angle), cos(angle)) * 0.35, frameTimeCounter * 0.055));
        float spiral = 0.5 + 0.5 * sin(angle * 4.0 - u * 23.0 + noise * 7.0);
        float ringBand = exp(-abs(u - 0.18) * 7.2) + exp(-abs(u - 0.40) * 10.0) * 0.42 + exp(-abs(u - 0.68) * 8.0) * 0.18;
        float angularDiskMask = 1.0 - smoothstep(horizonAngularRadius * 1.08, horizonAngularRadius * 4.35, angularDist);
        float density = smoothstep(0.0, 0.026, u) * (1.0 - smoothstep(0.78, 1.0, u));
        density *= ringBand;
        density *= 0.58 + 0.46 * spiral;
        density *= 0.55 + 0.46 * noise + fineNoise * 0.16;
        density *= 1.0 - smoothstep(0.00, 0.16, abs(dot(normalize(rel), diskNormal)));
        density *= angularDiskMask;

        vec3 radialDir = normalize(rel);
        vec3 tangent = normalize(cross(diskNormal, radialDir));
        float doppler = 0.48 + 1.22 * smoothstep(-1.0, 1.0, dot(tangent, normalize(vec3(0.88, 0.08, 0.46))));
        float innerHot = exp(-u * 5.7);
        float lowerGlow = smoothstep(-0.65, 0.35, dot(ray, -diskNormal)) * smoothstep(0.02, 0.55, u) * (1.0 - smoothstep(0.55, 1.0, u));

        vec3 innerCol = vec3(1.0, 0.96, 0.84) * 4.2;
        vec3 midCol = vec3(0.92, 0.52, 0.30) * 1.35;
        vec3 outerCol = vec3(0.34, 0.18, 0.13) * 0.54;
        vec3 diskCol = mix(mix(innerCol, midCol, smoothstep(0.06, 0.34, u)), outerCol, smoothstep(0.34, 1.0, u));

        color += diskCol * density * doppler * (0.28 + innerHot * 0.64);
        color += vec3(1.0, 0.42, 0.18) * density * lowerGlow * (0.22 + innerHot * 0.28);
    }

    #if END_BH_JETS == 1
        float jetAxis = abs(dot(ray, diskNormal));
        float jetCenter = pow(max(dot(ray, bhDir), 0.0), 2.0);
        float jetCone = smoothstep(0.965, 0.999, jetAxis) * smoothstep(0.0, 0.20, angularDist);
        color += vec3(0.18, 0.42, 1.0) * jetCone * jetCenter * 0.045;
    #endif

    float tH0;
    float tH1;
    bool hitHorizon = spaceRaySphere(ro, ray, center, horizonRadius, tH0, tH1) && tH0 > 0.0;
    if (hitHorizon) {
        color = vec3(0.0);
    }

    float frontPlane = exp(-abs(dot(ray, diskNormal)) * 82.0);
    float frontRadial = smoothstep(horizonAngularRadius * 0.86, horizonAngularRadius * 1.06, angularDist) * (1.0 - smoothstep(horizonAngularRadius * 1.95, horizonAngularRadius * 2.45, angularDist));
    float frontBias = smoothstep(-0.20, 0.55, dot(ray, -diskNormal));
    float frontBand = frontPlane * frontRadial * frontBias;
    frontBand *= bhFrontMask;
    float frontHot = exp(-max(angularDist - horizonAngularRadius * 1.02, 0.0) * 38.0);
    float frontAnim = 0.78 + 0.32 * swirlWave;
    float sx = diskCoordX / horizonAngularRadius;
    float sy = diskCoordY / horizonAngularRadius;
    float arcRadialMask = smoothstep(horizonAngularRadius * 0.72, horizonAngularRadius * 1.08, angularDist) *
                          (1.0 - smoothstep(horizonAngularRadius * 1.85, horizonAngularRadius * 2.55, angularDist));
    arcRadialMask *= bhFrontMask;
    float accretionBelt = exp(-abs(sy + 0.03) * 2.15) * (1.0 - smoothstep(2.55, 4.35, abs(sx)));
    float beltTexture = 0.74 + 0.26 * sin(sx * 4.8 + diskFlow * 0.72 + spaceFbm(vec3(sx * 0.9, sy * 1.4, frameTimeCounter * 0.04)) * 4.0);
    float frontBeltMask = accretionBelt * smoothstep(0.62, 1.08, angularDist / horizonAngularRadius) *
                          (1.0 - smoothstep(4.0, 5.3, angularDist / horizonAngularRadius));
    frontBeltMask *= bhFrontMask;
    float arcWindow = 1.0 - smoothstep(1.15, 1.82, abs(sx));
    float upperArc = exp(-abs(sy - 0.72) * 4.6) * arcWindow;
    float lowerArc = exp(-abs(sy + 0.78) * 5.4) * (1.0 - smoothstep(0.92, 1.55, abs(sx)));
    float movingArc = 0.80 + 0.28 * sin(diskAngle * 10.0 - diskFlow * 1.6 + angularDist * 42.0);
    color += vec3(1.0, 0.94, 0.84) * frontBand * (0.75 + frontHot * 1.05) * frontAnim;
    color += mix(vec3(1.0, 0.52, 0.18), vec3(1.0, 0.94, 0.72), smoothstep(0.0, 1.25, abs(sx))) * frontBeltMask * beltTexture * 0.74;
    color += vec3(1.0, 0.88, 0.70) * (upperArc * 1.05 + lowerArc * 0.86) * movingArc * arcRadialMask * smoothstep(0.62, 1.18, angularDist / horizonAngularRadius);
    color += vec3(0.62, 0.34, 0.20) * frontBand * smoothstep(horizonAngularRadius * 1.12, horizonAngularRadius * 2.20, angularDist) * 0.38 * frontAnim;

    float photonRing = exp(-abs(angularDist - horizonAngularRadius * 1.032) * 360.0);
    photonRing *= 1.0 - smoothstep(horizonAngularRadius * 1.12, horizonAngularRadius * 1.34, angularDist);
    photonRing *= bhFrontMask;
    float photonRing2 = exp(-abs(angularDist - horizonAngularRadius * 1.12) * 220.0);
    photonRing2 *= 1.0 - smoothstep(horizonAngularRadius * 1.25, horizonAngularRadius * 1.55, angularDist);
    photonRing2 *= bhFrontMask;
    float redCrescent = photonRing2 * smoothstep(-0.55, 0.25, dot(ray, -diskNormal));
    color += vec3(0.98, 0.98, 1.08) * photonRing * 3.2 * movingCorona;
    color += vec3(1.0, 0.48, 0.20) * redCrescent * 0.30 * frontAnim;
}
#else
vec3 spaceBendRayForBlackHole(vec3 ray) {
    return ray;
}
#endif

#ifdef PULSAR
void spaceRenderPulsar(inout vec3 color, vec3 ray, float visibility) {
    #ifdef END_SHADER
        return;
    #endif

    if (visibility * PULSAR_BRIGHTNESS <= 0.0001) return;

    vec3 centerDir = normalize(vec3(0.215, 0.75, 0.90));
    float frontMask = smoothstep(0.0, 0.035, dot(ray, centerDir));
    if (frontMask <= 0.0001) return;

    vec3 upSeed = abs(centerDir.y) > 0.88 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    vec3 tangent = normalize(cross(upSeed, centerDir));
    vec3 bitangent = normalize(cross(centerDir, tangent));
    vec3 offset = ray - centerDir * dot(ray, centerDir);
    vec2 p = vec2(dot(offset, tangent), dot(offset, bitangent));

    float t = frameTimeCounter;
    float erraticAngle = t * 2.7 + sin(t * 5.3) * 1.10 + sin(t * 12.9 + 1.7) * 0.48 + sin(t * 23.0) * 0.19;
    vec2 beamDir = vec2(cos(erraticAngle), sin(erraticAngle));
    vec2 beamNormal = vec2(-beamDir.y, beamDir.x);

    float size = max(PULSAR_SIZE, 0.1);
    float coreRadius = 0.0028 * size;
    float haloRadius = 0.024 * size;
    float dist = length(p);
    float core = exp(-dist / max(coreRadius, 0.0001));
    float hotCenter = exp(-dist * dist / max(coreRadius * coreRadius * 3.5, 0.000001));
    float halo = exp(-dist / max(haloRadius, 0.0001)) * (1.0 - smoothstep(haloRadius * 1.8, haloRadius * 4.0, dist));

    float along = abs(dot(p, beamDir));
    float across = abs(dot(p, beamNormal));
    float beamFlicker = 0.72 + 0.28 * sin(t * 18.0 + sin(t * 4.0) * 4.0);
    float beam = exp(-across / (0.00155 * size)) * (1.0 - smoothstep(0.018 * size, 0.112 * size, along));
    float beamCore = exp(-across / (0.00042 * size)) * (1.0 - smoothstep(0.0, 0.072 * size, along));
    float counterBeam = exp(-across / (0.0024 * size)) * (1.0 - smoothstep(0.030 * size, 0.145 * size, along)) * 0.45;

    float pulse = (0.78 + 0.22 * sin(t * 9.7 + sin(t * 3.1) * 2.0)) * visibility * frontMask * PULSAR_BRIGHTNESS;
    vec3 blue = vec3(0.05, 0.55, 2.6);
    vec3 cyan = vec3(0.42, 1.35, 3.4);
    vec3 whiteHot = vec3(3.0, 3.4, 3.8);

    color += blue * halo * 0.95 * pulse;
    color += cyan * beam * beamFlicker * 1.35 * pulse;
    color += blue * counterBeam * pulse;
    color += whiteHot * (core * 2.4 + hotCenter * 1.9 + beamCore * beamFlicker * 1.5) * pulse;
}
#endif

vec3 renderSpaceObjects(vec3 color, vec3 ray, vec3 lightDir, float planetVisibility) {
    #ifndef END_SHADER
        if (planetVisibility <= 0.001) return color;
    #endif

    vec3 planetRay = ray;

    #if (!defined END_SHADER && defined METEORS_OW && METEORS_OW == 1) || (defined END_SHADER && defined END_METEORS && END_METEORS == 1)
        spaceRenderMeteors(color, ray, planetVisibility);
    #endif

    #if defined PULSAR && !defined END_SHADER
        spaceRenderPulsar(color, ray, planetVisibility);
    #endif

    #if (!defined END_SHADER && defined PLANETS && PLANETS == 1) || (defined END_SHADER && defined END_PLANETS && END_PLANETS == 1)
        if (SPACE_PLANET_BRIGHTNESS > 0.01) {
            #if !defined END_SHADER && defined PLANET_0 && PLANET_0 == 1
                spaceRenderHorizonPlanet(color, ray, lightDir, planetVisibility);
            #endif

        #if (defined END_SHADER && defined END_PLANET_0 && END_PLANET_0 == 1) || (!defined END_SHADER && defined PLANET_0 && PLANET_0 == 1)
            float d0 = length(spacePlanetCenter(0));
        #else
            float d0 = -1.0;
        #endif
        #if (defined END_SHADER && defined END_PLANET_1 && END_PLANET_1 == 1) || (!defined END_SHADER && defined PLANET_1 && PLANET_1 == 1)
            float d1 = length(spacePlanetCenter(1));
        #else
            float d1 = -1.0;
        #endif
        #if (defined END_SHADER && defined END_PLANET_2 && END_PLANET_2 == 1) || (!defined END_SHADER && defined PLANET_2 && PLANET_2 == 1)
            float d2 = length(spacePlanetCenter(2));
        #else
            float d2 = -1.0;
        #endif
        #if (defined END_SHADER && defined END_PLANET_3 && END_PLANET_3 == 1) || (!defined END_SHADER && defined PLANET_3 && PLANET_3 == 1)
            float d3 = length(spacePlanetCenter(3));
        #else
            float d3 = -1.0;
        #endif
        #if (defined END_SHADER && defined END_PLANET_4 && END_PLANET_4 == 1) || (!defined END_SHADER && defined PLANET_4 && PLANET_4 == 1)
            float d4 = length(spacePlanetCenter(4));
        #else
            float d4 = -1.0;
        #endif

        for (int pass = 0; pass < 5; pass++) {
            int id = -1;
            float best = -1.0;

            if (d0 > best) {
                best = d0;
                id = 0;
            }
            if (d1 > best) {
                best = d1;
                id = 1;
            }
            if (d2 > best) {
                best = d2;
                id = 2;
            }
            if (d3 > best) {
                best = d3;
                id = 3;
            }
            if (d4 > best) {
                best = d4;
                id = 4;
            }

            if (id == 0) {
                #if defined END_SHADER && END_BLACK_HOLE == 1
                    if (!spacePlanetClearsBlackHole(0)) {
                        d0 = -1.0;
                        continue;
                    }
                #endif
                spaceBlendPlanet(color, planetRay, lightDir, 0, planetVisibility);
                d0 = -1.0;
            } else if (id == 1) {
                #if defined END_SHADER && END_BLACK_HOLE == 1
                    if (!spacePlanetClearsBlackHole(1)) {
                        d1 = -1.0;
                        continue;
                    }
                #endif
                spaceBlendPlanet(color, planetRay, lightDir, 1, planetVisibility);
                d1 = -1.0;
            } else if (id == 2) {
                #if defined END_SHADER && END_BLACK_HOLE == 1
                    if (!spacePlanetClearsBlackHole(2)) {
                        d2 = -1.0;
                        continue;
                    }
                #endif
                spaceBlendPlanet(color, planetRay, lightDir, 2, planetVisibility);
                d2 = -1.0;
            } else if (id == 3) {
                #if defined END_SHADER && END_BLACK_HOLE == 1
                    if (!spacePlanetClearsBlackHole(3)) {
                        d3 = -1.0;
                        continue;
                    }
                #endif
                spaceBlendPlanet(color, planetRay, lightDir, 3, planetVisibility);
                d3 = -1.0;
            } else if (id == 4) {
                #if defined END_SHADER && END_BLACK_HOLE == 1
                    if (!spacePlanetClearsBlackHole(4)) {
                        d4 = -1.0;
                        continue;
                    }
                #endif
                spaceBlendPlanet(color, planetRay, lightDir, 4, planetVisibility);
                d4 = -1.0;
            }
        }
        }
    #endif

    #if defined END_SHADER && END_BLACK_HOLE == 1
        spaceRenderBlackHole(color, ray, lightDir);
    #endif

    return color;
}

#endif
