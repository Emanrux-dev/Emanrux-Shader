#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/bokeh.glsl"
#include "/lib/blocks.glsl"
#include "/lib/entities.glsl"
#include "/lib/items.glsl"

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/


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

#if !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined BLOCKENTITIES
out vec4 vgrassSideCheck;
out vec3 vcenterPosition;
flat out int vdiscardGrass;
#endif

out vec4 vcolor;
out float vVanillaAO;

out vec4 vlmtexcoord;
out vec4 vnormalMat;

// #ifdef POM
	out vec4 vtexcoordam; // .st for add, .pq for mul
	out vec4 vtexcoord;
// #endif

#ifdef MC_NORMAL_MAP
	out vec4 vtangent;
	attribute vec4 at_tangent;
	out vec3 vFlatNormals;
#endif

uniform float frameTimeCounter;
const float PI48 = 150.796447372*WAVY_SPEED;
float pi2wt = PI48*frameTimeCounter;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform int blockEntityId;
uniform int entityId;
flat out float vblockID;

uniform int heldItemId;
uniform int heldItemId2;

#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
	attribute vec4 at_midBlock;
#else
	attribute vec3 at_midBlock;
#endif

uniform int frameCounter;
uniform float far;
uniform float aspectRatio;
uniform float viewHeight;
uniform float viewWidth;
uniform int hideGUI;
uniform float screenBrightness;
uniform int isEyeInWater;

// in vec3 at_velocity;
// out vec3 velocity;

uniform float nightVision;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec2 texelSize;

#if defined HAND
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;

float detectCameraMovement(){
	// simply get the difference of modelview matrices and cameraPosition across a frame.
	vec3 fakePos = vec3(0.5,0.5,0.0);
	vec3 hand_playerPos = mat3(gbufferModelViewInverse) * fakePos + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * hand_playerPos;
	float detectMovement = 1.0 - clamp(distance(previousPosition, fakePos)/texelSize.x,0.0,1.0);

	return detectMovement;
}
#endif

//#ifndef IS_LPV_ENABLED
	uniform vec3 relativeEyePosition;
//#endif

#if !defined ENTITIES && !defined HAND && defined SHADER_GRASS && (defined GRASS_DETECT_FALLOFF || defined GRASS_DETECT_INV_FALLOFF || REPLACE_SHORT_GRASS > 0)
uniform usampler1D texBlockData;
#include "/lib/lpv_common.glsl"
#include "/lib/lpv_blocks.glsl"
#include "/lib/lpv_buffer.glsl"
#include "/lib/voxel_common.glsl"

uint GetVoxelBlock(const in ivec3 voxelPos) {
    if (clamp(voxelPos, ivec3(0), ivec3(VoxelSize3-1u)) != voxelPos)
        return BLOCK_EMPTY;
    
    return imageLoad(imgVoxelMask, voxelPos).r;
}
#endif

							
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}

vec2 calcWave(in vec3 pos) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec2 ret = (sin(pi2wt*vec2(0.0063,0.0015)*4. - pos.xz + pos.y*0.05)+0.1)*magnitude;

    return ret;
}

vec3 calcMovePlants(in vec3 pos) {
    vec2 move1 = calcWave(pos );
	float move1y = -length(move1);
   return vec3(move1.x,move1y,move1.y)*5.*WAVY_STRENGTH;
}

vec3 calcWaveLeaves(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec3 ret = (sin(pi2wt*vec3(0.0063,0.0224,0.0015)*1.5 - pos))*magnitude;

    return ret;
}

vec3 calcMoveLeaves(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWaveLeaves(pos      , 0.0054, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    return move1*5.*WAVY_STRENGTH;
}
vec3 srgbToLinear2(vec3 srgb){
    return mix(
        srgb / 12.92,
        pow(.947867 * srgb + .0521327, vec3(2.4) ),
        step( .04045, srgb )
    );
}
vec3 blackbody2(float Temp)
{
    float t = pow(Temp, -1.5);
    float lt = log(Temp);

    vec3 col = vec3(0.0);
         col.x = 220000.0 * t + 0.58039215686;
         col.y = 0.39231372549 * lt - 2.44549019608;
         col.y = Temp > 6500. ? 138039.215686 * t + 0.72156862745 : col.y;
         col.z = 0.76078431372 * lt - 5.68078431373;
         col = clamp(col,0.0,1.0);
         col = Temp < 1000. ? col * Temp * 0.001 : col;

    return srgbToLinear2(col);
}
// float luma(vec3 color) {
// 	return dot(color,vec3(0.21, 0.72, 0.07));
// }

#define SEASONS_VSH
#include "/lib/climate_settings.glsl"


uniform sampler2D noisetex;//depth
float densityAtPos(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	
	//The y channel has an offset to avoid using two textures fetches
	vec2 xy = texture2D(noisetex, coord).yx;

	return mix(xy.r,xy.g, f.y);
}
float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	gl_Position = ftransform();

	#if defined ENTITIES && defined IS_IRIS
		// force out of frustum
		if (entityId == 1599) gl_Position.z -= 10000.0;
	#endif

	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;

    /////// ----- COLOR STUFF ----- ///////
	vcolor = gl_Color;

	vVanillaAO = 1.0 - clamp(vcolor.a,0,1);
	if (vcolor.a < 0.3) vcolor.a = 1.0; // fix vanilla ao on some custom block models.
	


    /////// ----- RANDOM STUFF ----- ///////
	// gl_TextureMatrix[0] for animated things like charged creepers
	vlmtexcoord.xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	// #ifdef POM
	vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = vlmtexcoord.xy-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid)*2.;
	vtexcoordam.st  = min(vlmtexcoord.xy,midcoord-texcoordminusmid);
	vtexcoord.xy    = sign(texcoordminusmid)*0.5+0.5;
	// #endif


	vec2 lmcoord = gl_MultiTexCoord1.xy / 240.0; 
	vlmtexcoord.zw = lmcoord;



	#ifdef MC_NORMAL_MAP
		vec3 alterTangent = at_tangent.rgb;

		vtangent = vec4(normalize(gl_NormalMatrix * alterTangent.rgb), at_tangent.w);
	#endif

	vnormalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), 1.0);
	
	vFlatNormals = vnormalMat.xyz;

	#ifdef ENTITIES
		vblockID = entityId;
	#elif defined BLOCKENTITIES
		vblockID = blockEntityId;
	#else
		vblockID = mc_Entity.x;
	#endif

	if(vblockID == BLOCK_GROUND_WAVING_VERTICAL || vblockID == BLOCK_GRASS_SHORT || vblockID == BLOCK_GRASS_TALL_LOWER || vblockID == BLOCK_GRASS_TALL_UPPER ) vnormalMat.a = 0.60;
	if(vblockID == BLOCK_AIR_WAVING) vnormalMat.a = 0.55;

	#if defined WORLD && !defined HAND

		#ifdef BLOCKENTITIES
			if(blockEntityId == BLOCK_END_PORTAL || blockEntityId == 187) {
				vlmtexcoord.w = 0.0;
			}
		#endif

		#if PUDDLE_MODE > 0 || ShaderSnow > 0
			if(vblockID == 215) vlmtexcoord.w = 0.0;
		#endif
	#endif
	
	#ifdef ENTITIES
		// try and single out nametag text and then discard nametag background
		// if( dot(gl_Color.rgb, vec3(1.0/3.0)) < 1.0) vNameTags = 1;
		// if(gl_Color.a < 1.0) vNameTags = 1;
		// if(gl_Color.a >= 0.24 && gl_Color.a <= 0.25 ) gl_Position = vec4(10,10,10,1);
		#ifdef INCLUDE_UNLISTED_ENTITIES
			vnormalMat.a = 0.45;
		#else
			if(entityId == ENTITY_BOAT || entityId == ENTITY_SMALLSHIPS || entityId == ENTITY_SSS_MEDIUM || entityId == ENTITY_SSS_WEAK || entityId == ENTITY_PLAYER || entityId == 2468) vnormalMat.a = 0.45;
		#endif
	#endif

	#if PUDDLE_MODE > 0 || ShaderSnow > 0
		if (vblockID == 244 || vblockID == 189) vlmtexcoord.w = 0.0;
	#endif

	// special cases light lightning and beacon beams...	
	#ifdef ENTITIES
		if(entityId == ENTITY_LIGHTNING){
			vnormalMat.a = 0.50;
		}
	#endif


#ifdef WORLD

   	vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;

	vec3 worldNormals = viewToWorld(vFlatNormals);

	#if !defined ENTITIES && !defined HAND && defined SHADER_GRASS && (defined GRASS_DETECT_FALLOFF || defined GRASS_DETECT_INV_FALLOFF || REPLACE_SHORT_GRASS > 0) && !defined BLOCKENTITIES

		vgrassSideCheck = vec4(0.0);
	
		if(length(worldpos) < min(GRASS_RANGE, 0.5*float(LpvSize)) && vblockID == 85 && worldNormals.y > 0.9) {

			float fractYPos = fract(worldpos.y+cameraPosition.y);
			if(fractYPos > 0.9999 || fractYPos < 0.0001 || abs(fractYPos - 0.5) < 0.0001) {

				vcenterPosition = worldpos + at_midBlock.xyz / 64.0;

				vec3 LPVpos = GetLpvPosition(vcenterPosition);

				#if REPLACE_SHORT_GRASS > 0
					uint blockTop = GetVoxelBlock(ivec3(LPVpos.x, LPVpos.y + 0.6, LPVpos.z));
				#else
					uint blockTop = 0;
				#endif

				if(blockTop == 12 || blockTop > 4000) {
					vgrassSideCheck = vec4(2.0);
				}
				#if REPLACE_SHORT_GRASS < 2
				else {
					uint blockEast = GetVoxelBlock(ivec3(LPVpos.x + 1.0, LPVpos.y + 0.6, LPVpos.z));
					uint blockWest = GetVoxelBlock(ivec3(LPVpos.x - 1.0, LPVpos.y + 0.6, LPVpos.z));
					uint blockSouth = GetVoxelBlock(ivec3(LPVpos.x, LPVpos.y + 0.6, LPVpos.z + 1.0));
					uint blockNorth = GetVoxelBlock(ivec3(LPVpos.x, LPVpos.y + 0.6, LPVpos.z - 1.0));

					if(blockEast > 4000 || blockEast == 12 || (blockEast > 80 && blockEast < 86) || blockEast == 503 || (blockEast > 406 && blockEast < 440)) {vgrassSideCheck.x = 1.0;} else {
						#ifdef GRASS_DETECT_FALLOFF
							blockEast = GetVoxelBlock(ivec3(LPVpos.x + 1.0, LPVpos.y, LPVpos.z));
							if(blockEast != 85) {vgrassSideCheck.x = -1.0;}
						#endif
					}
					if(blockWest > 4000 || blockWest == 12 || (blockWest > 80 && blockWest < 86) || blockWest == 503 || (blockWest > 406 && blockWest < 440)) {vgrassSideCheck.y = 1.0;} else {
						#ifdef GRASS_DETECT_FALLOFF
							blockWest = GetVoxelBlock(ivec3(LPVpos.x - 1.0, LPVpos.y, LPVpos.z));
							if(blockWest != 85) {vgrassSideCheck.y = -1.0;}
						#endif
					}
					if(blockSouth > 4000 || blockSouth == 12 || (blockSouth > 80 && blockSouth < 86) || blockSouth == 503 || (blockSouth > 406 && blockSouth < 440)) {vgrassSideCheck.z = 1.0;} else {
						#ifdef GRASS_DETECT_FALLOFF
							blockSouth = GetVoxelBlock(ivec3(LPVpos.x, LPVpos.y, LPVpos.z+ 1.0));
							if(blockSouth != 85) {vgrassSideCheck.z = -1.0;}
						#endif
					}
					if(blockNorth > 4000 || blockNorth == 12 || (blockNorth > 80 && blockNorth < 86) || blockNorth == 503 || (blockNorth > 406 && blockNorth < 440)) {vgrassSideCheck.w = 1.0;} else {
						#ifdef GRASS_DETECT_FALLOFF
							blockNorth = GetVoxelBlock(ivec3(LPVpos.x, LPVpos.y, LPVpos.z - 1.0));
							if(blockNorth != 85) {vgrassSideCheck.w = -1.0;}
						#endif
					}
					#ifndef GRASS_DETECT_INV_FALLOFF
						vgrassSideCheck = clamp(vgrassSideCheck, -1.0, 0.0);
					#endif
				}
				#endif
			}
		}

		vdiscardGrass = 0;
		#if REPLACE_SHORT_GRASS > 0
			#if GRASS_DENSITY == 3
				float maxShortGrassRange = 28.0;
			#elif GRASS_DENSITY == 2
				float maxShortGrassRange = 24.0;
			#elif GRASS_DENSITY == 2
				float maxShortGrassRange = 20.0;
			#else
				float maxShortGrassRange = 16.0;
			#endif

			if(length(worldpos) < maxShortGrassRange && vblockID == 12) {
				vcenterPosition = worldpos + at_midBlock.xyz / 64.0;
				vec3 LPVpos = GetLpvPosition(vcenterPosition);
				uint blockBelow = GetVoxelBlock(ivec3(LPVpos.x, LPVpos.y - 0.6, LPVpos.z));
				if(blockBelow == 85) vdiscardGrass = 1;
			}
		#endif
	#endif

	#ifdef WAVY_PLANTS
		// also use normal, so up/down facing geometry does not get detatched from its model parts.
		bool InterpolateFromBase = gl_MultiTexCoord0.t < max(mc_midTexCoord.t, abs(worldNormals.y));

		if(	
			(
				// these wave off of the ground. the area connected to the ground does not wave.
				(InterpolateFromBase && (mc_Entity.x == BLOCK_GRASS_TALL_LOWER || mc_Entity.x == BLOCK_GROUND_WAVING || mc_Entity.x == BLOCK_GRASS_SHORT || mc_Entity.x == BLOCK_SAPLING || mc_Entity.x == BLOCK_GROUND_WAVING_VERTICAL)) 

				// these wave off of the ceiling. the area connected to the ceiling does not wave.
				|| (!InterpolateFromBase && (mc_Entity.x == 17))

				// these wave off of the air. they wave uniformly
				|| (mc_Entity.x == BLOCK_GRASS_TALL_UPPER || mc_Entity.x == BLOCK_AIR_WAVING)

			) && abs(position.z) < 64.0
		){
			vec3 UnalteredWorldpos = worldpos;

			// vec3 offsetPos = UnalteredWorldpos+vec3(0.0, 1.0, 0.0)+relativeEyePosition;
            // float playerDist = smoothstep(0.5, 0.05, length(offsetPos.xz)) * smoothstep(1.0, 0.2, abs(offsetPos.y));
            // vec2 dir2 = normalize(UnalteredWorldpos.xz+relativeEyePosition.xz);

			// apply displacement for waving plant blocks
			worldpos += calcMovePlants(worldpos + cameraPosition) * max(vlmtexcoord.w,0.5);
			// worldpos.xz += playerDist*dir2;


			// apply displacement for waving leaf blocks specifically, overwriting the other waving mode. these wave off of the air. they wave uniformly
			if(mc_Entity.x == BLOCK_AIR_WAVING) worldpos = UnalteredWorldpos + calcMoveLeaves(worldpos + cameraPosition, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5))*vlmtexcoord.w;
		
		}
	#endif

	// position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;
	
	// ensure hand/entities have the same transformations as the spidereyes and enchant glint programs.
	#if !defined ENTITIES && !defined HAND
		gl_Position = vec4(worldpos, 0.0);
	#endif
#endif

	#if defined Seasons && defined WORLD && !defined ENTITIES && !defined BLOCKENTITIES && !defined HAND
		YearCycleColor(vcolor.rgb, gl_Color.rgb, mc_Entity.x == BLOCK_AIR_WAVING, true);
	#endif
}
