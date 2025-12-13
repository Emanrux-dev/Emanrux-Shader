#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

#include "/lib/SSBOs.glsl"

#ifdef END_SHADER
	flat varying float Flashing;
#endif

#include "/lib/scene_controller.glsl"

flat varying vec3 WsunVec;
flat varying vec3 WmoonVec;
flat varying vec3 unsigned_WsunVec;

flat varying float exposure;

flat varying vec2 TAA_Offset;
flat varying vec3 zMults;
uniform sampler2D colortex4;

// uniform float far;
uniform float near;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform float rainStrength;
uniform float sunElevation;
uniform int frameCounter;
uniform float frameTimeCounter;

uniform int framemod8;
#include "/lib/TAA_jitter.glsl"



#include "/lib/util.glsl"
#include "/lib/Shadow_Params.glsl"

void main() {
	gl_Position = ftransform();

	#ifdef END_SHADER
		Flashing = texelFetch2D(colortex4,ivec2(1,1),0).x/150.0;
	#endif

	zMults = vec3(1.0/(far * near),far+near,far-near);

	#ifdef SMOOTH_SUN_ROTATION
		unsigned_WsunVec = WsunVecSmooth;
	#else
		unsigned_WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	#endif
	#ifdef CUSTOM_MOON_ROTATION
		vec3 moonVec = customMoonVecSSBO;
		//sunCol *= smoothstep(0.005, 0.09, length(moonVec - unsigned_WsunVec));
	#else
		#ifdef SMOOTH_MOON_ROTATION
			vec3 moonVec = WmoonVecSmooth;
		#else
			vec3 moonVec = normalize(mat3(gbufferModelViewInverse) * moonPosition);
		#endif
		if(dot(-moonVec, unsigned_WsunVec) < 0.9999) moonVec = -moonVec;
	#endif
	
	WmoonVec = moonVec;

	WsunVec = mix(WmoonVec, unsigned_WsunVec, clamp(float(sunElevation > 1e-5)*2.0 - 1.0,0,1));

	#if defined CUSTOM_MOON_ROTATION && LIGHTNING_SHADOWS > 0
		WmoonVec = customMoonVec2SSBO;
	#endif

	#ifdef TAA
		TAA_Offset = offsets[framemod8];
	#else
		TAA_Offset = vec2(0.0);
	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif
}
