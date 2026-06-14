#include "/lib/settings.glsl"

#if defined IS_LPV_ENABLED || defined LPV_ENABLED || defined FIRE_COLOR_CORRECTION
  #extension GL_ARB_shader_image_load_store : enable
#endif

#include "/lib/SSBOs.glsl"

uniform sampler2D colortex7;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex14;
uniform sampler2D colortex15;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;
uniform sampler2D shadowcolor1;

#if !defined IS_IRIS || (defined SHADER_GRASS_SETTING && MC_VERSION < 12101 && !defined SHADER_GRASS_UNSUPPORTED_FIX) || defined EXPLODE_THE_SHADER
  #include "/lib/text_rendering.glsl"
#endif

#if DEBUG_VIEW == debug_CLOUDDEPTHTEX && defined CUMULONIMBUS_LIGHTNING && CUMULONIMBUS > 0
  #extension GL_NV_gpu_shader5 : enable
  #extension GL_ARB_shader_image_load_store : enable

  layout (rgba16f) uniform image2D cloudDepthTex;
#endif

in vec2 texcoord;
flat in int nearSoulBlock_fs;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform float frameTime;
uniform float viewHeight;
uniform float viewWidth;
uniform float aspectRatio;
uniform vec3 relativeEyePosition;

#ifdef PIXELATED
  uniform vec2 view_res;
#endif

uniform int hideGUI;

uniform vec3 previousCameraPosition;
// uniform vec3 cameraPosition;
uniform mat4 gbufferPreviousModelView;
// uniform mat4 gbufferModelViewInverse;
// uniform mat4 gbufferModelView;

#ifdef DROWNING_EFFECT
  uniform float drowningSmooth;
  uniform float currentPlayerAir;
#endif

#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/res_params.glsl"

uniform float near;
uniform float far;
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
float blueNoise(){
  return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}

float convertHandDepth_2(in float depth, bool hand) {
	  if(!hand) return depth;

    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    return ndcDepth * 0.5 + 0.5;
}

#include "/lib/util.glsl"
#include "/lib/projections.glsl"

#include "/lib/gameplay_effects.glsl"

void doCameraGridLines(inout vec3 color, vec2 UV){

  float lineThicknessY = 0.001;
  float lineThicknessX = lineThicknessY/aspectRatio;
  
  float horizontalLines = abs(UV.x-0.33);
  horizontalLines = min(abs(UV.x-0.66), horizontalLines);

  float verticalLines = abs(UV.y-0.33);
  verticalLines = min(abs(UV.y-0.66), verticalLines);

  float gridLines = horizontalLines < lineThicknessX || verticalLines < lineThicknessY ? 1.0 : 0.0;

  if(hideGUI > 0.0) gridLines = 0.0;
  color = mix(color, vec3(1.0),  gridLines);
}

vec3 doMotionBlur(vec2 texcoord, float depth, float noise, bool hand){
  
  const float samples = 4.0;
  vec3 color = vec3(0.0);

  float blurMult = 1.0;
  if(hand) blurMult = 0.0;

	vec3 viewPos = toScreenSpace(vec3(texcoord, depth));
	viewPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);

	vec3 previousPosition = mat3(gbufferPreviousModelView) * viewPos + gbufferPreviousModelView[3].xyz;
  previousPosition = toClipSpace3(previousPosition);

	vec2 velocity = texcoord - previousPosition.xy;
  
  // thank you Capt Tatsu for letting me use these
  velocity /= (1.0 + length(velocity)); // ensure the blurring stays sane where UV is beyond 1.0 or -1.0
  velocity /= (1.0 + frameTime*1000.0 * samples * 0.25); // ensure the blur radius stays roughly the same no matter the framerate or sample count
  velocity *= blurMult * MOTION_BLUR_STRENGTH; // remove hand blur and add user control

  texcoord = texcoord - velocity*(samples*0.5 + noise);

  vec2 screenEdges = 2.0/vec2(viewWidth, viewHeight);

	for (int i = 0; i < int(samples); i++) {

    texcoord += velocity;
    color += texture(colortex7, clamp(texcoord, screenEdges, 1.0-screenEdges)).rgb;

  }

  return color / samples;
}

float doVignette( in vec2 texcoord, in float noise){

  float vignette = 1.0-clamp(1.0-length(texcoord-0.5),0.0,1.0);
  
  // vignette = pow(1.0-pow(1.0-vignette,3),5);
  vignette *= vignette*vignette;
  vignette = 1.0-vignette;
  vignette *= vignette*vignette*vignette*vignette;
  
  // stop banding
  vignette = vignette + vignette*(noise-0.5)*0.01;
  
  return mix(1.0, vignette, VIGNETTE_STRENGTH);
}

#if DEBUG_VIEW == debug_WATERSIM && WATER_INTERACTION == 2
  layout (rgba16f) uniform readonly image2D waveSim2;
#endif

uniform sampler2D radiosity_direct;
uniform sampler2D radiosity_direct_soft;
uniform sampler2D radiosity_handheld;

#if defined OVERWORLD_SHADER
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float sunElevation;
    uniform float moonElevation;
#endif

#if defined END_SHADER && END_BLACK_HOLE == 1
    uniform float blackHoleCenterFocus;
#endif

#if defined OVERWORLD_SHADER
vec2 lensDelta(vec2 uv, vec2 pos) {
    vec2 d = uv - pos;
    d.x *= aspectRatio;
    return d;
}

float lensDisc(vec2 uv, vec2 pos, float radius, float softness) {
    return 1.0 - smoothstep(radius, radius + softness, length(lensDelta(uv, pos)));
}

float lensRing(vec2 uv, vec2 pos, float radius, float width) {
    float d = length(lensDelta(uv, pos));
    return exp(-abs(d - radius) / max(width, 0.0001));
}

float lensAperture(vec2 uv, vec2 pos, float radius, float softness, float blades) {
    vec2 d = lensDelta(uv, pos);
    float a = atan(d.y, d.x);
    float blade = 0.92 + 0.08 * cos(a * blades);
    return 1.0 - smoothstep(radius * blade, radius * blade + softness, length(d));
}

float lensStreak(vec2 uv, vec2 pos, float streakLength, float streakWidth, float angle) {
    vec2 d = lensDelta(uv, pos);
    float s = sin(angle);
    float c = cos(angle);
    d = mat2(c, -s, s, c) * d;
    return exp(-abs(d.y) / streakWidth) * exp(-abs(d.x) / streakLength);
}

void applyLensFlare(inout vec3 color, vec3 lightPos, vec3 lightCol, float noise, float strength, float centerGrowth, float lunarFlare) {
    if (strength > 0.001 && lightPos.z < -0.01) {
        vec3 clipPos = toClipSpace3(lightPos);
        vec2 screenPos = clipPos.xy;

        if (screenPos.x < 0.015 || screenPos.x > 0.985 || screenPos.y < 0.015 || screenPos.y > 0.985) return;

        vec2 centerDelta = (screenPos - 0.5) * vec2(aspectRatio, 1.0);
        float centerDist = length(centerDelta);
        
        float directLook = 1.0 - smoothstep(0.02, 0.22, centerDist);
        if (directLook <= 0.001) return;

        float centerAmount = 1.0 - smoothstep(0.01, 0.30, centerDist);
        float scale = mix(1.0, 1.25, centerAmount * centerGrowth);
        vec2 delta = lensDelta(texcoord, screenPos);
        float dist = length(delta);

        float visibility = 0.0;
        for(int i = 0; i < 16; i++) {
            vec2 offset = circlemap(float(i), 16.0) * 0.0052;
            float d = texture(depthtex1, clamp(screenPos + offset, vec2(0.001), vec2(0.999))).r;
            if (d >= 0.9995) visibility += 1.0 / 16.0;
        }

        visibility = smoothstep(0.16, 0.90, visibility);
        if (visibility <= 0.001) return;

        vec2 axis = 0.5 - screenPos;
        float b = 8.0; 

        vec3 warmWhite = mix(vec3(1.00, 0.96, 0.88), vec3(0.85, 0.92, 1.00), lunarFlare);
        vec3 orangeYel = mix(vec3(1.00, 0.65, 0.10), vec3(0.60, 0.75, 1.00), lunarFlare);
        vec3 redBrown  = mix(vec3(0.80, 0.25, 0.05), vec3(0.25, 0.35, 0.65), lunarFlare);
        vec3 cyanBlue  = mix(vec3(0.15, 0.65, 0.95), vec3(0.55, 0.80, 1.00), lunarFlare);
        vec3 magenta   = mix(vec3(0.85, 0.15, 0.55), vec3(0.45, 0.40, 0.85), lunarFlare);
        vec3 green     = mix(vec3(0.40, 0.85, 0.30), vec3(0.55, 0.85, 0.85), lunarFlare);
        vec3 purpBlue  = mix(vec3(0.50, 0.30, 0.90), vec3(0.35, 0.40, 0.85), lunarFlare);

        float core = exp(-dist * 250.0 / scale) * mix(1.2, 0.6, lunarFlare); 
        float innerHalo = exp(-dist * 80.0 / scale) * mix(0.15, 0.05, lunarFlare);
        float outerHalo = exp(-dist * 30.0 / scale) * mix(0.06, 0.015, lunarFlare);
        float haze = exp(-dist * 8.0 / scale) * mix(0.02, 0.005, lunarFlare);

        float angle = atan(delta.y, delta.x);
        float starBurst = 0.0;
        for(float i = 0.0; i < 4.0; i++) {
            float a = angle + i * 0.785398;
            starBurst += pow(abs(cos(a)), 160.0) * exp(-dist * 40.0 / scale);
        }
        float star = starBurst * mix(0.15, 0.03, lunarFlare);

        #if LENS_FLARE_MODE == 3
        float extraRays = 0.0;
        for(float i = 0.0; i < 8.0; i++) {
            float a = angle + i * 0.392699;
            extraRays += pow(abs(cos(a)), 260.0) * exp(-dist * 28.0 / scale);
        }
        star += extraRays * mix(0.22, 0.045, lunarFlare);
        #endif

        float ring = 0.0;
        vec3 ringCol = orangeYel;
        #if defined SUN_FLARE_RING
        if (lunarFlare < 0.5) {
            float rDist = abs(dist - 0.06 * scale);
            float rInnerDist = abs(dist - 0.045 * scale);
            
            float rNoise = texture(noisetex, texcoord * 1.5 + noise * 0.01).r;
            float rAngle = atan(delta.y, delta.x);
            float rShimmer = pow(abs(cos(rAngle * 12.0 + noise * 3.0)), 3.0);
            float rGlitter = pow(abs(cos(rAngle * 45.0 - noise * 5.0)), 20.0) * exp(-dist * 15.0 / scale);
            
            float ring1 = exp(-rInnerDist * 180.0 / scale) * 0.4;
            float ring2 = rGlitter * 0.5;
            
            ring = (ring1 + ring2) * (0.8 + 0.3 * rNoise);

            vec3 colorA = mix(orangeYel, redBrown, 0.6);
            vec3 colorB = mix(cyanBlue, warmWhite, 0.3);
            vec3 ringRainbow = mix(colorA, colorB, smoothstep(-0.03 * scale, 0.03 * scale, dist - 0.06 * scale));
            
            ringCol = mix(orangeYel, ringRainbow, 0.5);
            ring *= directLook;
        }
        #endif

        vec3 ghostCol = vec3(0.0);
        ghostCol += lensAperture(texcoord, 0.5 + axis *  0.15, 0.015 * scale, 0.003 * scale, b) * cyanBlue * 0.15;
        ghostCol += lensAperture(texcoord, 0.5 + axis *  0.22, 0.035 * scale, 0.004 * scale, b) * purpBlue * 0.08;
        ghostCol += lensAperture(texcoord, 0.5 + axis *  0.35, 0.020 * scale, 0.003 * scale, b) * magenta  * 0.12;
        ghostCol += lensAperture(texcoord, 0.5 + axis *  0.42, 0.010 * scale, 0.002 * scale, b) * warmWhite* 0.18;
        ghostCol += lensAperture(texcoord, 0.5 + axis *  0.55, 0.050 * scale, 0.006 * scale, b) * purpBlue * 0.05;
        ghostCol += lensAperture(texcoord, 0.5 + axis *  0.65, 0.030 * scale, 0.004 * scale, b) * cyanBlue * 0.08;
        ghostCol += lensAperture(texcoord, 0.5 + axis * -0.10, 0.025 * scale, 0.003 * scale, b) * orangeYel* 0.10;
        ghostCol += lensAperture(texcoord, 0.5 + axis * -0.20, 0.040 * scale, 0.005 * scale, b) * magenta  * 0.06;
        ghostCol += lensAperture(texcoord, 0.5 + axis * -0.35, 0.060 * scale, 0.008 * scale, b) * purpBlue * 0.05;
        ghostCol += lensAperture(texcoord, 0.5 + axis * -0.50, 0.120 * scale, 0.015 * scale, b) * cyanBlue * 0.03;

        #if LENS_FLARE_MODE == 2
        if (lunarFlare < 0.75) {
            ghostCol += lensRing(texcoord, 0.5 + axis *  0.72, 0.090 * scale, 0.010 * scale) * cyanBlue  * 0.070;
            ghostCol += lensRing(texcoord, 0.5 + axis *  0.94, 0.155 * scale, 0.018 * scale) * purpBlue  * 0.055;
            ghostCol += lensRing(texcoord, 0.5 + axis * -0.62, 0.135 * scale, 0.020 * scale) * orangeYel * 0.050;
            ghostCol += lensRing(texcoord, 0.5 + axis * -0.82, 0.205 * scale, 0.026 * scale) * magenta   * 0.035;
            ghostCol += lensDisc(texcoord, 0.5 + axis *  0.88, 0.030 * scale, 0.020 * scale) * warmWhite * 0.030;
            ring += lensRing(texcoord, screenPos, 0.105 * scale, 0.010 * scale) * directLook * 0.32;
            ring += lensRing(texcoord, screenPos, 0.165 * scale, 0.018 * scale) * directLook * 0.16;
        }
        #endif

        float horizontal = lensStreak(texcoord, screenPos, 0.45 * scale, 0.0015 * scale, 0.0) * mix(0.12, 0.03, lunarFlare);
        float rayStreaks = 0.0;
        #if LENS_FLARE_MODE == 3
            rayStreaks += lensStreak(texcoord, screenPos, 0.34 * scale, 0.0018 * scale, 1.570796) * mix(0.080, 0.018, lunarFlare);
            rayStreaks += lensStreak(texcoord, screenPos, 0.28 * scale, 0.0014 * scale, 0.785398) * mix(0.060, 0.014, lunarFlare);
            rayStreaks += lensStreak(texcoord, screenPos, 0.28 * scale, 0.0014 * scale, -0.785398) * mix(0.060, 0.014, lunarFlare);
            rayStreaks += lensStreak(texcoord, screenPos, 0.55 * scale, 0.0009 * scale, 0.0) * mix(0.075, 0.018, lunarFlare);
        #endif

        vec3 source = vec3(0.0);
        source += core * warmWhite;
        source += innerHalo * orangeYel;
        source += outerHalo * mix(orangeYel, redBrown, 0.5);
        source += haze * redBrown;
        source += horizontal * mix(warmWhite, cyanBlue, 0.4);
        source += rayStreaks * mix(warmWhite, orangeYel, 0.35);
        source += star * warmWhite;
        source += ring * ringCol;

        vec3 flare = lightCol * (source + ghostCol);
        
        float screenFade  = smoothstep(0.0, 0.08, texcoord.x) * (1.0 - smoothstep(0.92, 1.0, texcoord.x));
        screenFade       *= smoothstep(0.0, 0.08, texcoord.y) * (1.0 - smoothstep(0.92, 1.0, texcoord.y));
        
        color += flare * visibility * directLook * strength * screenFade * mix(0.4, 0.2, lunarFlare);
    }
}
#endif

void main() {
  
  float noise = blueNoise();

  #if defined MOTION_BLUR
    float depth = texture(depthtex0, texcoord*RENDER_SCALE).r;
    bool hand = depth < 0.56;
    float depth2 = convertHandDepth_2(depth, hand);

    vec3 COLOR = doMotionBlur(texcoord, depth2, noise, hand);
  #elif defined PIXELATED
    vec3 COLOR = texelFetch(colortex7, ivec2(gl_FragCoord.xy)-ivec2(mod(gl_FragCoord.xy, PIXELIZATION_STRENGTH)),0).rgb;
  #else
    #ifdef FISHEYE_EFFECT
      vec2 _texcoord = texcoord - vec2(0.5);
      
      float dist = length(_texcoord);
      float dist2 = dist * (1.0 - FISHEYE_STRENGTH * dist * dist);
      
      _texcoord = _texcoord * dist2 / dist;
      
      _texcoord += vec2(0.5);

      vec3 COLOR = texture(colortex7, _texcoord).rgb;
    #else
      vec3 COLOR = texture(colortex7, texcoord).rgb;
    #endif
  #endif
  
  #if defined END_SHADER && END_BLACK_HOLE == 1
  if (black_hole_effect_strength > 0.001) {
    vec3 bhWorldDir = normalize(vec3(0.18, 0.42, -0.89));
    vec3 bhViewDir = mat3(gbufferModelView) * bhWorldDir * 100.0;
    vec3 bhScreen = toClipSpace3(bhViewDir);

    if (bhViewDir.z < 0.0 && bhScreen.x > -0.1 && bhScreen.x < 1.1 && bhScreen.y > -0.1 && bhScreen.y < 1.1) {
      vec2 bhCenterDelta = (bhScreen.xy - vec2(0.5)) * vec2(aspectRatio, 1.0);
      float centerLock = 1.0 - smoothstep(0.010, 0.045, length(bhCenterDelta));
      centerLock = centerLock * centerLock;

      if (centerLock > 0.001) {
        float focusRamp = mix(centerLock * 0.22, centerLock, clamp(blackHoleCenterFocus, 0.0, 1.0));
        float effectStrength = clamp(black_hole_effect_strength, 0.0, 2.0) * focusRamp;
        float zoomAmount = effectStrength * 0.105;

        float t = frameTimeCounter;
        vec2 shake = vec2(
          sin(t * 22.7 + 1.7) * 0.0024 + sin(t * 41.3) * 0.0017 + sin(t * 9.1 + 4.2) * 0.0009,
          cos(t * 18.3 + 2.3) * 0.0024 + cos(t * 37.1) * 0.0017 + cos(t * 11.7 + 0.8) * 0.0009
        ) * effectStrength * (0.35 + 0.65 * clamp(blackHoleCenterFocus, 0.0, 1.0));

        vec2 zoomedUV = mix(texcoord, bhScreen.xy, zoomAmount) + shake;
        zoomedUV = clamp(zoomedUV, vec2(0.001), vec2(0.999));
        COLOR = texture(colortex7, zoomedUV).rgb;
      }
    }
  }
  #endif

  #if defined LOW_HEALTH_EFFECT || defined DAMAGE_TAKEN_EFFECT || defined WATER_ON_CAMERA_EFFECT || defined ON_FIRE_DISTORT_EFFECT || defined FIRE_COLOR_CORRECTION
    // for making the fun, more fun
    applyGameplayEffects(COLOR, texcoord, noise);
  #endif

  #if MAX_COLORS_PER_CHANNEL > 1
    COLOR = floor(COLOR*(MAX_COLORS_PER_CHANNEL-1))/(MAX_COLORS_PER_CHANNEL-1);
  #endif 

  #ifdef FILM_GRAIN
    // basic film grain implementation from https://www.shadertoy.com/view/4sXSWs slightly edited
    float x = (texcoord.x + 4.0 ) * (texcoord.y + 4.0 ) * (frameTimeCounter * 10.0);
    vec3 grain = vec3(mod((mod(x, 13.0) + 1.0) * (mod(x, 123.0) + 1.0), 0.01)-0.005) * FILM_GRAIN_STRENGTH;

    COLOR += grain;
  #endif

  #ifdef DROWNING_EFFECT
    if (currentPlayerAir != -1.0) COLOR *= 0.2 + 0.8*drowningSmooth;
  #endif
  
  #ifdef VIGNETTE
    COLOR *= doVignette(texcoord, noise);
  #endif

  #ifdef CAMERA_GRIDLINES
    doCameraGridLines(COLOR, texcoord);
  #endif

  #if DEBUG_VIEW == debug_SHADOWMAP
    vec2 shadowUV = texcoord * vec2(2.0, 1.0) ;

    // shadowUV -= vec2(0.5,0.0);
    // float zoom = 0.1;
    // shadowUV = ((shadowUV-0.5) - (shadowUV-0.5)*zoom) + 0.5;

    if(shadowUV.x < 1.0 && shadowUV.y < 1.0 && hideGUI == 1) COLOR = texture(shadowcolor1,shadowUV).rgb;
  #endif
  #if DEBUG_VIEW == debug_DEPTHTEX0
    COLOR = vec3(ld(texture(depthtex0, texcoord*RENDER_SCALE).r));
  #endif
  #if DEBUG_VIEW == debug_DEPTHTEX1
    COLOR = vec3(ld(texture(depthtex1, texcoord*RENDER_SCALE).r));
  #endif
  #if DEBUG_VIEW == debug_CLOUDDEPTHTEX && defined CUMULONIMBUS_LIGHTNING && CUMULONIMBUS > 0
    COLOR = imageLoad(cloudDepthTex, ivec2(gl_FragCoord.xy*VL_RENDER_SCALE*RENDER_SCALE)).rgb;
  #endif

  gl_FragColor.rgb = COLOR;

  #if DEBUG_VIEW == debug_WATERSIM && WATER_INTERACTION == 2
    if (hideGUI == 1) {
    gl_FragColor.rgb += vec3(imageLoad(waveSim2, ivec2(gl_FragCoord.xy)*5).x);

    vec2 offsetCoords = vec2(gl_FragCoord.x-840.0, gl_FragCoord.y);
    vec2 waveGradients = vec2(imageLoad(waveSim2, ivec2(offsetCoords)*5).zw);
    vec3 waveNormals = normalize(vec3(waveGradients.x, waveGradients.y, 0.2));
    if (length(waveNormals.xy) > 0.0) gl_FragColor.rgb += waveNormals;
    }
  #endif

  #if defined LENS_FLARE && defined OVERWORLD_SHADER
      float sunFlareStrength = smoothstep(0.015, 0.11, sunElevation);
      float moonFlareStrength = smoothstep(0.015, 0.12, moonElevation) * (1.0 - smoothstep(-0.06, 0.05, sunElevation)) * 0.16;
      applyLensFlare(gl_FragColor.rgb, sunPosition, sunColorBase * 0.000007, noise, sunFlareStrength, 2.5, 0.0);
      applyLensFlare(gl_FragColor.rgb, moonPosition, moonColorBase * 0.0000025, noise, moonFlareStrength, 0.0, 1.0);
  #endif

  #if defined SHADER_GRASS_SETTING && MC_VERSION < 12101 && !defined SHADER_GRASS_UNSUPPORTED_FIX
    const float textSize2 = 4.0;
    beginText(ivec2(gl_FragCoord.xy/textSize2), ivec2(0.05*viewWidth/textSize2, 0.75*viewHeight/textSize2));
    text.fgCol = vec4(1.0, 0.0, 0.0, 1.0);
    printString((_S, _h, _a, _d, _e, _r, _space, _G, _r, _a, _s, _s, _space, _n, _e, _e, _d, _s, _space, _1, _dot, _2, _1, _dot, _1, _space, _o, _r, _space, _h, _i, _g, _h, _e, _r, _exclm));
    printLine();
    printString((_D, _i, _s, _a, _b, _l, _e, _space, _i, _t, _exclm));
    #if MC_VERSION == 12001
      printLine();
      printLine();
      printString((_T, _o, _space, _u, _s, _e, _space, _i, _t, _space, _o, _n, _space, _1, _dot, _2, _0, _dot, _1, _space, _u, _s, _e, _space, _t, _h, _e));
      printLine();
      text.fgCol = vec4(0.0, 1.0, 0.0, 1.0);
      printString((_quote, _E, _c, _l, _i, _p, _s, _e, _space, _S, _h, _a, _d, _e, _r, _space, _G, _r, _a, _s, _s, _space, _C, _o, _m, _p, _a, _t, _quote));
      printLine();
      text.fgCol = vec4(1.0, 0.0, 0.0, 1.0);
      printString((_R, _e, _s, _o, _u, _r, _c, _e, _space, _P, _a, _c, _k, _space, _f, _r, _o, _m, _space, _M, _o, _d, _r, _i, _n, _t, _h, _exclm));
      printLine();
      printLine();
      printString((_A, _d, _d, _i, _t, _i, _o, _n, _a, _l, _l, _y, _space, _e, _n, _a, _b, _l, _e, _space, _t, _h, _e));
      printLine();
      text.fgCol = vec4(1.0, 1.0, 0.0, 1.0);
      printString((_quote, _S, _h, _a, _d, _e, _r, _space, _G, _r, _a, _s, _s, _space, _U, _n, _s, _u, _p, _p, _o, _r, _t, _e, _d, _space, _F, _i, _x, _quote));
      printLine();
      text.fgCol = vec4(1.0, 0.0, 0.0, 1.0);
      printString((_i, _n, _space, _e, _x, _p, _e, _r, _i, _m, _e, _n, _t, _a, _l, _space, _s, _e, _t, _t, _i, _n, _g, _s, _exclm));
    #endif
    endText(gl_FragColor.rgb);
  #endif

  #ifndef IS_IRIS
    gl_FragColor.rgb = vec3(0.0);
    const float textSize = 4.0;
    beginText(ivec2(gl_FragCoord.xy/textSize), ivec2(0.05*viewWidth/textSize, 0.75*viewHeight/textSize));
    text.fgCol = vec4(1.0, 0.0, 0.0, 1.0);
    printString((_O, _p, _t, _i, _F, _i, _n, _e, _space, _d, _o, _e, _s, _space, _n, _o, _t, _space, _s, _u, _p, _p, _o, _r, _t, _space, _E, _c, _l, _i, _p, _s, _e, _exclm));
    printLine();
    printLine();
    printString((_U, _s, _e, _space, _I, _r, _i, _s, _space, _i, _n, _s, _t, _e, _a, _d, _exclm));
    endText(gl_FragColor.rgb);
  #endif

  #ifdef PHOTONICS
    #if DEBUG_VIEW == debug_radiosity_direct
      gl_FragColor.rgb = vec3(texture(radiosity_direct, texcoord).rgb);
    #elif DEBUG_VIEW == debug_radiosity_direct_soft
      gl_FragColor.rgb = vec3(texture(radiosity_direct_soft, texcoord).rgb);
    #elif DEBUG_VIEW == debug_radiosity_handheld
      gl_FragColor.rgb = vec3(texture(radiosity_handheld, texcoord).rgb);
    #elif DEBUG_VIEW == debug_radiosity_GI
      gl_FragColor.rgb = vec3(texture(colortex15, texcoord).rgb);
    #endif
  #endif

  #ifdef EXPLODE_THE_SHADER
    gl_FragColor.rgb = vec3(0.0);
    beginText(ivec2(gl_FragCoord.xy/vec2(6.0, 8.0)), ivec2(0.05*viewWidth/6.0, 0.75*viewHeight/8.0));
    text.fgCol = vec4(1.0, 0.0, 0.0, 1.0);
    printString((_D, _o, _space, _N, _O, _T, _space, _u, _s, _e, _space, _b, _o, _t, _h, _space, _D, _i, _s, _t, _a, _n, _t, _space, _H, _o, _r, _i, _z, _o, _n, _s, _space));
    printLine();
    printString((_a, _n, _d, _space, _V, _o, _x, _y, _space, _t, _o, _g, _e, _t, _h, _e, _r, _exclm));
    printLine();
    printLine();
    printString((_D, _i, _s, _a, _b, _l, _e, _space, _o, _n, _e, _space, _o, _f, _space, _t, _h, _e, _m, _exclm));
    endText(gl_FragColor.rgb);
  #endif
}
