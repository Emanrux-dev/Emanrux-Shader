#include "/lib/settings.glsl"

#if RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 2
	in vec4 color;
	
	uniform int renderStage;

	float interleaved_gradientNoise(){
		// vec2 coord = gl_FragCoord.xy + (frameCounter%40000);
		vec2 coord = gl_FragCoord.xy ;
		// vec2 coord = gl_FragCoord.xy;
		float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715)) );
		return noise ;
	}

	vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
	}

#endif


void main() {

	#if RESOURCEPACK_SKY == 1 || RESOURCEPACK_SKY == 2
		#if MAX_COLOR_BUFFERS > 20 || defined VOXY
			/* RENDERTARGETS:17 */
		#else
			/* RENDERTARGETS:2 */
		#endif

		bool isStars = renderStage == MC_RENDER_STAGE_STARS;

		if(!isStars) discard;

		vec4 COLOR = color;

		vec3 NEWCOLOR = COLOR.rgb * 5.0 * STARS_BRIGHTNESS;

		NEWCOLOR.rgb = toLinear(NEWCOLOR.rgb);

		NEWCOLOR.rgb = max(NEWCOLOR.rgb - NEWCOLOR.rgb * interleaved_gradientNoise()*0.05, 0.0);
		
		gl_FragData[0] = vec4(NEWCOLOR.rgb*0.1, COLOR.a);
	#else
		discard;
	#endif
}