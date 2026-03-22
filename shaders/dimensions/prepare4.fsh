#include "/lib/settings.glsl"

#define ReflectedFog

#include "/lib/SSBOs.glsl"

uniform float skyLightLevelSmooth;
uniform float nightVision;

uniform sampler2D noisetex;

uniform sampler2D colortex1;

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

uniform float frameTime;
uniform int frameCounter;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float eyeAltitude;
uniform vec3 sunVec;
uniform vec3 moonVec;
uniform vec2 texelSize;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewI;
uniform mat4 shadowProjection;
uniform float sunElevation;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
// uniform float far;
uniform ivec2 eyeBrightnessSmooth;
// uniform ivec2 eyeBrightness;
uniform float caveDetection;
uniform int isEyeInWater;
uniform float auroraAmount;

#define LUT

// vec4 lightCol = vec4(lightSourceColor, float(sunElevation > 1e-5)*2-1.);

#include "/lib/util.glsl"
#include "/lib/ROBOBO_sky.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/waterBump.glsl"

#ifdef SMOOTH_SUN_ROTATION
	vec3 WsunVec = WsunVecSmooth;
#else
	vec3 WsunVec = mat3(gbufferModelViewInverse)*sunVec;
#endif
#ifdef CUSTOM_MOON_ROTATION
	vec3 WmoonVec = customMoonVecSSBO;
#else
	#ifdef SMOOTH_MOON_ROTATION
		vec3 WmoonVec = WmoonVecSmooth;
	#else
		vec3 WmoonVec = mat3(gbufferModelViewInverse)*moonVec;
	#endif
#endif
// vec3 WsunVec = normalize(LightDir);

vec3 toShadowSpaceProjected(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    p3 = diagonal3(shadowProjection) * p3 + shadowProjection[3].xyz;

    return p3;
}
float interleaved_gradientNoise_temporal(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y) + 1.0/1.6180339887 * frameCounter);
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter) ;
}
float blueNoise(){
  return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}

#define DHVLFOG
// #define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
// #define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 feetPlayerPos = p * 2. - 1.;
    vec4 viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}

uniform float near;
uniform float dhVoxyFarPlane;
uniform float dhVoxyNearPlane;


#include "/lib/DistantHorizons_projections.glsl"

vec3 DH_toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(dhVoxyProjectionInverse[0].x, dhVoxyProjectionInverse[1].y, dhVoxyProjectionInverse[2].zw);
    vec3 feetPlayerPos = p * 2. - 1.;
    vec4 viewPos = iProjDiag * feetPlayerPos.xyzz + dhVoxyProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}

vec3 DH_toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(dhVoxyProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

// float DH_ld(float dist) {
//     return (2.0 * dhVoxyNearPlane) / (dhVoxyFarPlane + dhVoxyNearPlane - dist * (dhVoxyFarPlane - dhVoxyNearPlane));
// }
// float DH_invLinZ (float lindepth){
// 	return -((2.0*dhVoxyNearPlane/lindepth)-dhVoxyFarPlane-dhVoxyNearPlane)/(dhVoxyFarPlane-dhVoxyNearPlane);
// }

float DH_ld(float dist) {
    return (2.0 * dhVoxyNearPlane) / (dhVoxyFarPlane + dhVoxyNearPlane - dist * (dhVoxyFarPlane - dhVoxyNearPlane));
}
float DH_inv_ld (float lindepth){
	return -((2.0*dhVoxyNearPlane/lindepth)-dhVoxyFarPlane-dhVoxyNearPlane)/(dhVoxyFarPlane-dhVoxyNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}
float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}
#ifdef OVERWORLD_SHADER

	// uniform sampler2D colortex4;
	// uniform sampler2D colortex12;
	// const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadowtex0HW;

	// #undef TRANSLUCENT_COLORED_SHADOWS

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex1HW;
	#endif

	// #define TEST
	#define TIMEOFDAYFOG
	#include "/lib/lightning_stuff.glsl"

	#include "/lib/scene_controller.glsl"


	#define VL_CLOUDS_DEFERRED

	#include "/lib/volumetricClouds.glsl"
	#include "/lib/climate_settings.glsl"
	#include "/lib/overworld_fog.glsl"
	
#endif
#ifdef NETHER_SHADER
	uniform sampler2D colortex4;
	#include "/lib/nether_fog.glsl"
#endif
#ifdef END_SHADER
	uniform sampler2D colortex4;
	#include "/lib/end_fog.glsl"
#endif

vec3 rodSample(vec2 Xi)
{
	float r = sqrt(1.0f - Xi.x*Xi.y);
    float phi = 2 * 3.14159265359 * Xi.y;

    return normalize(vec3(cos(phi) * r, sin(phi) * r, Xi.x)).xzy;
}
//Low discrepancy 2D sequence, integration error is as low as sobol but easier to compute : http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
vec2 R2_samples(float n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

uniform float dayChangeSmooth;
uniform bool worldTimeChangeCheck;

uniform int hideGUI;

#if AURORA_LOCATION > 0
	#include "/lib/aurora.glsl"
#endif

void main() {
/* RENDERTARGETS:4 */

gl_FragData[0] = vec4(0.0);

float mixhistory = 0.06;


#ifdef OVERWORLD_SHADER
////////////////////////////////
/// --- ATMOSPHERE IMAGE --- ///
////////////////////////////////

/// --- Sky only
if (gl_FragCoord.x > 18. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257){
	vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.,1.))/256.,0.0,1.0);
	vec3 viewVector = cartToSphere(p);

	vec2 planetSphere = vec2(0.0);
	vec3 sky = vec3(0.0);
	vec3 skyAbsorb = vec3(0.0);
	
	vec3 mC = vec3(fog_coefficientMieR*1e-6, fog_coefficientMieG*1e-6, fog_coefficientMieB*1e-6);

	#ifdef CUSTOM_MOON_ROTATION
		#if LIGHTNING_SHADOWS > 0
			vec3 WmoonVec = customMoonVec2SSBO;
		#else
			vec3 WmoonVec = customMoonVecSSBO;
		#endif
	#else
		#ifdef SMOOTH_MOON_ROTATION
			vec3 WmoonVec = WmoonVecSmooth;
		#else
			vec3 WmoonVec = normalize(mat3(gbufferModelViewInverse) * moonPosition + gbufferModelViewInverse[3].xyz);
		#endif
		if(dot(-WmoonVec, WsunVec) < 0.9999) WmoonVec = -WmoonVec;
	#endif
	
	sky = calculateAtmosphere((averageSkyColSSBO*2000.0), viewVector, vec3(0.0,1.0,0.0), WsunVec, WmoonVec, planetSphere, skyAbsorb, 10, blueNoise());

	// fade atmosphere conditions for rain away when you pass above the cloud plane.
	float heightRelativeToClouds = clamp(1.0 - max(eyeAltitude - CloudLayer0_height,0.0) / 200.0 ,0.0,1.0);
	if(rainStrength > 0.0) sky = mix(sky, averageSkyColSSBO*2000.0 * (skyAbsorb*0.7+0.3), clamp(1.0 - exp(pow(clamp(-viewVector.y+0.9,0.0,1.0),2) * -5.0),0.0,1.0) * heightRelativeToClouds * rainStrength);
	
	#ifdef AEROCHROME_MODE
		sky *= vec3(0.0, 0.18, 0.35);
	#endif

	gl_FragData[0] = vec4(sky / 4000.0 , 1.0);
  
	if(worldTimeChangeCheck) mixhistory = 1.0;
}

/// --- Sky + clouds + fog 
if (gl_FragCoord.x > 18.+257. && gl_FragCoord.y > 1. && gl_FragCoord.x < 18+257+257.){
	vec2 p = clamp(floor(gl_FragCoord.xy-vec2(18.+257,1.))/256.,0.0,1.0);
	vec3 viewVector = cartToSphere(p);

	vec3 viewPos = mat3(gbufferModelView)*viewVector*1024.0;
	float noise = interleaved_gradientNoise_temporal();

	#ifdef SMOOTH_SUN_ROTATION
		WsunVec = WsunVecSmooth;
	#else
		WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition + gbufferModelViewInverse[3].xyz);// * ( float(sunElevation > 1e-5)*2.0-1.0 );
	#endif

	#ifdef CUSTOM_MOON_ROTATION
		#if LIGHTNING_SHADOWS > 0
			WmoonVec = customMoonVec2SSBO;
		#else
			WmoonVec = customMoonVecSSBO;
		#endif
		vec3 moonColor2 = moonColorSSBO * mix(0.0, 1.0, clamp(WmoonVec.y + 0.05, 0.0, 0.1)/0.1);
		//suncol *= mix(0.0, 1.0, clamp(WmoonVec.y + 0.05, 0.0, 0.1)/0.1);
	#else
		#ifdef SMOOTH_MOON_ROTATION
			WmoonVec = WmoonVecSmooth;
		#else
			WmoonVec = normalize(mat3(gbufferModelViewInverse) * moonPosition + gbufferModelViewInverse[3].xyz);
		#endif
		if(dot(-WmoonVec, WsunVec) < 0.9999) WmoonVec = -WmoonVec;
		vec3 moonColor2 = moonColorSSBO;
	#endif

	vec3 sky = texelFetch(colortex4,ivec2(gl_FragCoord.xy)-ivec2(257,0),0).rgb/150.0;	
	sky = mix(averageSkyCol_CloudsSSBO / 600.0, sky,  pow(clamp(viewVector.y+1.0,0.0,1.0),5.0));
	vec3 suncol = lightSourceColorSSBO;

	#ifdef AMBIENT_LIGHT_ONLY
		suncol = vec3(0.0);
	#endif

	float cloudPlaneDistance = 0.0;
	vec2 cloudDistance = vec2(0.0);

	#ifdef CUSTOM_MOON_ROTATION
		vec3 sunColor2 = sunColorSSBO * smoothstep(0.005, 0.09, length(WmoonVec - WsunVec));
	#else
		vec3 sunColor2 = sunColorSSBO;
	#endif
	
	vec4 volumetricClouds = GetVolumetricClouds(viewPos, vec2(noise, 1.0-noise), WsunVec, WmoonVec, sunColor2*2.5/150.0, moonColor2*2.5/150.0, skyGroundColSSBO/30.0, cloudPlaneDistance, cloudDistance);

	WsunVec = mix(WmoonVec, WsunVec, clamp(float(sunElevation > 1e-5)*2.0-1.0 ,0,1));

	float minimumLightAmount = 0.8*nightVision + 0.05 * mix(MIN_LIGHT_AMOUNT_INSIDE, MIN_LIGHT_AMOUNT, clamp(skyLightLevelSmooth, 0.0, 1.0));
	vec3 indirectLight_fog = skyGroundColSSBO/30.0 + vec3(1.0) * minimumLightAmount;


	vec4 volumetricFog = GetVolumetricFog(viewPos, WsunVec, vec2(noise, 1.0-noise), suncol*2.5/150.0, indirectLight_fog, averageSkyCol_CloudsSSBO/30.0, cloudPlaneDistance);

	#if AURORA_LOCATION > 0
		if (WsunVec.y < 0.0 && volumetricClouds.a > 0.01
		#if AURORA_LOCATION < 2
		 && auroraAmount > 0.001
		#endif
		#ifdef AURORA_MOON
		 && WmoonVec.y < 0.1
		#endif
		#if AURORA_CHANCE < 100
		 && hash_aurora(float(worldDay)) <= 0.01 * float(AURORA_CHANCE)
		#endif
		)
		{
		vec3 aurora = aurora(viewVector, 10, noise, WmoonVec.y, WsunVec.y);

		sky += 2.4 * aurora;
		}
	#endif

	sky = sky * volumetricClouds.a + volumetricClouds.rgb / 5.0;
	sky = sky * volumetricFog.a + volumetricFog.rgb / 5.0;

	gl_FragData[0] = vec4(sky,1.0);

	if(worldTimeChangeCheck) mixhistory = 1.0;
}
#endif

#if defined NETHER_SHADER || defined END_SHADER
	vec2 fogPos = vec2(256.0 - 256.0*0.12,1.0);

	//Sky gradient with clouds
	if (gl_FragCoord.x > (fogPos.x - fogPos.x*0.22) && gl_FragCoord.y > 0.4 && gl_FragCoord.x < 535){
		vec2 p = clamp(floor(gl_FragCoord.xy-fogPos)/256.,-0.2,1.2);
		vec3 viewVector = cartToSphere(p);
		float noise = interleaved_gradientNoise_temporal();

	 	vec3 BackgroundColor = vec3(0.0);

		vec4 VL_Fog = GetVolumetricFog(mat3(gbufferModelView)*viewVector*256.,  noise, 1.0-noise);

		BackgroundColor += VL_Fog.rgb;

	  	gl_FragData[0] = vec4(BackgroundColor*8.0, 1.0);

	}
#endif

#ifdef END_SHADER
	/* ---------------------- TIMER ---------------------- */

	float flash = 0.0;
	float maxWaitTime = 5;

	float Timer = texelFetch(colortex4, ivec2(3,1), 0).x/150.0;
	Timer -= frameTime;

	if(Timer <= 0.0){
		flash = 1.0;

		Timer = pow(hash11(frameCounter), 5) * maxWaitTime;
	}

	vec2 pixelPos0 = vec2(3,1);
	if (gl_FragCoord.x > pixelPos0.x && gl_FragCoord.x < pixelPos0.x + 1 && gl_FragCoord.y > pixelPos0.y && gl_FragCoord.y < pixelPos0.y + 1){
		mixhistory = 1.0;
		gl_FragData[0] = vec4(Timer, 0.0, 0.0, 1.0);
	}

	/* ---------------------- FLASHING ---------------------- */

	vec2 pixelPos1 = vec2(1,1);
	if (gl_FragCoord.x > pixelPos1.x && gl_FragCoord.x < pixelPos1.x + 1 && gl_FragCoord.y > pixelPos1.y && gl_FragCoord.y < pixelPos1.y + 1){
		mixhistory = clamp(4.0 * frameTime,0.0,1.0);
		gl_FragData[0] = vec4(flash, 0.0, 0.0, 1.0);
	}

	/* ---------------------- POSITION ---------------------- */

	vec2 pixelPos2 = vec2(2,1);
	if (gl_FragCoord.x > pixelPos2.x && gl_FragCoord.x < pixelPos2.x + 1 && gl_FragCoord.y > pixelPos2.y && gl_FragCoord.y < pixelPos2.y + 1){
		mixhistory = clamp(500.0 * frameTime,0.0,1.0);

		vec3 LastPos = (texelFetch(colortex4,ivec2(2,1),0).xyz/150.0) * 2.0 - 1.0;
		
		LastPos += (hash31(frameCounter / 50) * 2.0 - 1.0);
		LastPos = LastPos * 0.5 + 0.5;

		if(Timer > maxWaitTime * 0.7 ){ 
			LastPos = vec3(0.0);
		}

		gl_FragData[0] = vec4(LastPos, 1.0);
	}

#endif

//Temporally accumulate sky and light values
vec3 frameHistory = texelFetch(colortex4,ivec2(gl_FragCoord.xy),0).rgb;
vec3 currentFrame = gl_FragData[0].rgb*150.;


gl_FragData[0].rgb = clamp(mix(frameHistory, currentFrame, clamp(mixhistory,0.0,1.0)),0.0,65000.);
}