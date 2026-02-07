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
uniform sampler2D colortex9;
uniform sampler2D colortex16;


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
	/* RENDERTARGETS:2,1,9 */
	#elif defined VOXY
	/* RENDERTARGETS:2 */
	#endif


void main() {
	bool depthCheck = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x < 1.0;
	#if RESOURCEPACK_SKY != 0
		gl_FragData[1] = texelFetch(colortex1, ivec2(gl_FragCoord.xy),0);

		if(
			depthCheck
			
			#if defined DISTANT_HORIZONS || defined VOXY
				|| texelFetch(dhVoxyDepthTex, ivec2(gl_FragCoord.xy), 0).x < 1.0
			#endif

		) {
			// doing this for precision reasons, DH does NOT like depth => 1.0
		}else{
			
			vec4 skyColor = texelFetch(colortex9, ivec2(gl_FragCoord.xy),0);
			skyColor.rgb *= skyColor.a * 10.0;

			skyColor.rgb = max(skyColor.rgb - skyColor.rgb * interleaved_gradientNoise()*0.05, 0.0);

			gl_FragData[1].rgb = skyColor.rgb/5.0;
			gl_FragData[1].a = 0.0;

		}

		gl_FragData[2] = vec4(0.0);
	#endif
	
	#ifdef VOXY
		if(depthCheck) {
	#endif

	#if RESOURCEPACK_SKY != 0
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