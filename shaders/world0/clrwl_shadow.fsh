#version 430 compatibility

#include "/lib/settings.glsl"

varying vec4 color;

varying vec2 texcoord;
uniform sampler2D tex;
uniform sampler2D noisetex;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}

/* RENDERTARGETS: 0 */

void main() {
	vec4 color = texture2D(tex,texcoord.xy);
	vec2 lmcoord;
	float ao;
    vec4 overlayColor;

    clrwl_computeFragment(color, color, lmcoord, ao, overlayColor);
    color.rgb = mix(color.rgb, overlayColor.rgb, overlayColor.a);

	gl_FragData[0] = color;

  	#ifdef Stochastic_Transparent_Shadows
		if(gl_FragData[0].a < blueNoise()) { discard; return;}
  	#endif
}
