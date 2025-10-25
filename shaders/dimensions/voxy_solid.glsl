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


void voxy_emitFragment(VoxyFragmentParameters parameters) {

    vec4 Albedo;

    Albedo.rgb = parameters.sampledColour.rgb * parameters.tinting.rgb;

    int blockID = int(parameters.customId);

    float SSSAMOUNT = 0.0;

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

    Albedo.a = 1.0;

    vec3 normal = vec3(uint((parameters.face>>1)==2), uint((parameters.face>>1)==0), uint((parameters.face>>1)==1)) * (float(int(parameters.face)&1)*2-1);

    vec4 data1 = clamp( encode(normal, parameters.lightMap), 0.0, 1.0);
    
    gbuffer_data_0 = vec4(encodeVec2(Albedo.x,data1.x),	encodeVec2(Albedo.y,data1.y),	encodeVec2(Albedo.z,data1.z),	encodeVec2(data1.w,Albedo.w));

    gbuffer_data_1 = vec4(0.0, 0.0, SSSAMOUNT, 0.0);

    gbuffer_data_2 = vec4(normal * 0.5 + 0.5, 0.0);

}