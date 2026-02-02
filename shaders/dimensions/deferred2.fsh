#include "/lib/settings.glsl"

uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
	uniform sampler2D dhDepthTex;
	#define dhVoxyDepthTex dhDepthTex
#endif

#ifdef VOXY
	uniform sampler2D vxDepthTexTrans;
	#define dhVoxyDepthTex vxDepthTexTrans
#endif
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex16;
uniform sampler2D colortex17;
uniform vec2 texelSize;


float interleaved_gradientNoise(){
	// vec2 coord = gl_FragCoord.xy + (frameCounter%40000);
	vec2 coord = gl_FragCoord.xy ;
	// vec2 coord = gl_FragCoord.xy;
	float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715)) );
	return noise ;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

	#if RESOURCEPACK_SKY != 0
	/* RENDERTARGETS:2,1 */
	#elif defined VOXY
	/* RENDERTARGETS:2 */
	#endif


void main() {
	bool depthCheck = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x < 1.0;
	#if RESOURCEPACK_SKY != 0
		vec2 texcoord = gl_FragCoord.xy * texelSize;

		gl_FragData[1] = texelFetch(colortex1, ivec2(gl_FragCoord.xy),0);

		if(
			depthCheck
			
			#if defined DISTANT_HORIZONS || defined VOXY
				|| texelFetch(dhVoxyDepthTex, ivec2(gl_FragCoord.xy), 0).x < 1.0
			#endif

		) {
			// doing this for precision reasons, DH does NOT like depth => 1.0
		}else{
			
			#if MAX_COLOR_BUFFERS > 20 || defined VOXY
				vec3 skyColor = texelFetch(colortex17, ivec2(gl_FragCoord.xy),0).rgb;
			#else
				vec3 skyColor = texelFetch(colortex2, ivec2(gl_FragCoord.xy),0).rgb;
			#endif
			skyColor.rgb = max(skyColor.rgb - skyColor.rgb * interleaved_gradientNoise()*0.05, 0.0);

			gl_FragData[1].rgb = skyColor/50.0;
			gl_FragData[1].a = 0.0;

		}
	#endif
	
	#ifdef VOXY
		if(depthCheck) {
	#endif

	#if RESOURCEPACK_SKY != 0 && (MAX_COLOR_BUFFERS < 20 && !defined VOXY)
		gl_FragData[0] = vec4(0.0);
	#else
		gl_FragData[0] = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0);
	#endif

	#ifdef VOXY
		} else {
			gl_FragData[0] = texelFetch(colortex16, ivec2(gl_FragCoord.xy), 0);
		}

	#endif
}