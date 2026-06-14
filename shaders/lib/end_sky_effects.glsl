#ifndef END_SKY_EFFECTS_GLSL
#define END_SKY_EFFECTS_GLSL
#ifdef END_VOID_SPIRAL

float endVoidHash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float endVoidHash21(vec2 p) {
    p = fract(p * vec2(0.1031, 0.1030));
    p += dot(p, p.yx + 33.33);
    return fract((p.x + p.y) * p.x);
}

float endVoidNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = endVoidHash13(vec3(i, 1.0));
    float b = endVoidHash13(vec3(i + vec2(1.0, 0.0), 1.0));
    float c = endVoidHash13(vec3(i + vec2(0.0, 1.0), 1.0));
    float d = endVoidHash13(vec3(i + vec2(1.0, 1.0), 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float endVoidVoxelNoise(vec2 p, float scale) {
    vec2 vp = floor(p * scale) / scale;
    return endVoidHash21(vp);
}

float endVoidFbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 6; i++) {
        v += a * endVoidNoise(p);
        p = rot * p * 2.03 + shift;
        a *= 0.48;
    }
    return v;
}

float endVoidFbmFine(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * endVoidNoise(p);
        p *= 2.1;
        a *= 0.5;
    }
    return v;
}

void renderEndVoidSpiral(inout vec3 color, vec3 ray) {
    float downView = -ray.y;
    if (downView <= 0.0) return;

    vec2 p = ray.xz / max(downView, 0.03);
    float r = length(p);

    float coverage = smoothstep(0.0, 0.03, downView);
    if (coverage <= 0.0) return;

    float t = frameTimeCounter;

    float angle = atan(p.y, p.x);
    float logR = log(max(r, 0.0003));

    float swirl = -t * 0.55 - 10.0 / (r * 4.5 + 0.2);
    float a = angle + swirl;

    float arm1 = sin(a * 2.0 + logR * 6.0);
    float arm2 = sin(a * 4.0 + logR * 10.0 + 1.3);
    float arm3 = sin(a * 3.0 + logR * 8.0  + t * 0.4);
    float arm4 = sin(a * 6.0 + logR * 15.0 - t * 0.2);

    float arms = (arm1 * 0.55 + arm2 * 0.30 + arm3 * 0.35 + arm4 * 0.18);
    arms = 0.5 + 0.5 * arms;
    arms = pow(arms, 1.9);

    vec2 voxelUV = vec2(a * 4.0, logR * 3.0 + t * 0.18);
    float voxel1 = endVoidVoxelNoise(voxelUV, 8.0);
    float voxel2 = endVoidVoxelNoise(voxelUV + vec2(0.5), 16.0);
    float voxelTex = voxel1 * 0.6 + voxel2 * 0.4;

    vec2 flowUV  = vec2(a * 1.6, logR * 2.8 + t * 0.25);
    vec2 flowUV2 = vec2(a * 0.9 - t * 0.05, logR * 1.5 - t * 0.14);
    float flow      = endVoidFbm(flowUV * 2.0);
    float flow2     = endVoidFbm(flowUV2 * 1.4);
    float fineDust  = endVoidFbmFine(flowUV * 6.5 - t * 0.09);
    float microDust = endVoidFbmFine(flowUV * 14.0 + t * 0.06);

    float blackHole = smoothstep(0.0, 0.06, r);
    float centerVoid = smoothstep(0.0, 0.18, r);
    float centerVoid2 = smoothstep(0.0, 0.40, r);

    float innerRing = exp(-pow((r - 0.15) * 8.0, 2.0));
    float midRing   = exp(-pow((r - 0.30) * 4.0, 2.0));

    float coreGlow  = exp(-r * 14.0);
    float corePulse = 0.5 + 0.5 * sin(t * 2.1);
    float innerGlow = exp(-r * 4.5);
    float midGlow   = exp(-r * 2.0);
    float outerFade = 1.0 / (1.0 + r * r * 0.5);
    float edgeSoften = smoothstep(2.8, 0.8, r);

    float density = arms * (0.35 + flow * 0.75 + flow2 * 0.25);
    density *= centerVoid * outerFade * edgeSoften;
    density *= (0.5 + voxelTex * 0.6);
    density += fineDust  * 0.18 * centerVoid2 * outerFade;
    density += microDust * 0.10 * centerVoid2 * outerFade * smoothstep(0.05, 0.3, r);

    float rings  = 0.5 + 0.5 * sin(logR * 11.0 - t * 0.9);
    float rings2 = 0.5 + 0.5 * sin(logR * 5.0  + t * 0.5);
    rings  = smoothstep(0.38, 1.0, rings);
    rings2 = smoothstep(0.45, 1.0, rings2);
    density += rings  * 0.16 * centerVoid * outerFade;
    density += rings2 * 0.08 * centerVoid * outerFade;

    float bandFreq = 22.0;
    float densityBands = 0.5 + 0.5 * sin(logR * bandFreq - t * 1.2 + angle * 0.5);
    densityBands = smoothstep(0.55, 1.0, densityBands);
    density += densityBands * 0.10 * centerVoid * outerFade * arms;

    vec3 absoluteBlack = vec3(0.000, 0.000, 0.000);
    vec3 deepVoid      = vec3(0.002, 0.001, 0.008);
    vec3 shadowPurple  = vec3(0.020, 0.005, 0.045);
    vec3 darkPurple    = vec3(0.06,  0.02,  0.16);
    vec3 deepBlue      = vec3(0.08,  0.04,  0.45);
    vec3 royalBlue     = vec3(0.18,  0.10,  0.85);
    vec3 midPurple     = vec3(0.30,  0.07,  0.55);
    vec3 violet        = vec3(0.52,  0.13,  0.88);
    vec3 magenta       = vec3(0.85,  0.22,  0.82);
    vec3 hotWhite      = vec3(0.85,  0.65,  1.00);
    vec3 dustTint      = vec3(0.22,  0.06,  0.42);

    float armBlend = arms * (0.6 + flow * 0.4);
    vec3 spiralColor = mix(shadowPurple, darkPurple, smoothstep(0.0, 0.25, armBlend));
    spiralColor = mix(spiralColor, midPurple, smoothstep(0.25, 0.55, armBlend));
    spiralColor = mix(spiralColor, violet,    smoothstep(0.55, 0.80, armBlend));
    spiralColor = mix(spiralColor, magenta, pow(max(arms - 0.75, 0.0) * 3.5, 2.0) * flow);

    float blueBand = sin(a * 2.0 + logR * 6.0 + 1.57) * 0.5 + 0.5;
    blueBand = pow(blueBand, 3.0);
    spiralColor = mix(spiralColor, royalBlue, blueBand * 0.50 * arms);

    float interArm = 1.0 - arms;
    interArm = pow(interArm, 2.5);
    spiralColor = mix(spiralColor, absoluteBlack, interArm * 0.65);

    float darken = centerVoid * outerFade * coverage;

    float fogClear = coverage * smoothstep(3.2, 0.18, r);
    color *= mix(1.0, 0.28, fogClear);
    color = mix(color, deepVoid, darken * 0.99);

    color = mix(color, absoluteBlack, interArm * darken * 0.55);

    color = mix(color, absoluteBlack, (1.0 - blackHole) * coverage);

    color += spiralColor * density * coverage * 1.5;

    color += royalBlue * innerRing * blackHole * coverage * 0.80;
    color += violet    * innerRing * blackHole * coverage * 0.35;
    color += deepBlue  * midRing   * coverage * 0.40;

    color += dustTint * fineDust * microDust * 0.12 * centerVoid2 * outerFade * coverage;

    color += violet    * innerGlow * 0.15 * coverage * blackHole;
    color += midPurple * midGlow   * 0.08 * coverage * centerVoid;

    float vignette = smoothstep(0.0, 1.5, r) * (1.0 - smoothstep(1.5, 3.0, r));
    color = mix(color, absoluteBlack, vignette * coverage * 0.25);

    color = mix(color, color * vec3(0.50, 0.32, 0.95), darken * 0.20);
}

#endif

#ifdef END_WANDERING_DRAGONS

float endDragonSegment(vec2 p, vec2 a, vec2 b, float radius) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    return 1.0 - smoothstep(radius, radius * 1.25, length(pa - ba * h));
}

float endDragonSegmentTapered(vec2 p, vec2 a, vec2 b, float radiusA, float radiusB) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    float r = mix(radiusA, radiusB, h);
    return 1.0 - smoothstep(r, r * 1.22, length(pa - ba * h));
}

float endDragonBox(vec2 p, vec2 center, vec2 halfSize, float rot) {
    vec2 d = p - center;
    float c = cos(rot);
    float s = sin(rot);
    d = vec2(d.x * c - d.y * s, d.x * s + d.y * c);
    vec2 q = abs(d) - halfSize;
    float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    return 1.0 - smoothstep(0.0, 0.008, dist);
}

float endDragonTriangle(vec2 p, vec2 a, vec2 b, vec2 c) {
    vec2 v0 = b - a;
    vec2 v1 = c - a;
    vec2 v2 = p - a;
    float den = v0.x * v1.y - v1.x * v0.y;
    float denSafe = abs(den) < 1e-5 ? 1e-5 : den;
    float u = (v2.x * v1.y - v1.x * v2.y) / denSafe;
    float v = (v0.x * v2.y - v2.x * v0.y) / denSafe;
    return step(0.0, u) * step(0.0, v) * step(u + v, 1.0);
}

float endDragonLine(vec2 p, vec2 a, vec2 b, float thickness) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    return 1.0 - smoothstep(thickness, thickness * 1.35, length(pa - ba * h));
}

vec2 endDragonRotate(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void renderEndDragon(inout vec3 color, vec3 ray, vec3 centerDir, vec3 flightDir, float size, float phase, float brightness) {
    float front = dot(ray, centerDir);
    if (front <= 0.0) return;

    vec3 worldUp = vec3(0.0, 1.0, 0.0);
    vec3 upRef = worldUp - centerDir * dot(worldUp, centerDir);
    if (dot(upRef, upRef) < 1e-4) upRef = vec3(0.0, 0.0, 1.0) - centerDir * dot(vec3(0.0, 0.0, 1.0), centerDir);
    upRef = normalize(upRef);
    vec3 rightRef = normalize(cross(upRef, centerDir));

    vec2 p = vec2(dot(ray, rightRef), dot(ray, upRef)) / max(front, 0.08) / size;
    vec2 screenFlight = vec2(dot(flightDir, rightRef), dot(flightDir, upRef) * 0.35);
    float face = screenFlight.x < 0.0 ? -1.0 : 1.0;
    p.x *= face;
    float pitch = clamp(screenFlight.y / max(abs(screenFlight.x) + 0.35, 0.35), -0.22, 0.22);
    p = endDragonRotate(p, -pitch);

    if (abs(p.x) > 2.40 || abs(p.y) > 1.65) return;

    float t = frameTimeCounter;
    float flapCycle  = sin(t * 3.10 + phase);
    float open       = 0.48 + 0.52 * smoothstep(-1.0, 1.0, flapCycle);
    float snap       = smoothstep(0.50, 1.0, flapCycle) * (1.0 - smoothstep(0.90, 1.0, flapCycle));
    float bodyBob    = sin(t * 1.55 + phase) * 0.010;
    float tailWave   = sin(t * 1.95 + phase) * 0.020;
    float tailWave2  = sin(t * 1.95 + phase + 0.75) * 0.018;
    float jawAngle   = smoothstep(-0.85, 0.85, sin(t * 1.3 + phase + 0.4)) * 0.55;

    vec2 hip   = vec2(-0.38, -0.006 + bodyBob);
    vec2 chest = vec2(0.18,   0.026 + bodyBob);

    float torso = endDragonBox(p, vec2(-0.10, 0.010 + bodyBob), vec2(0.315, 0.090), 0.02);
    torso = max(torso, endDragonSegmentTapered(p, hip, chest, 0.108, 0.092));
    torso = max(torso, endDragonBox(p, vec2(-0.11, 0.010 + bodyBob), vec2(0.300, 0.075), 0.00));
    torso = max(torso, endDragonBox(p, vec2(-0.13, -0.063 + bodyBob), vec2(0.245, 0.040), 0.0));

    vec2 nkB = vec2(0.24, 0.058 + bodyBob);
    vec2 nkM = vec2(0.42, 0.088 + bodyBob);
    vec2 nkT = vec2(0.56, 0.110 + bodyBob);
    float neck = endDragonSegmentTapered(p, nkB, nkM, 0.066, 0.053);
    neck = max(neck, endDragonSegmentTapered(p, nkM, nkT, 0.053, 0.044));
    neck = max(neck, endDragonBox(p, mix(nkB, nkM, 0.5), vec2(0.055, 0.047), 0.09));
    neck = max(neck, endDragonBox(p, mix(nkM, nkT, 0.5), vec2(0.046, 0.040), 0.06));

    float headHalf = 0.094;
    float blk      = headHalf * 2.0 / 16.0;

    vec2 headCenter = vec2(nkT.x + headHalf, nkT.y);

    float head = endDragonBox(p, headCenter, vec2(headHalf, headHalf), 0.0);

    float snoutHX = headHalf;
    float snoutHY = 2.5 * blk;
    vec2  snoutCenter = vec2(headCenter.x + headHalf + snoutHX, headCenter.y - 1.5 * blk);
    head = max(head, endDragonBox(p, snoutCenter, vec2(snoutHX, snoutHY), 0.0));

    float jawHX      = headHalf;
    float jawHY      = 2.0 * blk;
    float jawDrop    = jawAngle * jawHX * 0.55;
    vec2  jawCenter  = vec2(snoutCenter.x, headCenter.y - 6.0 * blk - jawDrop * 0.5);
    head = max(head, endDragonBox(p, jawCenter, vec2(jawHX, jawHY + jawDrop * 0.5), -jawAngle * 0.22));

    vec2 scaleL = vec2(headCenter.x - 3.2 * blk, headCenter.y + headHalf + 1.5 * blk);
    vec2 scaleR = vec2(headCenter.x + 3.2 * blk, headCenter.y + headHalf + 1.5 * blk);
    head = max(head, endDragonBox(p, scaleL, vec2(blk, 2.0 * blk), 0.0));
    head = max(head, endDragonBox(p, scaleR, vec2(blk, 2.0 * blk), 0.0));

    float eyeX    = headCenter.x + headHalf - 3.0 * blk;
    float eyeY    = headCenter.y + 0.5 * blk;
    float eye     = endDragonBox(p, vec2(eyeX, eyeY), vec2(0.018, 0.015), 0.0);
    float eyeCore = endDragonBox(p, vec2(eyeX, eyeY), vec2(0.010, 0.009), 0.0);

    float nostrilX = snoutCenter.x + snoutHX - 2.5 * blk;
    float nostril  = endDragonBox(p, vec2(nostrilX, snoutCenter.y + blk), vec2(0.007, 0.005), 0.0);

    vec2 t0 = vec2(-0.44, -0.006 + bodyBob);
    vec2 t1 = vec2(-0.60, -0.036 + bodyBob + tailWave  * 0.30);
    vec2 t2 = vec2(-0.78, -0.068 + bodyBob + tailWave  * 0.55);
    vec2 t3 = vec2(-0.97, -0.104 + bodyBob + tailWave  * 0.80);
    vec2 t4 = vec2(-1.16, -0.144 + bodyBob + tailWave  * 0.92);
    vec2 t5 = vec2(-1.34, -0.178 + bodyBob + tailWave2 * 1.00);
    vec2 t6 = vec2(-1.52, -0.208 + bodyBob + tailWave2 * 0.80);
    float tail = endDragonSegmentTapered(p, t0, t1, 0.076, 0.066);
    tail = max(tail, endDragonSegmentTapered(p, t1, t2, 0.066, 0.055));
    tail = max(tail, endDragonSegmentTapered(p, t2, t3, 0.055, 0.043));
    tail = max(tail, endDragonSegmentTapered(p, t3, t4, 0.043, 0.032));
    tail = max(tail, endDragonSegmentTapered(p, t4, t5, 0.032, 0.022));
    tail = max(tail, endDragonSegmentTapered(p, t5, t6, 0.022, 0.014));
    tail = max(tail, endDragonBox(p, t1, vec2(0.066, 0.050), 0.08));
    tail = max(tail, endDragonBox(p, t3, vec2(0.045, 0.034), 0.16));
    tail = max(tail, endDragonBox(p, t5, vec2(0.026, 0.020), 0.24));
    tail = max(tail, endDragonBox(p, t6, vec2(0.016, 0.013), 0.30));

    float legs = 0.0;
    vec2 lA0 = vec2(-0.25, -0.072 + bodyBob);
    vec2 lA1 = vec2(-0.29, -0.172 + bodyBob - snap * 0.016);
    vec2 lA2 = vec2(-0.23, -0.255 + bodyBob - snap * 0.020);
    vec2 lB0 = vec2(0.12, -0.066 + bodyBob);
    vec2 lB1 = vec2(0.095,-0.164 + bodyBob - snap * 0.014);
    vec2 lB2 = vec2(0.165,-0.240 + bodyBob - snap * 0.017);
    legs = max(legs, endDragonSegmentTapered(p, lA0, lA1, 0.036, 0.028));
    legs = max(legs, endDragonSegmentTapered(p, lA1, lA2, 0.028, 0.019));
    legs = max(legs, endDragonSegmentTapered(p, lB0, lB1, 0.032, 0.025));
    legs = max(legs, endDragonSegmentTapered(p, lB1, lB2, 0.025, 0.017));
    legs = max(legs, endDragonBox(p, lA2 + vec2( 0.036,-0.015), vec2(0.035,0.012), -0.18));
    legs = max(legs, endDragonBox(p, lA2 + vec2( 0.010,-0.025), vec2(0.028,0.010), -0.40));
    legs = max(legs, endDragonBox(p, lA2 + vec2(-0.012,-0.017), vec2(0.022,0.009), -0.60));
    legs = max(legs, endDragonBox(p, lB2 + vec2( 0.034,-0.014), vec2(0.035,0.012), -0.14));
    legs = max(legs, endDragonBox(p, lB2 + vec2( 0.010,-0.022), vec2(0.028,0.010), -0.32));
    legs = max(legs, endDragonBox(p, lB2 + vec2(-0.010,-0.016), vec2(0.022,0.009), -0.50));

    vec2 shoulder = vec2(-0.04, 0.082 + bodyBob);
    float wingLift = 0.30 + 0.32 * open;
    float wingSpan = 0.54 + 0.24 * open;

    vec2 wTE  = shoulder + vec2(-0.30,  wingLift * 0.80);
    vec2 wTT  = shoulder + vec2(-0.68 - wingSpan * 0.34, wingLift + snap * 0.038);
    vec2 wTF1 = wTT     + vec2(-0.22, -0.05);
    vec2 wTF2 = shoulder + vec2(-0.84,  wingLift * 0.48);
    vec2 wTF3 = shoulder + vec2(-0.63,  wingLift * 0.16);
    vec2 wTF4 = shoulder + vec2(-0.38, -0.025);

    vec2 wBE  = shoulder + vec2(-0.27, -wingLift * 0.72);
    vec2 wBT  = shoulder + vec2(-0.60 - wingSpan * 0.27, -wingLift * 0.98 - snap * 0.030);
    vec2 wBF1 = wBT     + vec2(-0.18,  0.05);
    vec2 wBF2 = shoulder + vec2(-0.72, -wingLift * 0.46);
    vec2 wBF3 = shoulder + vec2(-0.52, -wingLift * 0.12);

    float membrane = 0.0;
    membrane = max(membrane, endDragonTriangle(p, shoulder, wTE,  wTF4));
    membrane = max(membrane, endDragonTriangle(p, shoulder, wTF4, wTF3));
    membrane = max(membrane, endDragonTriangle(p, wTE,  wTT,  wTF1));
    membrane = max(membrane, endDragonTriangle(p, wTE,  wTF1, wTF2));
    membrane = max(membrane, endDragonTriangle(p, wTE,  wTF2, wTF3));
    membrane = max(membrane, endDragonTriangle(p, wTE,  wTF3, wTF4));
    membrane = max(membrane, endDragonTriangle(p, shoulder, wBE,  wBF3));
    membrane = max(membrane, endDragonTriangle(p, shoulder, wBF3, wBF2));
    membrane = max(membrane, endDragonTriangle(p, wBE,  wBT,  wBF1));
    membrane = max(membrane, endDragonTriangle(p, wBE,  wBF1, wBF2));
    membrane = max(membrane, endDragonTriangle(p, wBE,  wBF2, wBF3));

    float bones = 0.0;
    bones = max(bones, endDragonLine(p, shoulder, wTE,  0.022));
    bones = max(bones, endDragonLine(p, wTE,  wTT,  0.018));
    bones = max(bones, endDragonLine(p, wTE,  wTF1, 0.014));
    bones = max(bones, endDragonLine(p, wTE,  wTF2, 0.012));
    bones = max(bones, endDragonLine(p, wTE,  wTF3, 0.012));
    bones = max(bones, endDragonLine(p, shoulder, wTF4, 0.013));
    bones = max(bones, endDragonLine(p, wTF1, wTF2, 0.009));
    bones = max(bones, endDragonLine(p, wTF2, wTF3, 0.009));
    bones = max(bones, endDragonLine(p, wTF3, wTF4, 0.009));
    bones = max(bones, endDragonLine(p, shoulder, wBE,  0.020));
    bones = max(bones, endDragonLine(p, wBE,  wBT,  0.017));
    bones = max(bones, endDragonLine(p, wBE,  wBF1, 0.013));
    bones = max(bones, endDragonLine(p, wBE,  wBF2, 0.012));
    bones = max(bones, endDragonLine(p, wBE,  wBF3, 0.012));
    bones = max(bones, endDragonLine(p, wBF1, wBF2, 0.009));
    bones = max(bones, endDragonLine(p, wBF2, wBF3, 0.009));

    float spines = 0.0;
    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        vec2 sp = mix(vec2(-0.45, 0.074), vec2(0.52, 0.170), fi / 9.0);
        sp.y += bodyBob;
        float h = mix(0.014, 0.038, sin(3.14159 * fi / 9.0));
        spines = max(spines, endDragonBox(p, sp + vec2(0.0, h * 0.56), vec2(0.009, h), sin(fi * 0.65) * 0.07));
    }
    spines = max(spines, endDragonBox(p, vec2(0.32, 0.150 + bodyBob), vec2(0.008, 0.022), 0.16));
    spines = max(spines, endDragonBox(p, vec2(0.44, 0.162 + bodyBob), vec2(0.008, 0.020), 0.09));
    spines = max(spines, endDragonBox(p, vec2(0.54, 0.174 + bodyBob), vec2(0.008, 0.018), 0.04));

    float ribs = 0.0;
    ribs = max(ribs, endDragonLine(p, vec2(-0.30, 0.060 + bodyBob), vec2(-0.32, -0.058 + bodyBob), 0.006));
    ribs = max(ribs, endDragonLine(p, vec2(-0.10, 0.072 + bodyBob), vec2(-0.10, -0.063 + bodyBob), 0.006));
    ribs = max(ribs, endDragonLine(p, vec2( 0.07, 0.076 + bodyBob), vec2( 0.09, -0.055 + bodyBob), 0.006));
    ribs = max(ribs, endDragonLine(p, vec2( 0.18, 0.074 + bodyBob), vec2( 0.20, -0.048 + bodyBob), 0.005));

    float bodyParts = max(max(max(torso, neck), head), max(tail, legs));
    bodyParts = max(bodyParts, spines);
    float silhouette = max(bodyParts, membrane);
    float distanceFade = smoothstep(0.0, 0.18, front) * brightness;

    vec3 dragonBlack   = vec3(0.005, 0.004, 0.010);
    vec3 membraneColor = vec3(0.016, 0.012, 0.030);
    vec3 boneColor     = vec3(0.21, 0.17, 0.27);
    vec3 ribColor      = vec3(0.09, 0.07, 0.13);
    vec3 eyeGlow       = vec3(1.25, 0.16, 1.50);
    vec3 endGlow       = vec3(0.34, 0.04, 0.55);

    color = mix(color, dragonBlack,   bodyParts  * distanceFade * 0.98);
    color = mix(color, membraneColor, membrane   * distanceFade * 0.92);
    color = mix(color, boneColor,     bones      * distanceFade * 0.84);
    color = mix(color, ribColor,      ribs       * distanceFade * 0.56);
    color += eyeGlow * eye      * distanceFade * 1.90;
    color += eyeGlow * eyeCore  * distanceFade * 2.40;
    color += eyeGlow * nostril  * distanceFade * 0.40;
    color += endGlow * silhouette * (1.0 - silhouette) * distanceFade * 0.16;
}

vec3 endDragonDirectionAt(float id, float t) {
    float yaw    = t * (0.55 + id * 0.040) + id * 5.80 + 0.50 * sin(t * 0.28 + id * 2.30);
    float pitch  = 0.18 + 0.28 * sin(t * 0.65 + id * 3.10);
    float radius = 0.70 + 0.28 * sin(t * 0.42 + id * 2.80);
    return normalize(vec3(cos(yaw) * radius, pitch, sin(yaw) * radius));
}

vec3 endDragonDirection(float id) {
    float t = frameTimeCounter * 0.055 + id * 6.31;
    return endDragonDirectionAt(id, t);
}

vec3 endDragonFlightDir(float id) {
    float t  = frameTimeCounter * 0.055 + id * 6.31;
    vec3 d0 = endDragonDirectionAt(id, t);
    vec3 d1 = endDragonDirectionAt(id, t + 0.10);
    return normalize(d1 - d0);
}

void renderEndWanderingDragons(inout vec3 color, vec3 ray) {
    renderEndDragon(color, ray, endDragonDirection(0.0), endDragonFlightDir(0.0), 0.040, 0.0, 0.92);
    renderEndDragon(color, ray, endDragonDirection(1.0), endDragonFlightDir(1.0), 0.030, 2.1, 0.80);
    renderEndDragon(color, ray, endDragonDirection(2.0), endDragonFlightDir(2.0), 0.030, 4.4, 0.68);
    renderEndDragon(color, ray, endDragonDirection(3.0), endDragonFlightDir(3.0), 0.024, 6.2, 0.56);
}

#endif

#endif
