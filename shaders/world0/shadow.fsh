#version 430 compatibility

#include "/lib/settings.glsl"

varying vec4 color;

varying vec2 texcoord;
varying vec3 playerpos;
uniform sampler2D tex;
uniform sampler2D texture;
uniform sampler2D noisetex;

#if defined DISTANT_HORIZONS && DH_CHUNK_FADING > 1
	uniform float far;
#endif

in float LIGHTNING;
uniform float frameTimeCounter;

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////


void main() {
	if (LIGHTNING > 0.0) discard;

	#if defined DISTANT_HORIZONS && DH_CHUNK_FADING > 1
		float viewDist = length(playerpos);
		float minDist = min(shadowDistance, far);

		float ditherFade = smoothstep(0.93 * minDist, minDist, viewDist);

		if (step(ditherFade, blueNoise()) == 0.0) discard;
	#endif
	
	vec4 shadowColor = vec4(texture2D(tex,texcoord.xy).rgb * color.rgb,  texture2DLod(tex, texcoord.xy, 0).a);

	#ifdef TRANSLUCENT_COLORED_SHADOWS
		if(shadowColor.a > 0.9999) shadowColor.rgb = vec3(0.0);
	#endif

	gl_FragData[0] = shadowColor;

	// gl_FragData[0] = vec4(texture2D(tex,texcoord.xy).rgb * color.rgb,  texture2DLod(tex, texcoord.xy, 0).a);

  	#ifdef Stochastic_Transparent_Shadows
		if(gl_FragData[0].a < blueNoise()) { discard; return;}
  	#endif
}
