#extension GL_ARB_shader_texture_lod : enable
#extension GL_ARB_shader_image_load_store : enable
#extension GL_ARB_shading_language_packing : enable

#include "/lib/settings.glsl"
#include "/lib/blocks.glsl"
#include "/lib/entities.glsl"
#include "/lib/items.glsl"
#include "/lib/hsv.glsl"
#include "/lib/SSBOs.glsl"

uniform vec3 cameraPosition;
uniform vec3 relativeEyePosition;
uniform float frameTimeCounter;
uniform int frameCounter;

#ifdef IS_LPV_ENABLED
	uniform sampler3D texLpv1;
	uniform sampler3D texLpv2;
	#include "/lib/lpv_common.glsl"
	#include "/lib/lpv_render.glsl"
	#include "/lib/voxel_common.glsl"
#endif

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

	#if defined IRIS_FEATURE_FADE_VARIABLE && VANILLA_CHUNK_FADING > 0 && !defined HAND
		float chunkFade;
	#endif

	vec4 lmtexcoord;
	vec3 normalMat;

	#if (defined POM && !defined CUTOUT && (defined WORLD && !defined ENTITIES && !defined HAND || defined COLORWHEEL)) || (!defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD && !defined CUTOUT)
		vec4 texcoordam; // .st for add, .pq for mul
	#endif

	#if defined POM && !defined CUTOUT && (defined WORLD && !defined ENTITIES && !defined HAND || defined COLORWHEEL)
		vec2 texcoord;
	#endif

	#ifdef MC_NORMAL_MAP
		vec4 tangent;
	#endif

	flat int blockID;
	vec3 worldPosAbs;
} data_in;

const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

const float MAX_OCCLUSION_DISTANCE = MAX_DIST;
const float MIX_OCCLUSION_DISTANCE = MAX_DIST*0.9;
const int   MAX_OCCLUSION_POINTS   = MAX_ITERATIONS;
const float   MAX_OCCLUSION_POINTS_DIV = 1.0 / MAX_OCCLUSION_POINTS;

uniform vec2 texelSize;
uniform int framemod8;

#if defined POM && !defined CUTOUT && (defined WORLD && !defined ENTITIES && !defined HAND || defined COLORWHEEL)
	vec2 dcdx = dFdx(data_in.texcoord.st*data_in.texcoordam.pq);
	vec2 dcdy = dFdy(data_in.texcoord.st*data_in.texcoordam.pq);
#else
	const vec2 dcdx = vec2(0.0);
	const vec2 dcdy = vec2(0.0);
#endif

#include "/lib/res_params.glsl"


uniform float far;


#ifdef MC_NORMAL_MAP
	uniform sampler2D normals;
#endif


uniform sampler2D specular;
uniform sampler2D gtexture;
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
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

#if defined POM && !defined CUTOUT && (defined WORLD && !defined ENTITIES && !defined HAND || defined COLORWHEEL)
	vec4 readNormal(in vec2 coord)
	{
		return textureGrad(normals,fract(coord)*data_in.texcoordam.pq+data_in.texcoordam.st,dcdx,dcdy);
	}
	vec4 readTexture(in vec2 coord)
	{
		return textureGrad(gtexture,fract(coord)*data_in.texcoordam.pq+data_in.texcoordam.st,dcdx,dcdy);
	}
#endif


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
	#if defined POM && !defined CUTOUT && (defined WORLD && !defined ENTITIES && !defined HAND || defined COLORWHEEL)
	if(ifPOM){
		return textureGrad(sampler, lightmapCoord, dcdxdcdy.xy, dcdxdcdy.zw);
	}else
	#endif
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
#if defined BLOCKENTITIES && !defined COLORWHEEL && (MC_VERSION >= 260100 || !defined SHADER_END_PORTAL)
	mat2 mat2_rotate_z(float radians) {
		return mat2(
			cos(radians), -sin(radians),
			sin(radians), cos(radians)
		);
	}

	const vec3[] COLORS = vec3[](
		vec3(0.022087, 0.098399, 0.110818),
		vec3(0.011892, 0.095924, 0.089485),
		vec3(0.027636, 0.101689, 0.100326),
		vec3(0.046564, 0.109883, 0.114838),
		vec3(0.064901, 0.117696, 0.097189),
		vec3(0.063761, 0.086895, 0.123646),
		vec3(0.084817, 0.111994, 0.166380),
		vec3(0.097489, 0.154120, 0.091064),
		vec3(0.106152, 0.131144, 0.195191),
		vec3(0.097721, 0.110188, 0.187229),
		vec3(0.133516, 0.138278, 0.148582),
		vec3(0.070006, 0.243332, 0.235792),
		vec3(0.196766, 0.142899, 0.214696),
		vec3(0.047281, 0.315338, 0.321970),
		vec3(0.204675, 0.390010, 0.302066),
		vec3(0.080955, 0.314821, 0.661491)
	);

	const mat4 SCALE_TRANSLATE = mat4(
		0.5, 0.0, 0.0, 0.25,
		0.0, 0.5, 0.0, 0.25,
		0.0, 0.0, 1.0, 0.0,
		0.0, 0.0, 0.0, 1.0
	);

	mat4 end_portal_layer(float layer) {
		mat4 translate = mat4(
			1.0, 0.0, 0.0, 17.0 / layer,
			0.0, 1.0, 0.0, (2.0 + layer / 1.5) * (frameTimeCounter * 0.0011),
			0.0, 0.0, 1.0, 0.0,
			0.0, 0.0, 0.0, 1.0
		);

		mat2 rotate = mat2_rotate_z(radians((layer * layer * 4321.0 + layer * 9.0) * 2.0));

		mat2 scale = mat2((4.5 - layer / 4.0) * 2.0);

		return mat4(scale * rotate) * translate * SCALE_TRANSLATE;
	}
#endif
uniform float alphaTestRef;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

layout(location = 0) out vec4 OutAlbedo;
layout(location = 1) out vec4 OutSpecular;

#if defined HAND || defined ENTITIES || defined BLOCKENTITIES
	layout(location = 2) out vec4 OutTranslucents;
	#ifdef VOXY
		layout(location = 3) out vec4 OutTranslucents2;
		/* RENDERTARGETS:1,8,2,7 */
	#else
		/* RENDERTARGETS:1,8,2 */
	#endif
#else
	/* RENDERTARGETS:1,8 */
#endif

void main() {
	vec3 FragCoord = gl_FragCoord.xyz;
        float emissiveMask = 0.0;

	#ifdef HAND
		convertHandDepth(FragCoord.z);
	#endif
	
	#ifdef POM
		bool ifPOM = true;
	#else
		bool ifPOM = false;
	#endif

	#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD && !defined CUTOUT
		bool ShaderGrass = data_in.blockID == -15;
		if(ShaderGrass) ifPOM = false;
	#else
		bool ShaderGrass = false;
	#endif

	bool SIGN = data_in.blockID == BLOCK_SIGN;

	#ifdef ENTITIES
		// disallow POM to work on item frames.
		SIGN = data_in.blockID == ENTITY_ITEM_FRAME;
	#else
		SIGN = data_in.blockID == BLOCK_SIGN;
	#endif

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

	vec2 tempOffset = offsets[framemod8];

	vec3 fragpos = toScreenSpace(FragCoord*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5, 0.0));
	vec3 playerpos = mat3(gbufferModelViewInverse) * fragpos  + gbufferModelViewInverse[3].xyz;
	vec3 worldpos = playerpos + cameraPosition;

	vec2 adjustedTexCoord = data_in.lmtexcoord.xy;

	float saveDepth = 0.0;
#if defined POM && !defined CUTOUT && (defined WORLD && !defined ENTITIES && !defined HAND || defined COLORWHEEL)

	vec3 viewVector = normalize(tbnMatrix*fragpos);
	float dist = length(playerpos);

	float falloff = min(max(1.0-dist/MAX_OCCLUSION_DISTANCE,0.0) * 2.0,1.0);
	falloff = pow(1.0-pow(1.0-falloff,1.0),2.0);

	float maxdist = MAX_OCCLUSION_DISTANCE;
	if(!ifPOM) maxdist = 0.0;

	#if defined DEPTH_WRITE_POM
		gl_FragDepth = gl_FragCoord.z;
	#endif

	#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD && !defined CUTOUT
	 if (falloff > 0.0 && !ShaderGrass)
	#else
	 if (falloff > 0.0)
	#endif
	{
		bool isLumBlock = (data_in.blockID == 196 || data_in.blockID == 511 || data_in.blockID == 519 || data_in.blockID == 520 || data_in.blockID == 521 || data_in.blockID == 508 || data_in.blockID == 515 || data_in.blockID == 503 || data_in.blockID == 502 ||  data_in.blockID == 507 || data_in.blockID == 185 || data_in.blockID == 509 || data_in.blockID == 218 || data_in.blockID == 506);

		float depthmap;
		if(isLumBlock) {
			vec4 albedoSample = readTexture(data_in.texcoord.st);
			float lum = dot(albedoSample.rgb, vec3(0.299, 0.587, 0.114));
			float lumMin = 0.0;
			float lumMax = 1.0;
			lum = clamp((lum - lumMin) / max(lumMax - lumMin, 0.001), 0.0, 1.0);
			lum = pow(lum, 0.5);
			depthmap = (data_in.blockID == 515) ? lum : 1.0 - lum;
		} else {
			depthmap = readNormal(data_in.texcoord.st).a;
		}

		float pomdepth = POM_DEPTH * falloff;
		if(isLumBlock) pomdepth = min(pomdepth, 0.12);
		else           pomdepth = min(pomdepth, 0.20);

		if(depthmap > 0.995 || depthmap < 0.005) {
			adjustedTexCoord = mix(
				fract(data_in.texcoord.st) * data_in.texcoordam.pq + data_in.texcoordam.st,
				adjustedTexCoord,
				max(dist - MIX_OCCLUSION_DISTANCE, 0.0) / (MAX_OCCLUSION_DISTANCE - MIX_OCCLUSION_DISTANCE)
			);
		} else if(viewVector.z < 0.0) {

			vec3 clampedView = viewVector;
			clampedView.z = min(clampedView.z, -0.3);

			vec3 interval = clampedView.xyz / -clampedView.z * MAX_OCCLUSION_POINTS_DIV * pomdepth;
			
			vec3 coord = vec3(data_in.texcoord.st, 1.0);
			float sumVec = 0.0;

			for(int loopCount = 0; loopCount < MAX_OCCLUSION_POINTS && (1.0 - pomdepth + pomdepth * (isLumBlock ? (1.0 - dot(readTexture(coord.st).rgb, vec3(0.299, 0.587, 0.114))) : readNormal(coord.st).a)) < coord.p && coord.p >= 0.0; ++loopCount) {
				coord += interval;
				sumVec += 1.0;
			}

			if(sumVec > 0.0 && sumVec < float(MAX_OCCLUSION_POINTS)) {
				float afterDepth  = (1.0 - pomdepth + pomdepth * (isLumBlock ? (1.0 - dot(readTexture(coord.st).rgb, vec3(0.299, 0.587, 0.114))) : readNormal(coord.st).a)) - coord.p;
				vec2 prevCoord = coord.st - interval.xy;
				float beforeDepth = (coord.p - interval.z) - (1.0 - pomdepth + pomdepth * (isLumBlock ? (1.0 - dot(readTexture(prevCoord).rgb, vec3(0.299, 0.587, 0.114))) : readNormal(prevCoord).a));

				float weight = clamp(afterDepth / (afterDepth + beforeDepth), 0.0, 1.0);
				coord.st = mix(coord.st, prevCoord, weight);
				sumVec -= weight;
			}

			adjustedTexCoord = mix(
				fract(coord.st) * data_in.texcoordam.pq + data_in.texcoordam.st,
				adjustedTexCoord,
				max(dist - MIX_OCCLUSION_DISTANCE, 0.0) / (MAX_OCCLUSION_DISTANCE - MIX_OCCLUSION_DISTANCE)
			);

			#if defined DEPTH_WRITE_POM
				vec3 truePos = fragpos + sumVec * inverseMatrix(tbnMatrix) * interval;
				gl_FragDepth = toClipSpace3(truePos).z;
			#endif
		}
	}

#endif
	if(!ifPOM) adjustedTexCoord = data_in.lmtexcoord.xy;

	float opaqueMasks = 1.0;

	#ifdef HAND
		opaqueMasks = 0.75;
	#else
		#if defined WORLD && !defined ENTITIES
			if(data_in.blockID == BLOCK_GROUND_WAVING_VERTICAL || data_in.blockID == BLOCK_GRASS_SHORT || data_in.blockID == BLOCK_GRASS_TALL_LOWER || data_in.blockID == BLOCK_GRASS_TALL_UPPER ) opaqueMasks = 0.60;
			else if(data_in.blockID == BLOCK_AIR_WAVING) opaqueMasks = 0.55;
		#endif

		#if defined ENTITIES
			opaqueMasks = 0.45;
		#endif

		#if !defined BLOCKENTITIES && !defined ENTITIES && defined SHADER_GRASS && !defined COLORWHEEL && !defined HAND && !defined CUTOUT
			if(ShaderGrass) opaqueMasks = 0.8;
		#endif
	#endif
	

	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	ALBEDO		////////////////////////////////
	//////////////////////////////// 				//////////////////////////////// 

	float textureLOD = bias();

	vec2 lmcoord = data_in.lmtexcoord.zw;

	vec4 Color = data_in.color;

	#ifndef COLORWHEEL
		float vanillaAO = 1.0 - clamp(Color.a,0,1);

		vec4 Albedo = vec4(Color.rgb, 1.0);
		
		#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && defined WORLD && !defined CUTOUT
		if (!ShaderGrass)
		#endif
		{
		#ifdef IRIS_FEATURE_TEXTURE_FILTERING
		vec2 texSize = 1.0 / vec2(textureSize(gtexture, 0));
		 Albedo *= textureFilteringMode == 1 ? sampleRGSS(gtexture, adjustedTexCoord.xy, texSize) : sampleNearest(gtexture, adjustedTexCoord.xy, texSize);
		#else
		 Albedo *= texture_POMSwitch(gtexture, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM, textureLOD);
		#endif
		}
	#else
		vec4 Albedo = texture_POMSwitch(gtexture, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM, textureLOD);
		vec4 overlayColor;
		float vanillaAO;

		clrwl_computeFragment(Albedo, Albedo, lmcoord, vanillaAO, overlayColor);
		lmcoord = clamp((lmcoord - 1.0 / 32.0) * 32.0 / 30.0, 0.0, 1.0);
		vanillaAO = 1.0 - clamp(vanillaAO, 0,1);
	#endif

	#ifdef WORLD
		vec3 flatNormals = viewToWorld(normal);
	#endif

	#if REPLACE_SHORT_GRASS < 2 && !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD && !defined CUTOUT
		// darken the top of grass blocks a bit
		if(data_in.blockID == 85 && flatNormals.y > 0.9 && !ShaderGrass) Albedo.rgb *= smoothstep(-30.0, 25.0, length(playerpos));
	#endif

	#if defined DISTANT_HORIZONS && DH_CHUNK_FADING > 0
			float viewDist = length(playerpos); 
			float ditherFade = smoothstep(0.98 * far, 1.03 * far, viewDist);

			if(step(ditherFade, R2) == 0.0) discard;
	#endif
	
	if(Albedo.a < alphaTestRef) discard;
	
	#if defined IRIS_FEATURE_FADE_VARIABLE && VANILLA_CHUNK_FADING > 0 && !defined HAND
		#ifdef TAA
			if(sqrt(data_in.chunkFade) < BN) discard;
		#else
			if(sqrt(data_in.chunkFade) < R2) discard;
		#endif
	#endif

	#if (defined BLOCKENTITIES || defined ENTITIES || defined HAND) && !defined TRANSLUCENT_ENTITIES && defined TRANSLUCENT_ENTITIES_DITHER_FALLBACK
		float entityAlbedo = clamp((Albedo.a*Color.a - 0.1) * 10.0 / 9.0, 0.0, 1.0);
		#ifdef TAA
			if(entityAlbedo < BN) discard;
		#else
			if(entityAlbedo < R2) discard;
		#endif
	#endif

	float torchlightmap = lmcoord.x;

	#ifdef FIRE_COLOR_CORRECTION
		#ifdef IS_LPV_ENABLED
			#ifdef ENTITIES
				if (data_in.blockID != ENTITY_BLAZE && data_in.blockID != ENTITY_MAGMA_CUBE) {
					vec3 fireHSV = RgbToHsv(Albedo.rgb);
					if (fireHSV.y > 0.4 && fireHSV.z > 0.6 && fireHSV.x < 0.16 && fireHSV.x > 0.02) {
						vec3 _lpvPos = GetLpvPosition(playerpos);
						
						vec3 lpvCol = SampleLpvLinear(_lpvPos).rgb;
						bool isBlueLight = lpvCol.b > lpvCol.r * 1.1 && lpvCol.b > 0.003;
						
						bool soulFireFound = false;
						ivec3 vPosBase = ivec3(floor(_lpvPos));
						// Larger search radius: entity fire lingers even after leaving soul fire block
						for(int x = -4; x <= 4; x++) {
							for(int z = -4; z <= 4; z++) {
								for(int y = -4; y <= 4; y++) {
									uint b = imageLoad(imgVoxelMask, vPosBase + ivec3(x,y,z)).r;
									if (b == 244u || b == 245u || b == 246u) soulFireFound = true;
								}
							}
						}
						
						if (soulFireFound || isBlueLight) {
							vec3 sRgbHSV = RgbToHsv(Albedo.rgb);
							Albedo.rgb = HsvToRgb(vec3(0.53, min(sRgbHSV.y * 0.75, 0.8), min(sRgbHSV.z * 1.8, 1.0)));
							torchlightmap *= 0.05;
						}
					}
				}
			#endif
		#endif
	#endif

	#if defined Hand_Held_lights && !defined LPV_ENABLED
		#ifdef IS_IRIS
			vec3 playerCamPos = cameraPosition - relativeEyePosition;
		#else
			vec3 playerCamPos = cameraPosition;
		#endif

		#ifdef VIVECRAFT
        	if (vivecraftIsVR) { 
				playerCamPos = cameraPosition - vivecraftRelativeMainHandPos;
			}
		#endif

		if(heldItemId > 999 || heldItemId2 > 999){ 
			float pointLight = clamp(1.0-(length(worldpos-playerCamPos)-1.)/HANDHELD_LIGHT_RANGE,0.0,1.0);

			if (torchlightmap < 0.99) { 
				torchlightmap = mix(torchlightmap, 0.9, pointLight);
			}
		}

		#ifdef HAND
			torchlightmap *= 0.9;
		#endif
	#endif
	
	#if defined WORLD && !defined ENTITIES && !defined HAND && defined BLOCKENTITIES && !defined COLORWHEEL && !defined CUTOUT
		bool PORTAL = data_in.blockID == BLOCK_END_PORTAL || data_in.blockID == BLOCK_END_GATEWAY;

		float endPortalEmission = 0.0;
		if(PORTAL) {
		#if MC_VERSION < 260100 && defined SHADER_END_PORTAL
				const float steps = 20.0;
				vec3 color = vec3(0.0);
				float absorbance = 1.0;

			vec3 worldSpaceNormal = flatNormals;

				vec3 viewVec = normalize(tbnMatrix*fragpos);
				vec3 correctedViewVec = viewVec;

				correctedViewVec.xy = mix(correctedViewVec.xy, vec2( viewVec.y,-viewVec.x), clamp( worldSpaceNormal.y,0,1));
				correctedViewVec.xy = mix(correctedViewVec.xy, vec2(-viewVec.y, viewVec.x), clamp(-worldSpaceNormal.x,0,1)); 
				correctedViewVec.xy = mix(correctedViewVec.xy, vec2(-viewVec.y, viewVec.x), clamp(-worldSpaceNormal.z,0,1));

				correctedViewVec.z = mix(correctedViewVec.z, -correctedViewVec.z, clamp(length(vec3(worldSpaceNormal.xz, clamp(-worldSpaceNormal.y,0,1))),0,1)); 

				vec2 correctedWorldPos = playerpos.xz + cameraPosition.xz;
				correctedWorldPos = mix(correctedWorldPos,	vec2(-playerpos.x,playerpos.z)	+	vec2(-cameraPosition.x,cameraPosition.z),	clamp(-worldSpaceNormal.y,0,1));
				correctedWorldPos = mix(correctedWorldPos,	vec2( playerpos.z,playerpos.y)	+	vec2( cameraPosition.z,cameraPosition.y),	clamp( worldSpaceNormal.x,0,1));
				correctedWorldPos = mix(correctedWorldPos,	vec2(-playerpos.z,playerpos.y)	+	vec2(-cameraPosition.z,cameraPosition.y),	clamp(-worldSpaceNormal.x,0,1));
				correctedWorldPos = mix(correctedWorldPos,	vec2( playerpos.x,playerpos.y)	+	vec2( cameraPosition.x,cameraPosition.y),	clamp(-worldSpaceNormal.z,0,1));
				correctedWorldPos = mix(correctedWorldPos,	vec2(-playerpos.x,playerpos.y)	+	vec2(-cameraPosition.x,cameraPosition.y),	clamp( worldSpaceNormal.z,0,1));

				vec2 rayDir = ((correctedViewVec.xy) / -correctedViewVec.z) / steps * 5.0 ;

				vec2 uv = correctedWorldPos + rayDir * BN;
				uv += rayDir * 10.0;

				vec2 animation = vec2(frameTimeCounter, -frameTimeCounter)*0.01;

				for (int i = 0; i < int(steps); i++) {
					
					float verticalGradient = (i + BN)/steps ;
					float verticalGradient2 = exp(-7*(1-verticalGradient*verticalGradient));
				
					float density = max(max(verticalGradient - texture(noisetex, uv/256.0 + animation.xy).b*0.5,0.0) - (1.0-texture(noisetex, uv/32.0 + animation.xx).r) * (0.4 + 0.1 * (texture(noisetex, uv/10.0 - animation.yy).b)),0.0);

					float volumeCoeff = exp(-density*(i+1));

					vec3 lighting =  vec3(0.5,0.75,1.0) * 0.1 * exp(-10*density) + vec3(0.8,0.3,1.0) * verticalGradient2 * 1.7;
					color += (lighting - lighting * volumeCoeff) * absorbance;;

					absorbance *= volumeCoeff;
					endPortalEmission += verticalGradient*verticalGradient ;
					uv += rayDir;
				}

				Albedo.rgb = clamp(color,0,1);
				endPortalEmission = clamp(endPortalEmission/steps * 1.0,0.0,254.0/255.0);

			#else
				int PORTAL_STEPS = 16;
				if(data_in.blockID == BLOCK_END_PORTAL) PORTAL_STEPS = 15;

				Albedo.rgb = textureProj(gtexture, data_in.lmtexcoord).rgb * COLORS[0];
				for (int i = 0; i < PORTAL_STEPS; i++) {
					Albedo.rgb += textureProj(gtexture, data_in.lmtexcoord * end_portal_layer(float(i + 1))).rgb * COLORS[i];
				}
				Albedo.rgb *= 0.3;
				torchlightmap = 0.0;
				lmcoord.y = 0.0;
				endPortalEmission = 0.9;
			#endif
		}
	#endif
	
	#ifdef WhiteWorld
		Albedo.rgb = vec3(0.5);
	#endif

		
	#ifdef AEROCHROME_MODE
		float gray = dot(Albedo.rgb, vec3(0.2, 1.0, 0.07));
		if (
			data_in.blockID == BLOCK_AMETHYST_BUD_MEDIUM || data_in.blockID == BLOCK_AMETHYST_BUD_LARGE || data_in.blockID == BLOCK_AMETHYST_CLUSTER 
			|| data_in.blockID == BLOCK_SSS_STRONG || data_in.blockID == BLOCK_SSS_STRONG3 || data_in.blockID == BLOCK_SSS_WEAK || data_in.blockID == BLOCK_CACTUS
			|| data_in.blockID == BLOCK_CELESTIUM || data_in.blockID == BLOCK_SNOW_LAYERS
			|| data_in.blockID >= 10 && data_in.blockID < 80
		) {
			// IR Reflective (Pink-red)
			Albedo.rgb = mix(vec3(gray), aerochrome_color, 0.7);
		}
		else if(data_in.blockID == BLOCK_GRASS) {
		// Special handling for grass block
			float strength = 1.0 - Color.b;
			Albedo.rgb = mix(Albedo.rgb, aerochrome_color, strength);
		}
		#ifdef AEROCHROME_WOOL_ENABLED
			else if (data_in.blockID == BLOCK_SSS_WEAK_2 || data_in.blockID == BLOCK_CARPET) {
			// Wool
				Albedo.rgb = mix(Albedo.rgb, aerochrome_color, 0.3);
			}
		#endif
		else if(data_in.blockID == BLOCK_WATER || (data_in.blockID >= 300 && data_in.blockID < 400))
		{
		// IR Absorbsive? Dark.
			Albedo.rgb = mix(Albedo.rgb, vec3(0.01, 0.08, 0.15), 0.5);
		}
	#endif

	#ifdef WORLD
    Albedo.a = opaqueMasks;
    #ifdef ENCHANTING_TABLE_EFFECTS
    #ifndef HAND
    if (enchantTablePosSSBO.w > 0.5) {
        vec3 diff = data_in.worldPosAbs - enchantTablePosSSBO.xyz;
        diff -= vec3(0.5, 0.0, 0.5);

        float d2d = length(diff.xz);
        float t = frameTimeCounter;

        if (d2d < 1.8 && diff.y > 0.0 && diff.y < 3.5) {
            float soulEffect = 0.0;
            for (int i = 0; i < 4; i++) {
                float fi = float(i);
                float seed = fi * 15.71;
                float tOff = t * (0.3 + fi * 0.1);
                vec2 soulBase = vec2(
                    sin(tOff + seed) * 0.7,
                    cos(tOff * 0.9 + seed * 1.3) * 0.7
                );
                float height = fract(t * 0.12 + seed * 0.25) * 4.0;
                float verticalFade = smoothstep(0.0, 0.6, height) * (1.0 - smoothstep(3.0, 4.0, height));
                
                vec3 soulPos = vec3(soulBase.x, height, soulBase.y);
                float distToSoul = length(diff - soulPos);
                
                float shape = smoothstep(0.22, 0.0, distToSoul);
                float noise = fract(sin(dot(data_in.worldPosAbs + t*0.05, vec3(12.989, 78.233, 45.164))) * 43758.5453);
                
                soulEffect += shape * verticalFade * (0.8 + noise * 0.4);
            }
            
            if (soulEffect > 0.01) {
                vec3 soulColor = vec3(0.2, 0.7, 1.0);
                Albedo.rgb = mix(Albedo.rgb, soulColor * 4.0, soulEffect * 0.75);
                torchlightmap = max(torchlightmap, soulEffect * 0.6);
            }
        }

        if (flatNormals.y > 0.8 && abs(diff.y) < 1.1 && data_in.blockID != 267) {
            if (d2d > 0.05 && d2d < 2.1) {
                float angle = atan(diff.z, diff.x);

                float pulse1 = sin(t * 2.5) * 0.2 + 0.8;
                float pulse2 = sin(t * 1.1 + 1.3) * 0.15 + 0.85;
                float pulse3 = sin(t * 0.6 + 2.7) * 0.1 + 0.9;
                float pulse = pulse1 * pulse2 * pulse3;

                float proximityFade = smoothstep(2.1, 0.22, d2d);
                float innerGlow     = smoothstep(0.0, 0.33, d2d);
                float sigil = 0.0;

                float coreRing = smoothstep(0.04, 0.0, abs(d2d - 0.155 * pulse1));
                sigil = max(sigil, coreRing * 1.5);

                float starAngle5 = angle + t * 0.38;
                float star5 = abs(cos(starAngle5 * 2.5));
                float starRad5 = 0.358 + star5 * 0.154;
                sigil = max(sigil, smoothstep(0.022, 0.0, abs(d2d - starRad5)) * 0.65);

                float starAngle7 = angle - t * 0.22;
                float star7 = abs(cos(starAngle7 * 3.5));
                float starRad7 = 0.396 + star7 * 0.121;
                sigil = max(sigil, smoothstep(0.018, 0.0, abs(d2d - starRad7)) * 0.55);

                float r1 = 0.286;
                if (abs(d2d - r1) < 0.12) {
                    float phase1 = angle - t * 2.4;
                    float freq1 = 22.0;
                    float runeIdx1 = floor(phase1 * freq1);
                    float runeFrac1 = fract(phase1 * freq1);
                    float runeShape1 = smoothstep(0.08, 0.42, runeFrac1) * (1.0 - smoothstep(0.58, 0.92, runeFrac1));
                    float runeNoise1 = fract(sin(runeIdx1 * 13.731 + 7.43) * 51.4123);
                    float runes1 = runeShape1 * (0.5 + runeNoise1 * 0.5);
                    sigil = max(sigil, smoothstep(0.1, 0.0, abs(d2d - r1)) * runes1 * 1.4);
                }

                float sqA = t * 0.52;
                mat2 rotSqA = mat2(cos(sqA), -sin(sqA), sin(sqA), cos(sqA));
                vec2 pSqA = rotSqA * diff.xz;
                float squareA = max(abs(pSqA.x), abs(pSqA.y));
                sigil = max(sigil, smoothstep(0.018, 0.0, abs(squareA - 0.594)) * 0.75);

                float sqB = sqA + 0.7854;
                mat2 rotSqB = mat2(cos(sqB), -sin(sqB), sin(sqB), cos(sqB));
                vec2 pSqB = rotSqB * diff.xz;
                float squareB = max(abs(pSqB.x), abs(pSqB.y));
                sigil = max(sigil, smoothstep(0.015, 0.0, abs(squareB - 0.594)) * 0.55);

                float octaV = smoothstep(0.96, 1.0, cos(angle * 8.0 - sqA * 2.0));
                if (d2d > 0.495 && d2d < 0.688)
                    sigil = max(sigil, octaV * 0.6 * proximityFade);

                float r2 = 0.814; 
                if (abs(d2d - r2) < 0.22) {
                    float phase2 = angle + t * 0.75;
                    float freq2 = 36.0;
                    float runeIdx2 = floor(phase2 * freq2);
                    float runeFrac2 = fract(phase2 * freq2);
                    float runeShape2 = smoothstep(0.04, 0.35, runeFrac2) * (1.0 - smoothstep(0.65, 0.96, runeFrac2));
                    float runeNoise2 = fract(sin(runeIdx2 * 19.317 + 3.11) * 67.2345);
                    float runes2 = runeShape2 * (0.4 + runeNoise2 * 0.6);

                    float fade2 = smoothstep(0.2, 0.0, abs(d2d - r2));
                    float borderInner = smoothstep(0.013, 0.0, abs(abs(d2d - r2) - 0.14));
                    float borderOuter = smoothstep(0.013, 0.0, abs(abs(d2d - r2) - 0.19));
                    sigil = max(sigil, (runes2 + borderInner * 0.8 + borderOuter * 0.5) * fade2);
                }

                float spokes12 = smoothstep(0.975, 1.0, cos(angle * 12.0 - t * 0.35));
                if (d2d > 0.193 && d2d < 1.045)
                    sigil = max(sigil, spokes12 * 0.45 * proximityFade);

                float triA = t * 0.18;
                float triB = -t * 0.14 + 1.047;
                float cosTriA = cos(angle * 3.0 - triA);
                float cosTriB = cos(angle * 3.0 - triB);
                float triShapeA = smoothstep(0.97, 1.0, cosTriA);
                float triShapeB = smoothstep(0.97, 1.0, cosTriB);
                if (d2d > 0.853 && d2d < 1.128) {
                    sigil = max(sigil, triShapeA * 0.7 * proximityFade);
                    sigil = max(sigil, triShapeB * 0.55 * proximityFade);
                }

                float r3 = 1.21;
                if (abs(d2d - r3) < 0.12) {
                    float phase3 = angle - t * 0.28;
                    float constIdx = floor(phase3 * 10.0);
                    float constFrac = fract(phase3 * 10.0);
                    float constShape = smoothstep(0.0, 0.2, constFrac) * (1.0 - smoothstep(0.8, 1.0, constFrac));
                    float constNoise = step(0.6, fract(sin(constIdx * 7.351) * 43758.5453));
                    float rim3 = smoothstep(0.012, 0.0, abs(d2d - r3));
                    sigil = max(sigil, (constShape * constNoise * 2.2 + rim3 * 0.35) * smoothstep(0.11, 0.0, abs(d2d - r3)));
                }

                float r4 = 1.568 + sin(t * 1.8) * 0.044;
                float outerRim = smoothstep(0.025, 0.0, abs(d2d - r4));
                sigil = max(sigil, outerRim * 0.6 * pulse2);

                float r4seg = step(0.93, fract((angle - t * 0.12) / 6.2832 * 24.0));
                if (abs(d2d - (r4 - 0.066)) < 0.05)
                    sigil = max(sigil, r4seg * 0.5);

                for (int i = 0; i < 16; i++) {
                    float fi = float(i);
                    float orbitSpeed = 0.9 + fi * 0.03;
                    float orbitAngle = (6.2832 / 16.0) * fi + t * orbitSpeed;
                    float orbitR = 0.578 + sin(t * 1.4 + fi * 0.8) * 0.099;
                    vec2 orbitPos = vec2(cos(orbitAngle), sin(orbitAngle)) * orbitR;
                    float orbitDist = length(diff.xz - orbitPos);
                    sigil = max(sigil, smoothstep(0.055, 0.0, orbitDist) * (0.7 + sin(t * 3.0 + fi) * 0.3));
                }

                vec2 noiseCoord = data_in.worldPosAbs.xz + t * 0.08;
                float noise1 = fract(sin(dot(noiseCoord, vec2(12.9898, 78.233))) * 43758.5453);
                float noise2 = fract(sin(dot(noiseCoord * 1.5 + 0.3, vec2(39.346, 11.135))) * 27385.2134);
                float shimmer = (noise1 * 0.6 + noise2 * 0.4) * 0.22;
                sigil += shimmer * step(0.35, sigil);

                sigil *= proximityFade * innerGlow;
                sigil = clamp(sigil, 0.0, 1.0);

                if (sigil > 0.005) {
                    vec3 cVoid   = vec3(0.04, 0.0,  0.22);
                    vec3 cDeep   = vec3(0.12, 0.02, 0.85);
                    vec3 cArcane = vec3(0.0,  0.45, 1.0);
                    vec3 cEther  = vec3(0.35, 0.92, 1.0);
                    vec3 cDivine = vec3(0.88, 0.98, 1.0);
                    vec3 cGold   = vec3(1.0,  0.88, 0.35);

                    vec3 runeColor = mix(cVoid,   cDeep,   clamp(sigil * 2.0,        0.0, 1.0));
                    runeColor      = mix(runeColor, cArcane, clamp(sigil * 2.0 - 0.5, 0.0, 1.0));
                    runeColor      = mix(runeColor, cEther,  clamp(sigil * 3.0 - 1.2, 0.0, 1.0));
                    runeColor      = mix(runeColor, cDivine, pow(clamp(sigil, 0.0, 1.0), 2.8));

                    float goldMask = smoothstep(0.0, 0.165, d2d) * (1.0 - smoothstep(0.165, 0.385, d2d));
                    goldMask      += smoothstep(0.18, 0.0, abs(d2d - r2)) * 0.6;
                    runeColor      = mix(runeColor, cGold, goldMask * pow(sigil, 1.5) * pulse3 * 0.55);

                    float brightness = 6.2 + pulse * 1.6 + shimmer * 1.8;
                    Albedo.rgb = mix(Albedo.rgb, runeColor * brightness, sigil * 0.97);

                    float particleBoost = smoothstep(0.5, 1.0, sigil) * 0.4;
                    torchlightmap = max(torchlightmap, (sigil * 0.92 + particleBoost) * pulse);
        } // closes if (sigil > 0.005)
            } // closes if (d2d > 0.05 && d2d < 2.1)
        } // closes if (flatNormals.y > 0.8 && ...)

    } // closes if (enchantTablePosSSBO.w > 0.5)
    #endif // ifndef HAND

    if (data_in.blockID == 267) {
        vec3 hsv = RgbToHsv(Albedo.rgb);
        // Soften thresholds to avoid flickering at pixel edges
        float hueMask = smoothstep(0.46, 0.49, hsv.x) * (1.0 - smoothstep(0.61, 0.64, hsv.x));
        float satMask = smoothstep(0.32, 0.38, hsv.y);
        float valMask = smoothstep(0.45, 0.55, hsv.z);
        float rugMask = hueMask * satMask * valMask;

        if (rugMask > 0.01) {
            float pulse = sin(frameTimeCounter * 3.0) * 0.15 + 1.15;
            Albedo.rgb = mix(Albedo.rgb, Albedo.rgb * pulse * 1.5, rugMask);
            emissiveMask = max(emissiveMask, rugMask);
        }
    }
    #endif // ENCHANTING_TABLE_EFFECTS

	#if defined POM_OFFSET_SHADOW_BIAS && defined POM && (!defined ENTITIES && !defined HAND || defined COLORWHEEL)
			if(saveDepth > 0) Albedo.a = clamp(sqrt(saveDepth)*0.44, 0.0, 0.44);
		#endif

	#if defined ENTITIES || defined BLOCKENTITIES || defined HAND
		OutTranslucents = vec4(0.0);

		#ifdef VOXY
			OutTranslucents2 = vec4(0.0);
		#endif
	#endif

	
	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	NORMAL		////////////////////////////////
	//////////////////////////////// 				//////////////////////////////// 

	#if defined WORLD && defined MC_NORMAL_MAP
		#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD && !defined CUTOUT
		if(!ShaderGrass)
		#endif
		{
			vec4 NormalTex = texture_POMSwitch(normals, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM,textureLOD).xyzw;
			
			#if defined MATERIAL_AO && defined MC_TEXTURE_FORMAT_LAB_PBR
				Albedo.rgb *= NormalTex.b*0.5+0.5;
			#endif

			NormalTex.xy = NormalTex.xy * 2.0-1.0;
			NormalTex.z = sqrt(max(1.0 - dot(NormalTex.xy, NormalTex.xy), 0.0));

			normal = applyBump(tbnMatrix, NormalTex.xyz);
		}
	#endif
	
	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	SPECULAR	////////////////////////////////
	//////////////////////////////// 				//////////////////////////////// 
	
	#ifdef WORLD
		normal = viewToWorld(normal);

		float SSSAMOUNT = 0.0;
		#if (SSS_TYPE == 1 || SSS_TYPE == 2) && !defined HAND
			#ifdef ENTITIES
				#ifdef MOB_SSS
					/////// ----- SSS ON MOBS----- ///////
					// strong
					if(data_in.blockID == ENTITY_SSS_MEDIUM) SSSAMOUNT = 0.75;
			
					// medium
			
					// low
					else if(data_in.blockID == ENTITY_SSS_WEAK || data_in.blockID == ENTITY_PLAYER || data_in.blockID == ENTITY_CURRENT_PLAYER) SSSAMOUNT = 0.4;
				#endif
			#else
				#if defined SHADER_GRASS && !defined CUTOUT
					if (ShaderGrass) SSSAMOUNT = 0.65;
					else
				#endif

				/////// ----- SSS ON BLOCKS ----- ///////
				// strong
				if (
					data_in.blockID == BLOCK_SSS_STRONG || data_in.blockID == BLOCK_SSS_STRONG3 || data_in.blockID == BLOCK_AIR_WAVING || data_in.blockID == BLOCK_SSS_STRONG_2
				) {
					SSSAMOUNT = 1.0;
				}
				// medium
				else if (
					data_in.blockID == BLOCK_GROUND_WAVING || data_in.blockID == BLOCK_GROUND_WAVING_VERTICAL ||
					data_in.blockID == BLOCK_GRASS_SHORT || data_in.blockID == BLOCK_GRASS_TALL_UPPER || data_in.blockID == BLOCK_GRASS_TALL_LOWER ||
					data_in.blockID == BLOCK_SSS_WEAK || data_in.blockID == BLOCK_CACTUS || data_in.blockID == BLOCK_SSS_WEAK_2 ||
					data_in.blockID == BLOCK_CELESTIUM || (data_in.blockID >= 269 && data_in.blockID <= 274) || data_in.blockID == BLOCK_SNOW_LAYERS || data_in.blockID == BLOCK_CARPET ||
					data_in.blockID == BLOCK_AMETHYST_BUD_MEDIUM || data_in.blockID == BLOCK_AMETHYST_BUD_LARGE || data_in.blockID == BLOCK_AMETHYST_CLUSTER ||
					data_in.blockID == BLOCK_BAMBOO || data_in.blockID == BLOCK_SAPLING || data_in.blockID == BLOCK_VINE || data_in.blockID == BLOCK_VINE_OTHER
					#ifdef MISC_BLOCK_SSS
					|| data_in.blockID == BLOCK_SSS_WEIRD || data_in.blockID == BLOCK_GRASS
					#endif
				) {
					SSSAMOUNT = 0.5;
				} else if(data_in.blockID == GRASS_BLOCK_SNOWY) {
					SSSAMOUNT = 0.5 * smoothstep(0.0, 1.0, fract(worldpos.y));
				}
				#if defined CUTOUT
					else if (data_in.blockID == -BLOCK_GRASS) {
						SSSAMOUNT = 0.3;
					}
				#endif
			#endif

			#ifdef BLOCKENTITIES
				/////// ----- SSS ON BLOCK ENTITIES----- ///////
				// strong

				// medium
				if(data_in.blockID == BLOCK_SSS_WEAK_3) SSSAMOUNT = 0.4;

				// low

			#endif
		#endif

		#if EMISSIVE_TRIMS > 0
			bool isBrightTrim = currentRenderedItemId == 1026;
			bool isTrim = isBrightTrim || currentRenderedItemId == 1027;
		#endif

		#if EMISSIVE_TYPE == 1 || EMISSIVE_TYPE == 2
			/////// ----- EMISSIVE STUFF ----- ///////
			float EMISSIVE = emissiveMask;

			// normal block lightsources
			if(data_in.blockID == 513 || data_in.blockID == 514 || (data_in.blockID >= 100 && data_in.blockID < 282)) {
   			if(data_in.blockID != 513 && data_in.blockID != 514) EMISSIVE = max(EMISSIVE, 0.5);
				if(data_in.blockID == 199) EMISSIVE = 1;
				if(data_in.blockID == 266 || (data_in.blockID >= 276 && data_in.blockID <= 281)) EMISSIVE = 0.2; // sculk stuff
				else if(data_in.blockID == 195) EMISSIVE = 2.3; // glow lichen
				else if(data_in.blockID == 185) EMISSIVE = 1.0; // crying obsidian
				else if(data_in.blockID == 105) EMISSIVE = 2.0; // brewing stand
				else if(data_in.blockID == 236) EMISSIVE = 1.0; // respawn anchor
				else if(data_in.blockID == 101) EMISSIVE = 0.7; // large amethyst bud
				else if(data_in.blockID == 103) EMISSIVE = 1.0; // amethyst cluster
				else if(data_in.blockID == 244) EMISSIVE = 1.5; // soul fire
			       #ifdef EXTRA_EMISSIVE_BLOCKS
			       if(data_in.blockID == 513) EMISSIVE = 2.5; // Redstone_block
			       if(data_in.blockID == 514) EMISSIVE = 4.0; // Nether Wood
			       if(data_in.blockID == 185) EMISSIVE = 1.5; // Crying Obsidian
			       #endif
}

#if BRIGHT_ORES_INTENSITY > 0
    if(data_in.blockID == 502 || data_in.blockID == 520 || data_in.blockID == 519 || data_in.blockID == 506 || data_in.blockID == 507 || data_in.blockID == 521 || data_in.blockID == 522) {
        float normalizedSlider = (BRIGHT_ORES_INTENSITY / 100.0);
        float oreIntensity = normalizedSlider * normalizedSlider * 4.0;
        if(oreIntensity < 0.01 && normalizedSlider > 0.0) oreIntensity = 0.01;

        if(data_in.blockID == 502) {
            float brightness = dot(Albedo.rgb, vec3(0.299, 0.587, 0.114));
            vec3 hsv = RgbToHsv(Albedo.rgb);
            float saturationMask = smoothstep(0.25, 0.6, hsv.y);
            float brightnessMask = smoothstep(0.15, 0.45, brightness);
            EMISSIVE = max(saturationMask * brightnessMask * 1.8 * oreIntensity, 0.0);
        } else if(data_in.blockID == 520) {
            float brightness = dot(Albedo.rgb, vec3(0.299, 0.587, 0.114));
            vec3 hsv = RgbToHsv(Albedo.rgb);
            float saturationMask = smoothstep(0.15, 0.5, hsv.y);
            float brightnessMask = smoothstep(0.08, 0.35, brightness);
            EMISSIVE = max(saturationMask * brightnessMask * 2.40 * oreIntensity, 0.0);
        } else if(data_in.blockID == 506) {
            float brightness = dot(Albedo.rgb, vec3(0.299, 0.587, 0.114));
            float coalMask = smoothstep(0.30, 0.05, brightness);
            EMISSIVE = max(coalMask * 0.9 * oreIntensity, 0.0);
        } else if(data_in.blockID == 507) {
            float brightness = dot(Albedo.rgb, vec3(0.299, 0.587, 0.114));
            float coalMask = smoothstep(0.24, 0.04, brightness);
            EMISSIVE = max(coalMask * 0.7 * oreIntensity, 0.0);
        } else if(data_in.blockID == 519) {
            float brightness = dot(Albedo.rgb, vec3(0.299, 0.587, 0.114));
            float mask = smoothstep(0.3, 1.2, brightness);
            EMISSIVE = max(mask * 1.20 * oreIntensity, 0.0);
        } else if(data_in.blockID == 521 || data_in.blockID == 522) {
            float brightness = dot(Albedo.rgb, vec3(0.299, 0.587, 0.114));
            vec3 hsv = RgbToHsv(Albedo.rgb);
            float ironMask = smoothstep(0.12, 0.5, hsv.y) * smoothstep(0.3, 0.7, brightness);
            if (ironMask > 0.01) {
                Albedo.rgb = mix(Albedo.rgb, vec3(1.1, 1.1, 1.2) * brightness, ironMask * 0.9);
                EMISSIVE = max(ironMask * 10.0 * oreIntensity, 0.0);
            } else {
                EMISSIVE = 0.0;
            }
        } else {
            EMISSIVE = EMISSIVE_ORES_STRENGTH * getEmission(Albedo.rgb) * oreIntensity;
        }
    }
#endif

			#if EMISSIVE_ORES > 0 && !defined(BRIGHT_ORES_INTENSITY)
				if(data_in.blockID == 502) {
					EMISSIVE = EMISSIVE_ORES_STRENGTH;

					#ifndef HARDCODED_EMISSIVES_APPROX
						EMISSIVE *= getEmission(Albedo.rgb);
					#endif
				}
			#endif

			#if EMISSIVE_TRIMS > 0
				if(isTrim) EMISSIVE = EMISSIVE_TRIMS_STRENGTH*getTrimEmission(Albedo.rgb);

				if(isBrightTrim) EMISSIVE *= 0.4;
			#endif
		#endif


		vec4 SpecularTex = vec4(0.0);
		#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD && !defined CUTOUT
		if (ShaderGrass) {
			SpecularTex = vec4(0.15, 0.025, 1.0, 0.0);
		} else
		#endif
		{
			SpecularTex = texture_POMSwitch(specular, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM,textureLOD);
		}

		OutSpecular = vec4(0.0,0.0,0.0,0.0);
		OutSpecular.rg = SpecularTex.rg;

		#if EMISSIVE_ORES > 1 && EMISSIVE_TYPE > 1 && !defined(BRIGHT_ORES_INTENSITY)
			if(data_in.blockID == 502) {
				SpecularTex.a = EMISSIVE_ORES_STRENGTH;
				
				SpecularTex.a *= getEmission(Albedo.rgb);
			}
		#endif

		#if EMISSIVE_TRIMS > 1 && EMISSIVE_TYPE > 1
			if(isTrim) SpecularTex.a = EMISSIVE_TRIMS_STRENGTH*getTrimEmission(Albedo.rgb);

			if(isBrightTrim) SpecularTex.a *= 0.4;
		#endif

		#if EMISSIVE_TYPE == 2
		bool emissionCheck = SpecularTex.a <= 0.0;
		#endif

		#ifdef MIRROR_IRON
		if(data_in.blockID == 504 || currentRenderedItemId == 504) {
			OutSpecular.rg = vec2(1.0, 1.0);
			Albedo.rgb = vec3(1.0);
		}
		#endif

		#if defined HARDCODED_EMISSIVES_APPROX && (EMISSIVE_TYPE == 1 || EMISSIVE_TYPE == 2)
			#if EMISSIVE_TYPE == 2 && EMISSIVE_TRIMS > 0
			if(emissionCheck && !isTrim)
			#elif EMISSIVE_TRIMS > 0
			if(!isTrim)
			#elif EMISSIVE_TYPE == 2
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
		
		#if defined WORLD && !defined ENTITIES && !defined HAND && defined BLOCKENTITIES && !defined COLORWHEEL
			if(PORTAL) OutSpecular.a = endPortalEmission;
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
	#endif

	// hit glow effect...
	#if defined ENTITIES && !defined COLORWHEEL
		Albedo.rgb = mix(Albedo.rgb, entityColor.rgb, pow(entityColor.a, 0.8));
	#endif

	#ifdef COLORWHEEL
		Albedo.rgb = mix(Albedo.rgb, overlayColor.rgb, overlayColor.a);
	#endif

//////////////////////////////// EMANRUX ////////////////////////////////

#ifdef CUSTOM_REFLECTIONS
if(data_in.blockID == 509 || data_in.blockID == 510 || data_in.blockID == 79 || data_in.blockID == 517) {
    OutSpecular.r = 1.2;
    OutSpecular.g = 0.2;
}
if(data_in.blockID == 511) {
    OutSpecular.r = 1.0;
    OutSpecular.g = 0.3;
}
if(data_in.blockID == 504) {
    OutSpecular.r = 1.0;
    OutSpecular.g = 0.8;
}
#else
if(data_in.blockID == 509 || data_in.blockID == 516 || data_in.blockID == 517 || data_in.blockID == 510 || data_in.blockID == 511 || data_in.blockID == 79 || data_in.blockID == 504 || data_in.blockID == 512) {
    OutSpecular.r = 0.0;
    OutSpecular.g = 0.0;
}
#endif

	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	FINALIZE	////////////////////////////////
	//////////////////////////////// 				////////////////////////////////

	#ifdef WORLD
		// apply noise to lightmaps to reduce banding.
		vec2 PackLightmaps = vec2(torchlightmap, lmcoord.y);

		#if defined WORLD && !defined HAND && !defined ENTITIES
			
			PackLightmaps = clamp(PackLightmaps + PackLightmaps * (BN-0.5)*0.001, 0, 1);
		#endif

		#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD && !defined CUTOUT
			if (ShaderGrass) {flatNormals = data_in.normalMat; normal = data_in.texcoordam.xyz;}
		#endif

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

	#endif
	
}
