#version 430 compatibility


#include "/lib/settings.glsl"

#define COLORWHEEL

varying vec4 color;

varying vec2 texcoord;
uniform sampler2D tex;
uniform sampler2D texture;
uniform sampler2D noisetex;

#if defined DISTANT_HORIZONS && DH_CHUNK_FADING > 1
	uniform float far;
#endif

varying float LIGHTNING;
uniform float frameTimeCounter;


//////////////////////////////VOID MAIN//////////////////////////////

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}


void main() {
	#ifdef END_ISLAND_LIGHT
		if (LIGHTNING > 0.0) discard;
		
		vec4 color = texture2D(tex,texcoord.xy);

		vec2 lmcoord;
		float ao;
		vec4 overlayColor;

		clrwl_computeFragment(color, color, lmcoord, ao, overlayColor);
    	color.rgb = mix(color.rgb, overlayColor.rgb, overlayColor.a);


		gl_FragData[0] = color;
		
		// gl_FragData[0] = vec4(texture2D(tex,texcoord.xy).rgb * color.rgb,  texture2DLod(tex, texcoord.xy, 0).a);

		#ifdef Stochastic_Transparent_Shadows
			if(gl_FragData[0].a < blueNoise()) { discard; return;}
		#endif
	#else
		gl_FragData[0] = vec4(0.0);
	#endif
}