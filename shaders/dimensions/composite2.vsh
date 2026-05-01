#include "/lib/settings.glsl"

#include "/lib/SSBOs.glsl"

#if defined BorderFog || (defined CUMULONIMBUS_LIGHTNING && CUMULONIMBUS) > 0
	uniform sampler2D colortex4;
	#include "/lib/scene_controller.glsl"
#endif

#ifdef OVERWORLD_SHADER
	out DATA {
	flat vec3 WsunVec;
	flat vec3 WmoonVec;
	};
#endif

uniform float far;
uniform float near;
uniform float dhVoxyFarPlane;
uniform float dhVoxyNearPlane;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float sunElevation;
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

		WsunVec = mix(WmoonVec, WsunVec, clamp(float(sunElevation > 1e-5)*2.0 - 1.0,0,1));
	#endif

	gl_Position = ftransform();
}