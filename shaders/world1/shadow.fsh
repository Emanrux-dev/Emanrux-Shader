#version 430 compatibility

#include "/lib/settings.glsl"

in DATA {
	float LIGHTNING;
	vec4 color;
	vec2 texcoord;
};

uniform sampler2D gtexture;
uniform sampler2D noisetex;

#if defined DISTANT_HORIZONS && DH_CHUNK_FADING > 1
	uniform float far;
#endif

uniform float frameTimeCounter;

uniform int renderStage;


//////////////////////////////VOID MAIN//////////////////////////////

float blueNoise(){
  return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 );
}


void main() {
	#ifdef END_ISLAND_LIGHT
		if (LIGHTNING > 0.0) discard;
		
		vec4 shadowColor = vec4(texture(gtexture,texcoord.xy).rgb * color.rgb,  textureLod(gtexture, texcoord.xy, 0).a);

		// #ifdef TRANSLUCENT_COLORED_SHADOWS
		// 	if(shadowColor.a > 0.9999) shadowColor.rgb = vec3(0.0);
		// #endif


		gl_FragData[0] = shadowColor;
		
		// gl_FragData[0] = vec4(texture(tex,texcoord.xy).rgb * color.rgb,  textureLod(tex, texcoord.xy, 0).a);

		#ifdef Stochastic_Transparent_Shadows
			if(gl_FragData[0].a < blueNoise() && (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT || renderStage == MC_RENDER_STAGE_ENTITIES || renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES)) { discard; return;}
		#endif
	#else
		gl_FragData[0] = vec4(0.0);
	#endif
}
