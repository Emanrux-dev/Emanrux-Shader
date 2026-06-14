#version 430 compatibility
#define END_SHADER
#include "/lib/SSBOs.glsl"

#extension GL_ARB_explicit_attrib_location: enable
#extension GL_ARB_shader_image_load_store: enable

#include "/lib/settings.glsl"

#include "/lib/Shadow_Params.glsl"

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec4 toClipSpace3(vec3 viewSpacePosition) {
    return customShadowPerspectiveSSBO * vec4(viewSpacePosition, 1.0);
}

#define RENDER_SHADOW
#define ENTITIES_SHADOW

out DATA {
	float LIGHTNING;
	vec4 color;
	vec2 texcoord;
};

#if defined IS_LPV_ENABLED || defined END_ISLAND_LIGHT || (WATER_INTERACTION == 2 && IRIS_VERSION < 11004) || defined SHADER_GRASS
	uniform int renderStage;
	uniform mat4 shadowModelViewInverse;
	uniform int entityId;

	#include "/lib/entities.glsl"
#endif

#include "/lib/blocks.glsl"
in vec4 mc_Entity;

#if defined IS_LPV_ENABLED || (WATER_INTERACTION == 2 && IRIS_VERSION < 11004) || defined SHADER_GRASS
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

	#include "/lib/voxel_common.glsl"
	#include "/lib/voxel_write.glsl"
#endif

void main() {
	#if defined END_ISLAND_LIGHT || (defined IS_LPV_ENABLED && defined MC_GL_ARB_shader_image_load_store) || (WATER_INTERACTION == 2 && IRIS_VERSION < 11004) || defined SHADER_GRASS
		vec3 shadowViewPos = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
		vec3 feetPlayerPos = mat3(shadowModelViewInverse) * shadowViewPos + shadowModelViewInverse[3].xyz;
	#endif

	#if (defined IS_LPV_ENABLED && defined MC_GL_ARB_shader_image_load_store) || (WATER_INTERACTION == 2 && IRIS_VERSION < 11004) || defined SHADER_GRASS
		#ifdef LPV_NOSHADOW_HACK
			vec3 playerpos = gl_Vertex.xyz;
		#else
			vec3 playerpos = feetPlayerPos;
		#endif

		PopulateShadowVoxel(playerpos);
	#endif

	#ifdef END_ISLAND_LIGHT
		texcoord.xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		color = gl_Color;

		vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
		LIGHTNING = 0.0;
		if (renderStage == MC_RENDER_STAGE_ENTITIES && (entityId == ENTITY_LIGHTNING || (entityId == 0 && gl_Color.a < 0.2 && abs(normal.y) < 0.2))) LIGHTNING = 1.0;

		#ifdef PLANET_CURVATURE
			float curvature = length(feetPlayerPos.xz) / (16.0 * 8.0);
			feetPlayerPos.y -= curvature * curvature * CURVATURE_AMOUNT;
		#endif

		bool hideEntityShadow =
			entityId == ENTITY_SHADOW ||
			entityId == ENTITY_NAME_TAG ||
			(renderStage == MC_RENDER_STAGE_ENTITIES && entityId == 0 && gl_Color.a < 0.35 && length(feetPlayerPos) < 32.0);

		if (hideEntityShadow) {
			gl_Position = vec4(-1.0);
		} else {
			gl_Position = customShadowPerspectiveSSBO * customShadowMatrixSSBO * vec4(feetPlayerPos, 1.0);
			gl_Position = BiasShadowProjection(gl_Position);
	
  			gl_Position.z /= 6.0;

			if(mc_Entity.x == BLOCK_WATER) gl_Position = vec4(-1.0);
		}
	#else
		gl_Position = vec4(-1.0);
	#endif
}
