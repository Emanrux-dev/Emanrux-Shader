#include "/lib/settings.glsl"

uniform sampler2D colortex4;
uniform sampler2D colortex1;
uniform sampler2D colortex12;

uniform vec2 texelSize;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef DISTANT_HORIZONS
	uniform sampler2D dhDepthTex;
	uniform sampler2D dhDepthTex1;
	#define dhVoxyDepthTex dhDepthTex
	#define dhVoxyDepthTex1 dhDepthTex1
#endif

#ifdef VOXY
	uniform sampler2D vxDepthTexOpaque;
	uniform sampler2D vxDepthTexTrans;
	#define dhVoxyDepthTex vxDepthTexTrans
	#define dhVoxyDepthTex1 vxDepthTexOpaque
#endif
uniform float near;
uniform float far;
uniform float dhVoxyFarPlane;
uniform float dhVoxyNearPlane;

float linZ(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}
float DH_ld(float dist) {
    return (2.0 * dhVoxyNearPlane) / (dhVoxyFarPlane + dhVoxyNearPlane - dist * (dhVoxyFarPlane - dhVoxyNearPlane));
}
float DH_invLinZ (float lindepth){
	return -((2.0*dhVoxyNearPlane/lindepth)-dhVoxyFarPlane-dhVoxyNearPlane)/(dhVoxyFarPlane-dhVoxyNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}

void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}
vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
/* RENDERTARGETS:4,12 */
	vec3 oldTex = texelFetch2D(colortex4, ivec2(gl_FragCoord.xy), 0).xyz;
	float newTex = texelFetch2D(depthtex1, ivec2(gl_FragCoord.xy*4.), 0).x;

	float dataUnpacked = decodeVec2(texelFetch2D(colortex1,ivec2(gl_FragCoord.xy*4.),0).w).y; 
	bool hand = abs(dataUnpacked-0.75) < 0.01;

	if(hand) convertHandDepth(newTex);

    #if defined DISTANT_HORIZONS || defined VOXY
        float QuarterResDepth = texelFetch2D(dhVoxyDepthTex, ivec2(gl_FragCoord.xy*4), 0).x;
        if(newTex == 1.0) {
            float depth = DH_ld(QuarterResDepth);
            gl_FragData[0] = vec4(oldTex, 650000.0);
        } else {
            float depth = linZ(newTex);
            gl_FragData[0] = vec4(oldTex, depth * depth * 65000.0);
        }

        // sky
        if (newTex == 1.0 && QuarterResDepth == 1.0) { 
            gl_FragData[0] = vec4(oldTex, 65000.0);
        }
        
        float depth = newTex;
		float _near = near;
		float _far = far*4.0;
		if (depth >= 1.0) {
			depth = QuarterResDepth;
			_near = dhVoxyNearPlane;
			_far = dhVoxyFarPlane;
		}

		depth = linearizeDepthFast(depth, _near, _far);
		depth = depth / dhVoxyFarPlane;

        if(depth < 1.0) {
		    gl_FragData[1].a = depth * depth * 65000.0;
        } else {
            gl_FragData[1].a = 66000.0;
        }
    #else
        if(newTex < 1.0) {
            float depth = linZ(newTex);
            gl_FragData[0] = vec4(oldTex, depth * depth * 65000.0);
        } else {
            // sky
            gl_FragData[0] = vec4(oldTex, 65000.0);
        }
    #endif
}