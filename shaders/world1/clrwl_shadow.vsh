#version 430 compatibility

#if defined IS_LPV_ENABLED
	#extension GL_ARB_explicit_attrib_location: enable
	#extension GL_ARB_shader_image_load_store: enable
#endif

#define COLORWHEEL

#include "/lib/SSBOs.glsl"

#include "/lib/settings.glsl"

#define RENDER_SHADOW

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/
#if defined IS_LPV_ENABLED || defined END_ISLAND_LIGHT
	uniform int renderStage;
	uniform mat4 shadowModelViewInverse;
	uniform int entityId;

	#include "/lib/entities.glsl"
#endif

#if defined IS_LPV_ENABLED
	in vec4 mc_Entity;
	#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
		in vec4 at_midBlock;
	#else
		in vec3 at_midBlock;
	#endif
	in vec3 vaPosition;
	
	uniform vec3 chunkOffset;
	uniform vec3 cameraPosition;
	uniform vec3 relativeEyePosition;
    uniform int currentRenderedItemId;
	uniform int blockEntityId;

	#include "/lib/blocks.glsl"
	#include "/lib/voxel_common.glsl"
	#include "/lib/voxel_write.glsl"
#endif

// out float entity;
out vec4 color;

out vec2 texcoord;


//#include "/lib/Shadow_Params.glsl"

// uniform int entityId;


void main() {
	#if defined END_ISLAND_LIGHT || (defined IS_LPV_ENABLED && defined MC_GL_ARB_shader_image_load_store)
		vec3 shadowViewPos = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
		vec3 feetPlayerPos = mat3(shadowModelViewInverse) * shadowViewPos + shadowModelViewInverse[3].xyz;
	#endif

	#if defined IS_LPV_ENABLED && defined MC_GL_ARB_shader_image_load_store
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

		#ifdef PLANET_CURVATURE
			float curvature = length(feetPlayerPos.xz) / (16*8);
			feetPlayerPos.y -= curvature*curvature * CURVATURE_AMOUNT;
		#endif

		gl_Position = customShadowPerspectiveSSBO * customShadowMatrixSSBO * vec4(feetPlayerPos, 1.0);
	
  		gl_Position.z /= 6.0;
	#else
		gl_Position = vec4(-1.0);
	#endif
}
