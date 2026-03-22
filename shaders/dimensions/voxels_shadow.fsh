#include "/lib/settings.glsl"
#include "/lib/SSBOs.glsl"

in vec3 worldPos;
in vec3 cageNormal;
in vec3 color;

uniform int frameCounter, frameTime;
uniform float viewWidth, viewHeight;

uniform vec3 cameraPosition;

uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

uniform sampler2D depthtex0;

#include "/photonics/photonics.glsl"

void main() {
    #ifdef NETHER_SHADER
        discard;
    #else
        RayJob ray = RayJob(vec3(0), vec3(0), vec3(0), vec3(0), vec3(0), false);
        ray.origin = worldPos + cameraPosition - world_offset - 0.01f * cageNormal;

        #ifdef CUSTOM_MOON_ROTATION
            ray.direction = mat3(customShadowMatrixInverseSSBO) * vec3(0.0f, 0.0f, -1.0f);
        #else
            ray.direction = mat3(shadowModelViewInverse) * vec3(0.0f, 0.0f, -1.0f);
        #endif

        ray_constraint = ivec3(ray.origin);
        trace_ray(ray);

        if (!ray.result_hit) {
            discard;
        }

        vec4 shadowColor = vec4(ray.result_color, 1.0f);

        vec3 playerpos = ray.result_position - (cameraPosition - world_offset);

        #ifdef OVERWORLD_SHADER
            #ifdef CUSTOM_MOON_ROTATION
                vec3 viewPos = mat3(customShadowMatrixSSBO) * playerpos + customShadowMatrixSSBO[3].xyz;
            #else
                vec3 viewPos = mat3(shadowModelView) * playerpos + shadowModelView[3].xyz;
            #endif

            vec4 ndc4 = shadowProjection * vec4(viewPos, 1.0f);

            ndc4.z /=  6.0;
            vec3 screenPos = ndc4.xyz / ndc4.w * 0.5f + 0.5f;
        #endif

        #if defined END_ISLAND_LIGHT && defined END_SHADER
            vec4 ndc4 = customShadowPerspectiveSSBO * customShadowMatrixSSBO * vec4(playerpos, 1.0);
            ndc4.z /= 6.0;

            vec3 screenPos = ndc4.xyz / ndc4.w * 0.5f + 0.5f;
        #endif

        #if defined END_ISLAND_LIGHT && defined END_SHADER || defined OVERWORLD_SHADER
            gl_FragDepth = screenPos.z;
        #endif

        gl_FragData[0] = shadowColor;
    #endif
}

