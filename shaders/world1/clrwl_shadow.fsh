#version 430 compatibility


#include "/lib/settings.glsl"

#define COLORWHEEL

in vec4 color;
in vec2 texcoord;

uniform sampler2D gtexture;
uniform sampler2D noisetex;

//////////////////////////////VOID MAIN//////////////////////////////

float blueNoise(){
  return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}


void main() {
	#ifdef END_ISLAND_LIGHT
		vec4 color = texture(gtexture,texcoord.xy);

		vec2 lmcoord;
		float ao;
		vec4 overlayColor;

		clrwl_computeFragment(color, color, lmcoord, ao, overlayColor);
    	color.rgb = mix(color.rgb, overlayColor.rgb, overlayColor.a);


		gl_FragData[0] = color;
		
		// gl_FragData[0] = vec4(texture(tex,texcoord.xy).rgb * color.rgb,  textureLod(tex, texcoord.xy, 0).a);

		#ifdef Stochastic_Transparent_Shadows
			if(gl_FragData[0].a < blueNoise()) { discard; return;}
		#endif
	#else
		gl_FragData[0] = vec4(0.0);
	#endif
}