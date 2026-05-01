#include "/lib/settings.glsl"

#include "/lib/Shadow_Params.glsl"

#include "/lib/SSBOs.glsl"

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform int hideGUI;
uniform vec3 cameraPosition;
uniform vec3 relativeEyePosition;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform float screenBrightness;
uniform vec3 sunVec;
uniform float aspectRatio;
uniform float sunElevation;
uniform vec3 sunPosition;
uniform float lightSign;
uniform float cosFov;
uniform vec3 shadowViewDir;
uniform vec3 shadowCamera;
uniform vec3 shadowLightVec;
uniform float shadowMaxProj;

uniform int blockEntityId;
uniform int entityId;

out vec3 worldPos;
out vec3 cageNormal;
out vec3 color;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec4 toClipSpace3(vec3 viewSpacePosition) {

	// mat4 projection = DH_shadowProjectionTweak(gl_ProjectionMatrix);

    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),1.0);
}

#include "/lib/DistantHorizons_projections.glsl"


void main() {
	color = gl_Color.rgb;
	
	worldPos = vec3(0.0);
	cageNormal = gl_Normal;
	
	gl_Position = vec4(-1.0);

	#if defined OVERWORLD_SHADER
		vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;

		worldPos = mat3(shadowModelViewInverse) * position + shadowModelViewInverse[3].xyz;

		#ifdef CUSTOM_MOON_ROTATION
			position = mat3(customShadowMatrixSSBO) * worldPos + customShadowMatrixSSBO[3].xyz;
		#else
			position = mat3(shadowModelView) * worldPos + shadowModelView[3].xyz;
		#endif

		#ifdef DISTORT_SHADOWMAP
			gl_Position = BiasShadowProjection(toClipSpace3(position));
		#else
			gl_Position = toClipSpace3(position);
		#endif
		
		gl_Position.z /= 6.0;

	#elif defined END_SHADER && defined END_ISLAND_LIGHT
		vec3 shadowViewPos = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
		worldPos = mat3(shadowModelViewInverse) * shadowViewPos + shadowModelViewInverse[3].xyz;

		#ifdef PLANET_CURVATURE
			float curvature = length(worldPos.xz) / (16*8);
			worldPos.y -= curvature*curvature * CURVATURE_AMOUNT;
		#endif

		gl_Position = customShadowPerspectiveSSBO * customShadowMatrixSSBO * vec4(worldPos, 1.0);
	
		gl_Position.z /= 6.0;
	#endif
}