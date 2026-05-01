#include "/lib/settings.glsl"
#include "/lib/SSBOs.glsl"

uniform sampler2D colortex1;// albedo, detailed_normal
uniform sampler2D colortex8;// flat_normal

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float near;
uniform float far;
uniform float worldTime;

uniform vec2 taa_offset;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform vec2 texelSize;
uniform float skyLightLevelSmooth;
uniform int framemod8;
uniform float sunElevation;

#include "/photonics/photonics.glsl"

#include "/lib/res_params.glsl"

#include "/lib/util.glsl"

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

#include "/lib/DistantHorizons_projections.glsl"

#include "/lib/TAA_jitter.glsl"

#ifdef TAA
    vec2 TAA_Offset = offsets[framemod8];
#else
    vec2 TAA_Offset = vec2(0.0);
#endif

vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}


#define load_tex_coord gl_FragCoord.xy * texelSize

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

vec3 decode (vec2 encn){
    vec3 n = vec3(0.0);
    encn = encn * 2.0 - 1.0;
    n.xy = abs(encn);
    n.z = 1.0 - n.x - n.y;
    n.xy = n.z <= 0.0 ? (1.0 - n.yx) * sign(encn) : encn;
    return clamp(normalize(n.xyz),-1.0,1.0);
}

#ifdef DISTANT_HORIZONS
	uniform sampler2D dhDepthTex;
	#define dhVoxyDepthTex dhDepthTex
#endif

#ifdef VOXY
	uniform sampler2D vxDepthTexTrans;
	#define dhVoxyDepthTex vxDepthTexTrans
#endif

vec3 load_world_position() {
    float z =  texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x;

    vec3 viewPos = toScreenSpace(vec3(load_tex_coord/RENDER_SCALE - TAA_Offset*texelSize*0.5, z));

    vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    return feetPlayerPos + world_camera_position;
}

void load_fragment_variables(out vec3 albedo, out vec3 world_pos, out vec3 world_normal, out vec3 world_normal_mapped) {
    vec4 data = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);

    vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y)); // albedo, masks
	vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w)); // normals, lightmaps

	albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));

    world_normal_mapped = decode(dataUnpacked0.yw);

    vec4 SpecularData = texelFetch(colortex8, ivec2(gl_FragCoord.xy), 0);
    vec4 specdataUnpacked0 = vec4(decodeVec2(SpecularData.x),decodeVec2(SpecularData.y));
    vec4 specdataUnpacked1 = vec4(decodeVec2(SpecularData.z),decodeVec2(SpecularData.w));

    world_normal = normalize(vec3(specdataUnpacked0.yw,specdataUnpacked1.y) * 2.0 - 1.0);

    world_pos = load_world_position() - 0.01f * world_normal;
}


vec3 getCurrentLightsource() {
    float lightSourceCheck = float(sunElevation > 1e-5)*2.0 - 1.0;

    #ifdef OVERWORLD
        #ifdef SMOOTH_SUN_ROTATION
            vec3 WsunVec = WsunVecSmooth;
        #else
            vec3 WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);
        #endif

        #ifdef CUSTOM_MOON_ROTATION
            #if LIGHTNING_SHADOWS > 0
                vec3 WmoonVec = customMoonVec2SSBO;
            #else	
                vec3 WmoonVec = customMoonVecSSBO;
            #endif
        #else
            #ifdef SMOOTH_MOON_ROTATION
                vec3 WmoonVec = WmoonVecSmooth;
            #else
                vec3 WmoonVec = normalize(mat3(gbufferModelViewInverse) * moonPosition);
            #endif
            if(dot(-WmoonVec, WsunVec) < 0.9999) WmoonVec = -WmoonVec;
        #endif

        WsunVec = mix(WmoonVec, WsunVec, clamp(lightSourceCheck,0,1));
    #else
        vec3 WmoonVec = vec3(0.0, 1.0, 0.0);
        vec3 WsunVec = vec3(0.0, 1.0, 0.0);
    #endif

    return WsunVec;
}

vec3 sun_direction = normalize(getCurrentLightsource());

vec3 AmbientLightColor = averageSkyCol_CloudsSSBO/1200.0;
vec3 indirect_light_color = AmbientLightColor * ambient_brightness; 

vec2 get_taa_jitter() {
    #ifdef TAA
        return vec2(offsets[framemod8]*0.5*texelSize);
    #else
        return vec2(0.0);
    #endif
}

bool is_in_world() {
    return texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x <= 0.9999f;
}