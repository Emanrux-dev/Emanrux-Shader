#include "/lib/settings.glsl"

#include "/lib/SSBOs.glsl"

varying vec2 texcoord;
flat varying vec3 zMults;

#if defined BorderFog || (defined CUMULONIMBUS_LIGHTNING && CUMULONIMBUS) > 0
	uniform sampler2D colortex4;
	#include "/lib/scene_controller.glsl"
#endif

flat varying vec3 WsunVec;
flat varying vec3 WmoonVec;

uniform float far;
uniform float near;
uniform float dhVoxyFarPlane;
uniform float dhVoxyNearPlane;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float sunElevation;
flat varying vec2 TAA_Offset;
uniform int framemod8;
#include "/lib/TAA_jitter.glsl"

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	#ifdef OVERWORLD_SHADER
		#ifdef SMOOTH_SUN_ROTATION
			WsunVec = WsunVecSmooth;
		#else
			WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);
		#endif

		#if AURORA_LOCATION > 0
			#ifdef CUSTOM_MOON_ROTATION
				WmoonVec = customMoonVecSSBO;
			#else
				#ifdef SMOOTH_MOON_ROTATION
					WmoonVec = WmoonVecSmooth;
				#else
					WmoonVec = normalize(mat3(gbufferModelViewInverse) * moonPosition);
				#endif
				if(dot(-WmoonVec, WsunVec) < 0.9999) WmoonVec = -WmoonVec;
			#endif
		#endif
	#endif

	#ifdef TAA
		TAA_Offset = offsets[framemod8];
	#else
		TAA_Offset = vec2(0.0);
	#endif
	zMults = vec3(1.0/(far * near),far+near,far-near);

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
}
