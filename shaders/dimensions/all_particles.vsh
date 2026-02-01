#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
#include "/lib/items.glsl"

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

out DATA {
	vec4 lmtexcoord;
	vec4 color;

	#if defined DAMAGE_BLOCK_EFFECT && defined POM
		vec4 tangent;
		vec3 normalMat;

		vec4 texcoordam; // .st for add, .pq for mul
		vec2 texcoord;
	#endif

	#ifdef OVERWORLD_SHADER
		flat vec3 WsunVec;
	#endif
};

uniform sampler2D colortex4;

#ifdef OVERWORLD_SHADER
	#include "/lib/scene_controller.glsl"
#endif

uniform vec3 sunPosition;
uniform float sunElevation;

uniform vec2 texelSize;
uniform int framemod8;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform ivec2 eyeBrightnessSmooth;

uniform int heldItemId;
uniform int heldItemId2;

#include "/lib/TAA_jitter.glsl"

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}

#if defined DAMAGE_BLOCK_EFFECT && defined POM
	in vec4 mc_midTexCoord;
	in vec4 at_tangent;
#endif

#ifdef LINES
	uniform int currentSelectedBlockId;
	uniform int renderStage;

	#include "/lib/blocks.glsl"

	const float PI48 = 150.796447372*WAVY_SPEED;
	float pi2wt = PI48*frameTimeCounter;

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
#endif

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	color = gl_Color;

	lmtexcoord.xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	vec2 lmcoord = gl_MultiTexCoord1.xy / 240.0;
	lmtexcoord.zw = lmcoord;

	#if defined DAMAGE_BLOCK_EFFECT && defined POM
		vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texcoordminusmid = lmtexcoord.xy-midcoord;
		texcoordam.pq  = abs(texcoordminusmid)*2;
		texcoordam.st  = min(lmtexcoord.xy,midcoord-texcoordminusmid);
		texcoord.xy    = sign(texcoordminusmid)*0.5+0.5;

		tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
		
		normalMat = normalize(gl_NormalMatrix * gl_Normal);
	#endif


	#if defined WEATHER || defined LINES
		vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
		vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;

		#ifdef WEATHER
			bool istopv = worldpos.y > 5.0 && lmtexcoord.w > 0.99;

			if(!istopv){
			worldpos += vec3(2.0,0.0,2.0) * min(max(clamp(eyeBrightnessSmooth.y/240.0,0,1)-0.95,0)/0.05,1);
			}
		#endif

		#ifdef PLANET_CURVATURE
			float curvature = length(worldpos.xz) / (16*8);
			worldpos.y -= curvature*curvature * CURVATURE_AMOUNT;
		#endif

		#ifdef LINES
			#if defined WAVY_PLANTS
				bool selectionBox = renderStage == MC_RENDER_STAGE_OUTLINE;
				if(currentSelectedBlockId == BLOCK_AIR_WAVING && abs(position.z) < 64.0 && selectionBox){
					// apply displacement for waving leaf blocks specifically, overwriting the other waving mode. these wave off of the air. they wave uniformly
					worldpos += calcMoveLeaves(worldpos + cameraPosition, vec3(1.0,0.2,1.0))*clamp(eyeBrightnessSmooth.y/240.0,0,1);
				}
			#endif
		#endif

			position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;

			gl_Position = toClipSpace3(position);
	#else
		vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
		vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;

		#ifdef PLANET_CURVATURE
			float curvature = length(worldpos.xz) / (16*8);
			worldpos.y -= curvature*curvature * CURVATURE_AMOUNT;
		#endif

		position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;

		gl_Position = toClipSpace3(position);
	#endif
	
	#ifdef OVERWORLD_SHADER		
		#ifdef SMOOTH_SUN_ROTATION
			WsunVec = WsunVecSmooth;
		#else
			WsunVec = float(sunElevation > 1e-5)*2.0 - 1.0 * normalize(mat3(gbufferModelViewInverse) * sunPosition);
		#endif
	#endif
	

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
	
	#ifndef WEATHER
		#ifdef TAA
			gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
		#endif
	#endif
}
