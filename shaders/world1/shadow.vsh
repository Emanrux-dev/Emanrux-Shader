#version 430 compatibility
#include "/lib/SSBOs.glsl"


#extension GL_ARB_explicit_attrib_location: enable
#extension GL_ARB_shader_image_load_store: enable

#include "/lib/settings.glsl"

#define RENDER_SHADOW


/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/
#if defined IS_LPV_ENABLED || defined END_ISLAND_LIGHT || WATER_INTERACTION == 2 || defined SHADER_GRASS
	uniform int renderStage;
	uniform mat4 shadowModelViewInverse;
	uniform int entityId;

	#include "/lib/entities.glsl"
#endif

#if defined IS_LPV_ENABLED || WATER_INTERACTION == 2  || defined SHADER_GRASS
	attribute vec4 mc_Entity;
	#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
		attribute vec4 at_midBlock;
	#else
		attribute vec3 at_midBlock;
	#endif
	attribute vec3 vaPosition;
	
	uniform vec3 chunkOffset;
	uniform vec3 cameraPosition;
	uniform vec3 relativeEyePosition;
    uniform int currentRenderedItemId;
	uniform int blockEntityId;

	#include "/lib/blocks.glsl"
	#include "/lib/voxel_common.glsl"
	#include "/lib/voxel_write.glsl"
#endif

varying float LIGHTNING;
// out float entity;
varying vec4 color;

varying vec2 texcoord;


//#include "/lib/Shadow_Params.glsl"

// uniform int entityId;


void main() {
	#if defined END_ISLAND_LIGHT || (defined IS_LPV_ENABLED && defined MC_GL_EXT_shader_image_load_store)
		vec3 shadowViewPos = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
		vec3 feetPlayerPos = mat3(shadowModelViewInverse) * shadowViewPos + shadowModelViewInverse[3].xyz;
	#endif

	#if defined IS_LPV_ENABLED && defined MC_GL_EXT_shader_image_load_store || WATER_INTERACTION == 2  || defined SHADER_GRASS
		#ifdef LPV_NOSHADOW_HACK
			vec3 playerpos = gl_Vertex.xyz;
		#else
			vec3 playerpos = feetPlayerPos;
		#endif
			
		PopulateShadowVoxel(playerpos);
	#endif

	#ifdef END_ISLAND_LIGHT
		texcoord.xy = gl_MultiTexCoord0.xy;
		color = gl_Color;

		// hide lightning and dragon death beams
		vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
		LIGHTNING = 0.0;
		if (renderStage == MC_RENDER_STAGE_ENTITIES && (entityId == ENTITY_LIGHTNING || (entityId == 0 && gl_Color.a < 0.2 && abs(normal.y) < 0.2))) LIGHTNING = 1.0;

		#ifdef PLANET_CURVATURE
			float curvature = length(feetPlayerPos) / (16*8);
			feetPlayerPos.y -= curvature*curvature * CURVATURE_AMOUNT;
		#endif

		gl_Position = customShadowPerspectiveSSBO * customShadowMatrixSSBO * vec4(feetPlayerPos, 1.0);
	
  		gl_Position.z /= 6.0;
	#else
		gl_Position = vec4(-1.0);
	#endif
}
