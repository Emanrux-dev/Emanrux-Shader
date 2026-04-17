#include "/lib/settings.glsl"

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
        ray.direction = mat3(shadowModelViewInverse) * vec3(0.0f, 0.0f, -1.0f);
        ray_constraint = ivec3(ray.origin);
        trace_ray(ray);

        if (!ray.result_hit) {
            discard;
        }

        vec4 shadowColor = vec4(ray.result_color, 1.0f);

        gl_FragData[0] = shadowColor;
    #endif
}