#include "/lib/settings.glsl"
#include "/lib/util.glsl"
#include "/lib/res_params.glsl"

#if defined CUSTOM_MOON_ROTATION && defined OVERWORLD_SHADER
	#include "/lib/SSBOs.glsl"
#endif

#include "/lib/scene_controller.glsl"


out DATA {
	flat vec3 WsunVec;
	flat vec3 WrealSunVec;
	flat vec3 WmoonVec;
};

uniform vec2 texelSize;

uniform sampler2D colortex4;

uniform float sunElevation;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform mat4 gbufferModelViewInverse;
uniform int frameCounter;


uniform int framemod8;
#include "/lib/TAA_jitter.glsl"

uniform float frameTimeCounter;
#include "/lib/Shadow_Params.glsl"
#include "/lib/sky_gradient.glsl"


//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	gl_Position = ftransform();

	gl_Position.xy = (gl_Position.xy*0.5+0.5)*(0.01+VL_RENDER_SCALE)*2.0-1.0;

	float lightSourceCheck = float(sunElevation > 1e-5)*2.0 - 1.0;

	#ifdef OVERWORLD_SHADER
		#ifdef SMOOTH_SUN_ROTATION
			WsunVec = WsunVecSmooth;
		#else
			WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);
		#endif
	
		#ifdef CUSTOM_MOON_ROTATION
			#if LIGHTNING_SHADOWS > 0
				vec3 moonVec = customMoonVec2SSBO;
			#else	
				vec3 moonVec = customMoonVecSSBO;
			#endif
		#else
			#ifdef SMOOTH_MOON_ROTATION
				vec3 moonVec = WmoonVecSmooth;
			#else
				vec3 moonVec = normalize(mat3(gbufferModelViewInverse) * moonPosition);
			#endif
			if(dot(-moonVec, WsunVec) < 0.9999) moonVec = -moonVec;
		#endif

		WmoonVec = moonVec;

		WrealSunVec = WsunVec;
		WsunVec = mix(WmoonVec, WsunVec, clamp(lightSourceCheck,0,1));
	#else
		WmoonVec = vec3(0.0, 1.0, 0.0);
		WsunVec = vec3(0.0, 1.0, 0.0);
		WrealSunVec = vec3(0.0, 1.0, 0.0);
	#endif
}
