#define VOXY_PROGRAM

#include "/lib/settings.glsl"
#include "/lib/blocks.glsl"

layout (location = 0) out vec4 gbuffer_data_0;
layout (location = 1) out vec4 gbuffer_data_1;
layout (location = 2) out vec4 gbuffer_data_2;

vec4 encode (vec3 n, vec2 lightmaps){
	n.xy = n.xy / dot(abs(n), vec3(1.0));
	n.xy = n.z <= 0.0 ? (1.0 - abs(n.yx)) * sign(n.xy) : n.xy;
    vec2 encn = clamp(n.xy * 0.5 + 0.5,-1.0,1.0);
	
    return vec4(encn,vec2(lightmaps.x,lightmaps.y));
}

//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}
float encodeVec2(float x,float y){
    return encodeVec2(vec2(x,y));
}

#if EMISSIVE_TYPE > 0
	#include "/lib/hsv.glsl"

	float getEmission(vec3 Albedo) {
		vec3 hsv = RgbToHsv(Albedo);
		float emissive = smoothstep(0.05, 0.15, hsv.y) * pow(hsv.z, 3.5);
		return emissive * 0.5;
	}
#endif


void voxy_emitFragment(VoxyFragmentParameters parameters) {

    vec4 Albedo;

    Albedo.rgb = parameters.sampledColour.rgb * parameters.tinting.rgb;

    int blockID = int(parameters.customId);

    float SSSAMOUNT = 0.0;

	#if SSS_TYPE
		/////// ----- SSS ON BLOCKS ----- ///////
		// strong
		if (
			blockID == BLOCK_SSS_STRONG || blockID == BLOCK_SAPLING || blockID == BLOCK_AIR_WAVING
		) {
			SSSAMOUNT = 1.0;
		}

		// medium
		if (
			blockID == BLOCK_GROUND_WAVING || blockID == BLOCK_GROUND_WAVING_VERTICAL
			|| blockID == BLOCK_GRASS_SHORT || blockID == BLOCK_GRASS_TALL_UPPER || blockID == BLOCK_GRASS_TALL_LOWER
		) {
			SSSAMOUNT = 0.5;
		}
		if (
			blockID == BLOCK_SSS_WEAK || blockID == BLOCK_SSS_WEAK_2 ||
			blockID == BLOCK_GLOW_LICHEN || blockID == BLOCK_SNOW_LAYERS || blockID == BLOCK_CARPET ||
			blockID == BLOCK_AMETHYST_BUD_MEDIUM || blockID == BLOCK_AMETHYST_BUD_LARGE || blockID == BLOCK_AMETHYST_CLUSTER ||
			blockID == BLOCK_BAMBOO || blockID == BLOCK_SAPLING || blockID == BLOCK_VINE
		) {
			SSSAMOUNT = 0.5;
		}
		
		// low
		#ifdef MISC_BLOCK_SSS
			if(
				blockID == BLOCK_SSS_WEIRD || blockID == BLOCK_GRASS
			){
				SSSAMOUNT = 0.5;
			}
		#endif
	#endif

	float EMISSIVE = 0.0;

	#if EMISSIVE_TYPE > 0
		/////// ----- EMISSIVE STUFF ----- ///////

		// if(vNameTags > 0) EMISSIVE = 0.9;

		// normal block lightsources
		if(blockID >= 100 && blockID < 300) EMISSIVE = 0.5;

		if(blockID == 266 || blockID == 497) EMISSIVE = 0.2; // sculk stuff

		if(blockID == 195) EMISSIVE = 2.3; // glow lichen

		if(blockID == 185) EMISSIVE = 1.5; // crying obsidian

		if(blockID == 105) EMISSIVE = 2.0; // brewing stand
		
		if(blockID == 236) EMISSIVE = 1.0; // respawn anchor

		if(blockID == 101) EMISSIVE = 0.7; // large amethyst bud

		if(blockID == 103) EMISSIVE = 1.0; // amethyst cluster

		if(blockID == 244) EMISSIVE = 1.5; // soul fire

		#ifdef EMISSIVE_ORES
			if(blockID == 502) EMISSIVE = EMISSIVE_ORES_STRENGTH;
		#endif

		EMISSIVE *= getEmission(Albedo.rgb);
	#endif

    Albedo.a = 1.0;
	if(blockID == BLOCK_GROUND_WAVING_VERTICAL || blockID == BLOCK_GRASS_SHORT || blockID == BLOCK_GRASS_TALL_LOWER || blockID == BLOCK_GRASS_TALL_UPPER ) Albedo.a = 0.60;
	if(blockID == BLOCK_AIR_WAVING) Albedo.a = 0.55;

    vec3 normal = vec3(uint((parameters.face>>1)==2), uint((parameters.face>>1)==0), uint((parameters.face>>1)==1)) * (float(int(parameters.face)&1)*2-1);

	if (normal.z<=-0.9) normal.xy = vec2(-0.0000000000001);

    vec4 data1 = clamp( encode(normal, parameters.lightMap), 0.0, 1.0);
    
    gbuffer_data_0 = vec4(encodeVec2(Albedo.x,data1.x),	encodeVec2(Albedo.y,data1.y),	encodeVec2(Albedo.z,data1.z),	encodeVec2(data1.w,Albedo.w));

    gbuffer_data_1 = vec4(0.0, 0.0, SSSAMOUNT, EMISSIVE);

    gbuffer_data_2 = vec4(normal * 0.5 + 0.5, 0.0);

}