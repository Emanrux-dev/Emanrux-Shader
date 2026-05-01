#extension GL_ARB_shader_texture_lod : enable

#include "/lib/settings.glsl"
#include "/lib/blocks.glsl"
#include "/lib/entities.glsl"
#include "/lib/items.glsl"
#include "/lib/hsv.glsl"

#ifdef IRIS_FEATURE_TEXTURE_FILTERING
#include "/lib/texture_filtering.glsl"
#endif

#ifdef HAND
#undef POM
#endif

#ifndef USE_LUMINANCE_AS_HEIGHTMAP
#ifndef MC_NORMAL_MAP
#undef POM
#endif
#endif

#ifdef POM
#define MC_NORMAL_MAP
#endif


in DATA {
	vec4 color;

	vec4 lmtexcoord;
	vec3 normalMat;

	#ifdef MC_NORMAL_MAP
		vec4 tangent;
	#endif

    vec3 block_normal;
    #if defined IRIS_FEATURE_FADE_VARIABLE && VANILLA_CHUNK_FADING > 0
	float chunkFade;
	#endif
} data_in;

const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

const float MAX_OCCLUSION_DISTANCE = MAX_DIST;
const float MIX_OCCLUSION_DISTANCE = MAX_DIST*0.9;
const int   MAX_OCCLUSION_POINTS   = MAX_ITERATIONS;

uniform vec2 texelSize;
uniform int framemod8;


const vec2 dcdx = vec2(0.0);
const vec2 dcdy = vec2(0.0);

#include "/lib/res_params.glsl"


uniform float far;


#ifdef MC_NORMAL_MAP
	uniform sampler2D normals;
#endif


uniform sampler2D specular;
uniform sampler2D gtexture;
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
uniform float frameTimeCounter;
uniform int frameCounter;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float rainStrength;
uniform sampler2D noisetex;//depth
uniform sampler2D depthtex0;

#if defined VIVECRAFT
	uniform bool vivecraftIsVR;
	uniform vec3 vivecraftRelativeMainHandPos;
	uniform vec3 vivecraftRelativeOffHandPos;
	uniform mat4 vivecraftRelativeMainHandRot;
	uniform mat4 vivecraftRelativeOffHandRot;
#endif

uniform vec4 entityColor;

// in vec3 velocity;

uniform int heldItemId;
uniform int heldItemId2;


uniform float noPuddleAreas;
uniform float nightVision;
uniform vec3 relativeEyePosition;

// float interleaved_gradientNoise(){
// 	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameTimeCounter*51.9521);
// }

float interleaved_gradientNoise_temporal(){
	#ifdef TAA
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887);
	#endif
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
float R2_dither(){
	vec2 coord = gl_FragCoord.xy ;

	#ifdef TAA
		coord += + (frameCounter%40000) * 2.0;
	#endif
	
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

#ifdef TAA
	float blueNoise() {
		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
	} 
#else
	float blueNoise() {
		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887);
	}
#endif

uniform int currentRenderedItemId;


mat3 inverseMatrix(mat3 m) {
  float a00 = m[0][0], a01 = m[0][1], a02 = m[0][2];
  float a10 = m[1][0], a11 = m[1][1], a12 = m[1][2];
  float a20 = m[2][0], a21 = m[2][1], a22 = m[2][2];

  float b01 = a22 * a11 - a12 * a21;
  float b11 = -a22 * a10 + a12 * a20;
  float b21 = a21 * a10 - a11 * a20;

  float det = a00 * b01 + a01 * b11 + a02 * b21;

  return mat3(b01, (-a22 * a01 + a02 * a21), (a12 * a01 - a02 * a11),
              b11, (a22 * a00 - a02 * a20), (-a12 * a00 + a02 * a10),
              b21, (-a21 * a00 + a01 * a20), (a11 * a00 - a01 * a10)) / det;
}

vec3 viewToWorld(vec3 viewPosition) {
    vec4 pos;
    pos.xyz = viewPosition;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}
vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}

vec2 encodeNormal(vec3 n){
	n.xy = n.xy / dot(abs(n), vec3(1.0));
	n.xy = n.z <= 0.0 ? (1.0 - abs(n.yx)) * sign(n.xy) : n.xy;
    vec2 encn = clamp(n.xy * 0.5 + 0.5,-1.0,1.0);
	
    return encn;
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

#ifdef MC_NORMAL_MAP
	vec3 applyBump(mat3 tbnMatrix, vec3 bump){
		float bumpmult = NORMAL_MAP_MULT;
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		return normalize(bump*tbnMatrix);
	}
#endif


#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
vec3 toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}


vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}


const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);


uniform float near;


float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}


// vec4 readNoise(in vec2 coord){
// 	// return texture(noisetex,coord*texcoordam.pq+texcoord);
// 		return textureGradARB(noisetex,coord*texcoordam.pq + texcoordam.st,dcdx,dcdy);
// }
// float EndPortalEffect(
// 	inout vec4 ALBEDO,
// 	vec3 FragPos,
// 	vec3 WorldPos,
// 	mat3 tbnMatrix
// ){	
// 
// 	int maxdist = 25;
// 	int quality = 35;
// 
// 	vec3 viewVec = normalize(tbnMatrix*FragPos);
// 	if ( viewVec.z < 0.0 && length(FragPos) < maxdist) {
// 		float endportalGLow = 0.0;
// 		float Depth = 0.3;
// 		vec3 interval = (viewVec.xyz /-viewVec.z/quality*Depth) * (0.7 + (blueNoise-0.5)*0.1);
// 
// 		vec3 coord = vec3(WorldPos.xz , 1.0);
// 		coord += interval;
// 
// 		for (int loopCount = 0; (loopCount < quality) && (1.0 - Depth + Depth * ( 1.0-readNoise(coord.st).r - readNoise(-coord.st*3).b*0.2 ) ) < coord.p  && coord.p >= 0.0; ++loopCount) {
// 			coord = coord+interval ; 
// 			endportalGLow += (0.3/quality);
// 		}
// 
//   		ALBEDO.rgb = vec3(0.5,0.75,1.0) * sqrt(endportalGLow);
// 
// 		return clamp(pow(endportalGLow*3.5,3),0,1);
// 	}
// }

float bias(){
	// bias mipmapping as window resolution and / or render scale changes.
	#ifdef TAA_UPSCALING
		return (1.0 - texelSize.x * 2560.0) + (0.0 - (1.0-RENDER_SCALE.x) * 2.0);
	#else
		return 1.0 - texelSize.x * 2560.0;
	#endif
}
vec4 texture_POMSwitch(
	sampler2D sampler, 
	vec2 lightmapCoord,
	vec4 dcdxdcdy, 
	bool ifPOM,
	float LOD
){
	{
		return texture(sampler, lightmapCoord, LOD);
	}
}

void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}

float getEmission(vec3 Albedo) {
	vec3 hsv = RgbToHsv(Albedo);
    float emissive = smoothstep(0.05, 0.15, hsv.y) * pow(hsv.z, 3.5);
    return emissive * 0.5;
}

float getTrimEmission(vec3 Albedo) {
	vec3 hsv = RgbToHsv(Albedo);
    return sqrt(hsv.z);
}

uniform float alphaTestRef;

#include "/photonics/photonics.glsl"

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

layout(location = 0) out vec4 OutAlbedo;
layout(location = 1) out vec4 OutSpecular;

/* RENDERTARGETS:1,8 */

void main() {
	vec3 FragCoord = gl_FragCoord.xyz;
	
	bool ifPOM = false;

	bool ShaderGrass = false;

	bool SIGN = false;


	if(SIGN) ifPOM = false;

	vec3 normal = data_in.normalMat;

	#ifdef MC_NORMAL_MAP
		vec3 binormal = normalize(cross(data_in.tangent.rgb,normal)*data_in.tangent.w);
		mat3 tbnMatrix = mat3(data_in.tangent.x, binormal.x, normal.x,
							  data_in.tangent.y, binormal.y, normal.y,
							  data_in.tangent.z, binormal.z, normal.z);
	#endif

	float BN = blueNoise();
	float R2 = R2_dither();

	vec3 fragpos = toScreenSpace(FragCoord*vec3(texelSize/RENDER_SCALE,1.0));
	vec3 playerpos = mat3(gbufferModelViewInverse) * fragpos  + gbufferModelViewInverse[3].xyz;
	vec3 worldpos = playerpos + cameraPosition;

	vec2 adjustedTexCoord = data_in.lmtexcoord.xy;

	float saveDepth = 0.0;

	if(!ifPOM) adjustedTexCoord = data_in.lmtexcoord.xy;
	

	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	ALBEDO		////////////////////////////////
	//////////////////////////////// 				//////////////////////////////// 

	float textureLOD = bias();

	vec2 lmcoord = data_in.lmtexcoord.zw;

	vec4 Color = data_in.color;

    float vanillaAO = 1.0 - clamp(Color.a,0,1);

    // don't fix vanilla ao on some custom block models.
    // if (Color.a < 0.3) Color.a = 1.0; // fix vanilla ao on some custom block models.

    RayJob ray = RayJob(vec3(0), vec3(0), vec3(0), vec3(0), vec3(0), true);

    float normalOffset = mix(0.00015f, 0.025f, clamp(length(playerpos)*0.006, 0.0, 1.0));
    ray.origin = worldpos - world_offset - normalOffset * data_in.block_normal;

    ray.direction = playerpos - gbufferModelViewInverse[3].xyz;
    ray_constraint = ivec3(ray.origin);
    trace_ray(ray);

    if (!ray.result_hit) discard;
    if (ray.result_normal == vec3(0.0)) ray.result_normal = data_in.block_normal;
    int blockID = result_block_id;

    playerpos = ray.result_position + world_offset - cameraPosition;
    vec3 viewPos = (gbufferModelView * vec4(playerpos, 1.0f)).xyz;
    vec4 ndc4 = gbufferProjection * vec4(viewPos, 1.0f);
    vec3 screenPos = ndc4.xyz / ndc4.w * 0.5f + 0.5f;
    gl_FragDepth = screenPos.z;

    normal = normalize(gl_NormalMatrix * ray.result_normal);

    vec4 Albedo = vec4(ray.result_color, 1.0f);


	vec3 flatNormals = viewToWorld(normal);

	float torchlightmap = lmcoord.x;
	
	#ifdef WhiteWorld
		Albedo.rgb = vec3(0.5);
	#endif

    float opaqueMasks = 1.0;

	if(blockID == BLOCK_GROUND_WAVING_VERTICAL || blockID == BLOCK_GRASS_SHORT || blockID == BLOCK_GRASS_TALL_LOWER || blockID == BLOCK_GRASS_TALL_UPPER ) opaqueMasks = 0.60;
	else if(blockID == BLOCK_AIR_WAVING) opaqueMasks = 0.55;

		
	#ifdef AEROCHROME_MODE
		float gray = dot(Albedo.rgb, vec3(0.2, 1.0, 0.07));
		if (
			blockID == BLOCK_AMETHYST_BUD_MEDIUM || blockID == BLOCK_AMETHYST_BUD_LARGE || blockID == BLOCK_AMETHYST_CLUSTER 
			|| blockID == BLOCK_SSS_STRONG || blockID == BLOCK_SSS_STRONG3 || blockID == BLOCK_SSS_WEAK || blockID == BLOCK_CACTUS
			|| blockID == BLOCK_CELESTIUM || blockID == BLOCK_SNOW_LAYERS
			|| blockID >= 10 && blockID < 80
		) {
			// IR Reflective (Pink-red)
			Albedo.rgb = mix(vec3(gray), aerochrome_color, 0.7);
		}
		else if(blockID == BLOCK_GRASS) {
		// Special handling for grass block
			float strength = 1.0 - Color.b;
			Albedo.rgb = mix(Albedo.rgb, aerochrome_color, strength);
		}
		#ifdef AEROCHROME_WOOL_ENABLED
			else if (blockID == BLOCK_SSS_WEAK_2 || blockID == BLOCK_CARPET) {
			// Wool
				Albedo.rgb = mix(Albedo.rgb, aerochrome_color, 0.3);
			}
		#endif
		else if(blockID == BLOCK_WATER || (blockID >= 300 && blockID < 400))
		{
		// IR Absorbsive? Dark.
			Albedo.rgb = mix(Albedo.rgb, vec3(0.01, 0.08, 0.15), 0.5);
		}
	#endif

	Albedo.a = opaqueMasks;

    #if defined IRIS_FEATURE_FADE_VARIABLE && VANILLA_CHUNK_FADING > 0 && !defined HAND
		#ifdef TAA
			if(sqrt(data_in.chunkFade) < BN) discard;
		#else
			if(sqrt(data_in.chunkFade) < R2) discard;
		#endif
	#endif

	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	SPECULAR	////////////////////////////////
	//////////////////////////////// 				//////////////////////////////// 
	
    normal = viewToWorld(normal);

    float SSSAMOUNT = 0.0;
    #if (SSS_TYPE == 1 || SSS_TYPE == 2) && !defined HAND
        #ifdef ENTITIES
            #ifdef MOB_SSS
                /////// ----- SSS ON MOBS----- ///////
                // strong
                if(blockID == ENTITY_SSS_MEDIUM) SSSAMOUNT = 0.75;
        
                // medium
        
                // low
                else if(blockID == ENTITY_SSS_WEAK || blockID == ENTITY_PLAYER || blockID == ENTITY_CURRENT_PLAYER) SSSAMOUNT = 0.4;
            #endif
        #else
            #if defined SHADER_GRASS && !defined CUTOUT
                if (ShaderGrass) SSSAMOUNT = 0.65;
                else
            #endif
    
            /////// ----- SSS ON BLOCKS ----- ///////
            // strong
            if (
                blockID == BLOCK_SSS_STRONG || blockID == BLOCK_SSS_STRONG3 || blockID == BLOCK_AIR_WAVING || blockID == BLOCK_SSS_STRONG_2
            ) {
                SSSAMOUNT = 1.0;
            }
            // medium
            else if (
                blockID == BLOCK_GROUND_WAVING || blockID == BLOCK_GROUND_WAVING_VERTICAL ||
                blockID == BLOCK_GRASS_SHORT || blockID == BLOCK_GRASS_TALL_UPPER || blockID == BLOCK_GRASS_TALL_LOWER ||
                blockID == BLOCK_SSS_WEAK || blockID == BLOCK_CACTUS || blockID == BLOCK_SSS_WEAK_2 ||
                blockID == BLOCK_CELESTIUM || (blockID >= 269 && blockID <= 274) || blockID == BLOCK_SNOW_LAYERS || blockID == BLOCK_CARPET ||
                blockID == BLOCK_AMETHYST_BUD_MEDIUM || blockID == BLOCK_AMETHYST_BUD_LARGE || blockID == BLOCK_AMETHYST_CLUSTER ||
                blockID == BLOCK_BAMBOO || blockID == BLOCK_SAPLING || blockID == BLOCK_VINE || blockID == BLOCK_VINE_OTHER
                #ifdef MISC_BLOCK_SSS
                || blockID == BLOCK_SSS_WEIRD || blockID == BLOCK_GRASS
                #endif
            ) {
                SSSAMOUNT = 0.5;
            }
        #endif
    
        #ifdef BLOCKENTITIES
            /////// ----- SSS ON BLOCK ENTITIES----- ///////
            // strong
    
            // medium
            if(blockID == BLOCK_SSS_WEAK_3) SSSAMOUNT = 0.4;
    
            // low
    
        #endif
    #endif

    float EMISSIVE = 0.0;
    #if EMISSIVE_TYPE == 1 || EMISSIVE_TYPE == 2
        /////// ----- EMISSIVE STUFF ----- ///////

        // if(vNameTags > 0) EMISSIVE = 0.9;

        // normal block lightsources
        if(blockID >= 100 && blockID < 282) {
            EMISSIVE = 0.5;

            if(blockID == 266 || (blockID >= 276 && blockID <= 281)) EMISSIVE = 0.2; // sculk stuff

            else if(blockID == 195) EMISSIVE = 2.3; // glow lichen

            else if(blockID == 185) EMISSIVE = 1.5; // crying obsidian

            else if(blockID == 105) EMISSIVE = 2.0; // brewing stand

            else if(blockID == 236) EMISSIVE = 1.0; // respawn anchor

            else if(blockID == 101) EMISSIVE = 0.7; // large amethyst bud

            else if(blockID == 103) EMISSIVE = 1.0; // amethyst cluster

            else if(blockID == 244) EMISSIVE = 1.5; // soul fire
        }

        #if EMISSIVE_ORES > 0
            if(blockID == 502) {
                EMISSIVE = EMISSIVE_ORES_STRENGTH;

                #ifndef HARDCODED_EMISSIVES_APPROX
                    EMISSIVE *= getEmission(Albedo.rgb);
                #endif
            }
        #endif
    #endif


    vec4 SpecularTex = vec4(0.0);
    // SpecularTex.r = max(SpecularTex.r, rainfall);
    // SpecularTex.g = max(SpecularTex.g, max(Puddle_shape*0.02,0.02));

    OutSpecular = vec4(0.0,0.0,0.0,0.0);
    OutSpecular.rg = SpecularTex.rg;

    #if EMISSIVE_ORES > 1 && EMISSIVE_TYPE > 1
        if(blockID == 502) {
            SpecularTex.a = EMISSIVE_ORES_STRENGTH;
            
            SpecularTex.a *= getEmission(Albedo.rgb);
        }
    #endif


    #if EMISSIVE_TYPE == 2
    bool emissionCheck = SpecularTex.a <= 0.0;
    #endif

    // #ifdef MIRROR_IRON
    // if(blockID == 504 || currentRenderedItemId == 504) {
    //     OutSpecular.rg = vec2(1.0, 1.0);
    //     Albedo.rgb = vec3(1.0);
    // }
    // #endif

    #if defined HARDCODED_EMISSIVES_APPROX && (EMISSIVE_TYPE == 1 || EMISSIVE_TYPE == 2)
        #if EMISSIVE_TYPE == 2
        if(emissionCheck)
        #endif
        {
        EMISSIVE *= getEmission(Albedo.rgb);
        }
    #endif

    #if EMISSIVE_TYPE == 0
        OutSpecular.a = 0.0;
    #endif

    #if EMISSIVE_TYPE == 1
        EMISSIVE = clamp(EMISSIVE, 0.0, 0.99);
        OutSpecular.a = EMISSIVE;
    #endif

    #if EMISSIVE_TYPE == 2
        OutSpecular.a = SpecularTex.a;
        EMISSIVE = clamp(EMISSIVE, 0.0, 0.99);
        if(emissionCheck) OutSpecular.a = EMISSIVE;
    #endif

    #if EMISSIVE_TYPE == 3		
        OutSpecular.a = SpecularTex.a;
    #endif


    #if SSS_TYPE == 0
        OutSpecular.b = 0.0;
    #endif

    #if SSS_TYPE == 1
        OutSpecular.b = SSSAMOUNT;
    #endif

    #if SSS_TYPE == 2
        OutSpecular.b = SpecularTex.b;
        if(SpecularTex.b < 65.0/255.0) OutSpecular.b = SSSAMOUNT;
    #endif

    #if SSS_TYPE == 3		
        OutSpecular.b = SpecularTex.b;
    #endif

	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	FINALIZE	////////////////////////////////
	//////////////////////////////// 				////////////////////////////////

    // apply noise to lightmaps to reduce banding.
    vec2 PackLightmaps = vec2(torchlightmap, lmcoord.y);

    // special curve to give more precision on high/low values of the gradient. this curve will be inverted after sampling and decoding.
    // PackLightmaps = pow(1.0-pow(1.0-PackLightmaps,vec2(0.5)),vec2(0.5));
    
    // some dither to lightmaps to reduce banding.
    PackLightmaps = clamp( PackLightmaps + PackLightmaps * (BN-0.5)*0.005,0,1);


    vec4 data1 = clamp(vec4(encodeNormal(normal), PackLightmaps), 0.0, 1.0);

    Albedo = clamp(Albedo, 0.0, 1.0);

    OutAlbedo = vec4(encodeVec2(Albedo.x,data1.x),	encodeVec2(Albedo.y,data1.y),	encodeVec2(Albedo.z,data1.z),	encodeVec2(data1.w,Albedo.w));

    vec4 otherData = clamp(vec4(flatNormals * 0.5 + 0.5, vanillaAO), 0.0, 1.0);
    OutSpecular = clamp(OutSpecular, 0.0, 1.0);

    OutSpecular = vec4(
        encodeVec2(OutSpecular.x, otherData.x),
        encodeVec2(OutSpecular.y, otherData.y),
        encodeVec2(OutSpecular.z, otherData.z),
        encodeVec2(OutSpecular.w, otherData.w)
    );
}