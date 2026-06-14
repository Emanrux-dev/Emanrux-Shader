#version 430 compatibility
#define END_SHADER

#include "/lib/settings.glsl"

#define ENTITIES_SHADOW

in DATA {
	float LIGHTNING;
	vec4 color;
	vec2 texcoord;
};

uniform sampler2D gtexture;
uniform sampler2D noisetex;
uniform int renderStage;

float blueNoise() {
	return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy) % 512, 0).a + 1.0 / 1.6180339887);
}

void main() {
	#ifdef END_ISLAND_LIGHT
		if (LIGHTNING > 0.0) discard;

		vec4 shadowColor = vec4(texture(gtexture, texcoord.xy).rgb * color.rgb, textureLod(gtexture, texcoord.xy, 0).a);
		gl_FragData[0] = shadowColor;

		#ifdef Stochastic_Transparent_Shadows
			if (gl_FragData[0].a < blueNoise() && (renderStage == MC_RENDER_STAGE_ENTITIES || renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES)) {
				discard;
				return;
			}
		#endif
	#else
		gl_FragData[0] = vec4(0.0);
	#endif
}
