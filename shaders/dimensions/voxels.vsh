#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/bokeh.glsl"
#include "/lib/blocks.glsl"
#include "/lib/entities.glsl"
#include "/lib/items.glsl"

#include "/lib/SSBOs.glsl"

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



out DATA {
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
} data_out;

#ifdef MC_NORMAL_MAP
	in vec4 at_tangent;
#endif

uniform float frameTimeCounter;
const float PI48 = 150.796447372*WAVY_SPEED;
float pi2wt = PI48*frameTimeCounter;

in vec4 mc_Entity;
in vec4 mc_midTexCoord;

uniform int blockEntityId;
uniform int entityId;


uniform int heldItemId;
uniform int heldItemId2;

#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
	in vec4 at_midBlock;
#else
	in vec3 at_midBlock;
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
	uniform vec3 cameraPositionFract;

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

vec3 calcWaveLeaves(in vec3 pos) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec3 ret = (sin(pi2wt*vec3(0.0063,0.0224,0.0015)*1.5 - pos))*magnitude;

    return ret;
}

vec3 calcMoveLeaves(in vec3 pos, in vec3 amp1) {
    vec3 move1 = calcWaveLeaves(pos) * amp1;
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

uniform int framemod8;


#include "/lib/TAA_jitter.glsl"


uniform sampler2D noisetex;//depth
float densityAtPos(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	
	//The y channel has an offset to avoid using two textures fetches
	vec2 xy = texture(noisetex, coord).yx;

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
#if defined IRIS_FEATURE_FADE_VARIABLE && VANILLA_CHUNK_FADING > 1
	uniform float caveDetection;
#endif

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	gl_Position =  gl_ModelViewProjectionMatrix * gl_Vertex;

	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;

	#if defined IRIS_FEATURE_FADE_VARIABLE && VANILLA_CHUNK_FADING > 0 && !defined HAND
		data_out.chunkFade = abs(mc_chunkFade);
	#endif

    /////// ----- COLOR STUFF ----- ///////
	data_out.color = gl_Color;
    data_out.block_normal = gl_Normal;

    /////// ----- RANDOM STUFF ----- ///////
	// gl_TextureMatrix[0] for animated things like charged creepers
	data_out.lmtexcoord.xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	data_out.lmtexcoord.zw = gl_MultiTexCoord1.xy / 240.0; 

	#ifdef MC_NORMAL_MAP
		data_out.tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
	#endif

	data_out.normalMat = normalize(gl_NormalMatrix * gl_Normal);

   	vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;

	vec3 worldNormals = viewToWorld(data_out.normalMat);

	// position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;

    #if defined PLANET_CURVATURE
        float curvature = length(worldpos.xz) / (16.0*8.0);
        worldpos.y -= curvature*curvature * CURVATURE_AMOUNT;
    #endif

    gl_Position = toClipSpace3(mat3(gbufferModelView) * vec3(worldpos) + gbufferModelView[3].xyz);

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

}