#ifdef IS_LPV_ENABLED
	#extension GL_ARB_shader_image_load_store: enable
	#extension GL_ARB_shading_language_packing: enable
#endif
 
uniform vec3 relativeEyePosition;

#include "/lib/projections.glsl"

uniform int frameCounter;
uniform float frameTimeCounter;

#include "/lib/settings.glsl"

#include "/lib/SSBOs.glsl"

#undef FLASHLIGHT_BOUNCED_INDIRECT

#if MC_VERSION >= 12110
#define MAIN_SHADOW_PASS
#endif

// #if defined END_SHADER || defined NETHER_SHADER
// 	#undef IS_LPV_ENABLED
// #endif

#include "/lib/res_params.glsl"

in DATA {
	vec4 lmtexcoord;
	vec4 color;

	vec3 viewVector;

	vec4 normalMat;
	vec4 tangent;

	#if defined IRIS_FEATURE_FADE_VARIABLE && VANILLA_CHUNK_FADING > 0 && !defined HAND
		float chunkFade;
	#endif

	#ifdef OVERWORLD_SHADER
		flat vec3 WsunVec;
	#endif

	#if defined ENTITIES && defined IS_IRIS
		flat int NAMETAG;
	#endif

	#if defined ENTITIES
		flat int ENTITY_SHADOW_LIKE;
	#endif

	flat int blockID;

	#ifdef LARGE_WAVE_DISPLACEMENT
		vec3 largeWaveDisplacementNormal;
	#endif

	#ifdef LIGHTNING
		float LIGHTNING_BOLT;
	#endif
};

uniform vec4 entityColor;

#if defined OVERWORLD_SHADER || (defined END_ISLAND_LIGHT && defined END_SHADER)
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;
	
	#ifdef TRANSLUCENT_COLORED_SHADOWS
		uniform sampler2D shadowcolor0;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2DShadow shadowtex1;
	#endif

	uniform float lightSign;
#endif

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform float snowAmount;
uniform bool isSnowBiome;
uniform bool isAridBiome;

#ifdef DISTANT_HORIZONS
	uniform sampler2D dhDepthTex1;
	#define dhVoxyDepthTex1 dhDepthTex1
#endif

#ifdef VOXY
	uniform sampler2D vxDepthTexOpaque;
	#define dhVoxyDepthTex1 vxDepthTexOpaque
#endif

uniform sampler2D colortex7;
uniform sampler2D colortex9;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex14;
uniform sampler2D colortex5;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;

uniform sampler2D gtexture;
uniform sampler2D specular;
uniform sampler2D normals;

#ifdef IS_LPV_ENABLED
	uniform usampler1D texBlockData;
	uniform sampler3D texLpv1;
	uniform sampler3D texLpv2;
	uniform sampler3D texVoxelMask;
#endif

uniform vec3 sunVec;
uniform float near;
// uniform float far;
uniform float sunElevation;

uniform int isEyeInWater;
uniform float is_soul_burning;
uniform float rainStrength;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform ivec2 eyeBrightnessSmooth;
uniform float nightVision;


uniform vec2 texelSize;
uniform int framemod8;
uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;

uniform float moonIntensity;
uniform float sunIntensity;
uniform vec3 sunColor;
uniform vec3 nsunColor;

uniform int heldItemId;
uniform int heldItemId2;
uniform bool firstPersonCamera;

uniform float waterEnteredAltitude;

#if WATER_INTERACTION == 1
	uniform vec3 waterEnteredPosition;
	uniform float waterEnteredTime;
	uniform vec3 waterEnteredVelocity;

	uniform vec3 waterExitedPosition;
	uniform float waterExitedTime;
	uniform vec3 waterExitedVelocity;
#endif

#if WATER_INTERACTION == 2
	#ifdef PIXELATED_WAVES
		layout (rgba16f) uniform readonly image2D waveSim2;
	#else
		uniform sampler2D waveSim2Sampler;
	#endif
#endif

uniform float dhVoxyNearPlane;
uniform float dhVoxyFarPlane;

#include "/lib/util.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/color_transforms.glsl"

#include "/lib/DistantHorizons_projections.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"

#ifdef IRIS_FEATURE_TEXTURE_FILTERING
#include "/lib/texture_filtering.glsl"
#endif



#ifdef OVERWORLD_SHADER
	#include "/lib/lightning_stuff.glsl"
	
	#include "/lib/scene_controller.glsl"
	
	#define CLOUDSHADOWSONLY
	#include "/lib/volumetricClouds.glsl"

#endif

#ifdef END_SHADER
	#include "/lib/end_fog.glsl"
#endif

#ifdef IS_LPV_ENABLED
	#include "/lib/hsv.glsl"
	#include "/lib/lpv_common.glsl"
	#include "/lib/lpv_render.glsl"
        #include "/lib/voxel_common.glsl"
#endif

#define FORWARD_SPECULAR
#define FORWARD_SSR_QUALITY 15 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 200 300 400 500]
#define FORWARD_BACKGROUND_REFLECTION
// #define FORWARD_ROUGH_REFLECTION





vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

#include "/lib/blocks.glsl"
#include "/lib/lpv_blocks.glsl"
#include "/lib/lpv_buffer.glsl"

#if defined VIVECRAFT
	uniform bool vivecraftIsVR;
	uniform vec3 vivecraftRelativeMainHandPos;
	uniform vec3 vivecraftRelativeOffHandPos;
	uniform mat4 vivecraftRelativeMainHandRot;
	uniform mat4 vivecraftRelativeOffHandRot;
#endif

#define VOXEL_REFLECTIONS_TRANSLUCENT

#ifdef VOXEL_REFLECTIONS_TRANSLUCENT
#endif

#ifdef PHOTONICS
	#ifdef VOXEL_REFLECTIONS
		#define PHOTONICS_INCLUDED

		#include "/photonics/photonics.glsl"
	#endif
#endif

#include "/lib/diffuse_lighting.glsl"

#if defined PHYSICSMOD_OCEAN_SHADER
	#include "/lib/oceans.glsl"
#endif


float interleaved_gradientNoise_temporal(){
	#ifdef TAA
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887);
	#endif
}

float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

float R2_dither(){
	vec2 coord = gl_FragCoord.xy ;

	#ifdef TAA
		coord += + (frameCounter%40000) * 2.0;
	#endif
	
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

float blueNoise(){
	#ifdef TAA
  		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887);
	#endif
}

#include "/lib/TAA_jitter.glsl"

vec3 getParallaxDisplacement(vec3 waterPos, vec3 playerPos) {

	float largeWaves = texture(noisetex, waterPos.xy / 600.0 ).b;
	float largeWavesCurved = pow(1.0-pow(1.0-largeWaves,2.5),4.5);
	largeWavesCurved = mix(1.0-largeWavesCurved, largeWavesCurved, PATCHY_WAVE_BLEND);

	float waterHeight = getWaterHeightmap(waterPos.xy, largeWaves, largeWavesCurved);
	// waterHeight = exp(-20.0*sqrt(waterHeight));
	waterHeight = exp(-7.0*exp(-7.0*waterHeight)) * 0.25;
	
	vec3 parallaxPos = waterPos;

	parallaxPos.xy += (viewVector.xy / -viewVector.z) * waterHeight;

	return parallaxPos;
}

vec3 applyBump(mat3 tbnMatrix, vec3 bump, float mult, vec3 rippleBump){
	float bumpmult = mult;
	bump = bump * bumpmult + vec3(0.0f, 0.0f, 1.0f - bumpmult);

	#if defined PHYSICSMOD_OCEAN_SHADER && defined PHYSICS_OCEAN
		bump += 4.0 * rippleBump;
	#endif
	
	return normalize(bump*tbnMatrix);
}

vec2 CleanSample(
	int samples, float totalSamples, float noise
){

	// this will be used to make 1 full rotation of the spiral. the mulitplication is so it does nearly a single rotation, instead of going past where it started
	float variance = noise * 0.897;

	// for every sample input, it will have variance applied to it.
	float variedSamples = float(samples) + variance;
	
	// for every sample, the sample position must change its distance from the origin.
	// otherwise, you will just have a circle.
    float spiralShape = sqrt(variedSamples / (totalSamples + variance));

	float shape = 2.26; // this is very important. 2.26 is very specific
    float theta = variedSamples * (PI * shape);

	float x =  cos(theta) * spiralShape;
	float y =  sin(theta) * spiralShape;

    return vec2(x, y);
}

vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos ;
    return pos.xyz;
}

vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}

vec4 encode (vec3 n, vec2 lightmaps){
	n.xy = n.xy / dot(abs(n), vec3(1.0));
	n.xy = n.z <= 0.0 ? (1.0 - abs(n.yx)) * sign(n.xy) : n.xy;
    vec2 encn = clamp(n.xy * 0.5 + 0.5,-1.0,1.0);
	
    return vec4(encn,vec2(lightmaps.x,lightmaps.y));
}

//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}

float encodeVec2(float x,float y){
    return encodeVec2(vec2(x,y));
}

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

bool IsGlassVoxelId(uint id) {
	return (id >= 301u && id <= 318u) || id == 516u;
}

bool IsColoredGlassVoxelId(uint id) {
	return id >= 302u && id <= 317u;
}

vec3 GlassTintSrgbFromId(uint id, vec3 fallback) {
	vec3 tint = fallback;
	if (id == 302u) tint = vec3(0.04, 0.04, 0.05);
	else if (id == 303u) tint = vec3(0.10, 0.18, 0.95);
	else if (id == 304u) tint = vec3(0.42, 0.24, 0.12);
	else if (id == 305u) tint = vec3(0.00, 0.68, 0.78);
	else if (id == 306u) tint = vec3(0.25, 0.27, 0.30);
	else if (id == 307u) tint = vec3(0.18, 0.55, 0.10);
	else if (id == 308u) tint = vec3(0.34, 0.72, 1.00);
	else if (id == 309u) tint = vec3(0.66, 0.66, 0.64);
	else if (id == 310u) tint = vec3(0.56, 0.98, 0.13);
	else if (id == 311u) tint = vec3(0.84, 0.22, 0.90);
	else if (id == 312u) tint = vec3(1.00, 0.54, 0.07);
	else if (id == 313u) tint = vec3(1.00, 0.54, 0.76);
	else if (id == 314u) tint = vec3(0.46, 0.17, 0.82);
	else if (id == 315u) tint = vec3(0.95, 0.08, 0.06);
	else if (id == 316u) tint = vec3(0.96);
	else if (id == 317u) tint = vec3(1.00, 0.90, 0.10);
	else if (id == 318u) tint = vec3(0.22, 0.24, 0.26);
	return clamp(tint, vec3(0.02), vec3(1.0));
}



#ifdef RIPPLE_WATER
	#include "/lib/ripples.glsl"
	uniform float rippleAmount;
#endif

// #undef BASIC_SHADOW_FILTER

#if defined OVERWORLD_SHADER || (defined END_SHADER && defined END_ISLAND_LIGHT)

#include "/lib/Shadows.glsl"

vec2 EndShadowKernelOffset(int i, int samples) {
	if (i == 0 || samples <= 1) return vec2(0.0);

	float fi = float(i);
	float radius = sqrt((fi - 0.5) / float(samples - 1));
	float angle = fi * 2.39996323;
	return vec2(cos(angle), sin(angle)) * radius;
}

float ComputeShadowMap(inout vec3 directLightColor, vec3 playerPos, float maxDistFade, float noise, in vec3 geoNormals){

	#ifdef OVERWORLD_SHADER
		#ifdef CUSTOM_MOON_ROTATION
			vec3 projectedShadowPosition = mat3(customShadowMatrixSSBO) * playerPos  + customShadowMatrixSSBO[3].xyz;
		#else
			vec3 projectedShadowPosition = mat3(shadowModelView) * playerPos + shadowModelView[3].xyz;
		#endif

		applyShadowBias(projectedShadowPosition, playerPos, geoNormals);

		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		#ifdef DISTORT_SHADOWMAP
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;
		#else
			float distortFactor = 1.0;
		#endif

		projectedShadowPosition.z += shadowProjection[3].z * 0.0012;
	#else
		float distortFactor = 1.0;
	#endif

	#if defined END_ISLAND_LIGHT && defined END_SHADER
		vec4 shadowPos = customShadowMatrixSSBO * vec4(playerPos, 1.0);
		applyShadowBias(shadowPos.xyz, playerPos, geoNormals);
		shadowPos =  customShadowPerspectiveSSBO * shadowPos;
		vec3 projectedShadowPosition = shadowPos.xyz / shadowPos.w;
		projectedShadowPosition.z -= 0.0035;
	#endif

	projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);
	
	float shadowmap = 0.0;
	vec3 translucentTint = vec3(0.0);

	#ifdef BASIC_SHADOW_FILTER
		#ifdef END_SHADER
			int samples = END_SHADOW_FILTER_SAMPLES;
			float rdMul = END_SHADOW_FILTER_RADIUS * distortFactor * d0k;
		#else
			int samples = int(SHADOW_FILTER_SAMPLE_COUNT * 0.5);
			float rdMul = 2.4*distortFactor*d0k;
		#endif

		for(int i = 0; i < samples; i++){
			#ifdef END_SHADER
				vec2 offsetS = EndShadowKernelOffset(i, samples) * rdMul;
			#else
				vec2 offsetS = CleanSample(i, samples - 1, noise) * rdMul;
			#endif
			vec3 sampleShadowPosition = projectedShadowPosition;
			sampleShadowPosition.xy += offsetS;
	#else
		int samples = 1;
		vec3 sampleShadowPosition = projectedShadowPosition;
	#endif
	

		#if defined TRANSLUCENT_COLORED_SHADOWS

			float shadowDepthDiff = pow(clamp((texture(shadowtex1, sampleShadowPosition).x - sampleShadowPosition.z) * 2.0,0.0,1.0),2.0);

			float opaqueShadow = texture(shadowtex0, sampleShadowPosition).x;
			shadowmap += max(opaqueShadow, shadowDepthDiff);

			vec4 translucentShadow = texture(shadowcolor0, sampleShadowPosition.xy);

			float shadowAlpha = pow(1.0 - pow(translucentShadow.a,5.0),0.2);

			translucentShadow.rgb = max(normalize(translucentShadow.rgb + 0.0001), max(opaqueShadow, 1.0-shadowAlpha)) * shadowAlpha;

			translucentTint += mix(translucentShadow.rgb, vec3(1.0),  opaqueShadow*shadowDepthDiff);

		#else
			shadowmap += texture(shadow, sampleShadowPosition).x;
		#endif

	#ifdef BASIC_SHADOW_FILTER
		}
	#endif

	#if defined TRANSLUCENT_COLORED_SHADOWS
		directLightColor *= mix(vec3(1.0), translucentTint.rgb / samples, maxDistFade);
	#endif

	float shadowResult = shadowmap / samples;

	#ifdef END_SHADER
	float r = length(projectedShadowPosition.xy - vec2(0.5));
	float endMapFade = (1.0 - smoothstep(0.44, 0.50, r)) * step(0.0, projectedShadowPosition.z) * step(projectedShadowPosition.z, 1.0);
	shadowResult = mix(1.0, shadowResult, endMapFade);
	#endif

	return shadowResult;
}
#endif

#include "/lib/specular.glsl"

void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}

void Emission(
	inout vec3 Lighting,
	vec3 Albedo,
	float Emission
){
	if( Emission < 254.5/255.0) Lighting = mix(Lighting, Albedo * 5.0 * Emissive_Brightness, pow(Emission, Emissive_Curve));
}

float bias(){
	// bias mipmapping as window resolution and / or render scale changes.
	#ifdef TAA_UPSCALING
		return (1.0 - texelSize.x * 2560.0) + (0.0 - (1.0-RENDER_SCALE.x) * 2.0);
	#else
		return 1.0 - texelSize.x * 2560.0;
	#endif
}

#if defined FLASHLIGHT_SHADOWS && defined FLASHLIGHT && defined MAIN_SHADOW_PASS
float SSRT_FlashLight_Shadows(vec3 viewPos, bool depthCheck, vec3 lightDir, float noise, vec3 normals, bool hand){
	
	if(hand || !firstPersonCamera) return 1.0;

	vec3 WlightDir = normalize((gbufferModelViewInverse*vec4(lightDir, 1.0)).xyz);

	float NdotL = dot(normals, WlightDir);
	NdotL = smoothstep(0.0, 0.2, abs(NdotL));

	float shadows = 1.0;
	float samples = 16.0;

	float _near = near; float _far = far*4.0;

	if (depthCheck) {
		_near = dhVoxyNearPlane;
		_far = dhVoxyFarPlane;
	}

	vec3 position = toClipSpace3_DH(viewPos, depthCheck) ;
	
	//prevents the ray from going behind the camera
	float rayLength = ((viewPos.z + lightDir.z * _far * sqrt(3.)) > -_near) ? (-_near - viewPos.z) / lightDir.z : _far * sqrt(3.);

	vec3 direction = toClipSpace3_DH(viewPos + lightDir*rayLength, depthCheck) - position;
	direction.xyz = direction.xyz / max(max(abs(direction.x)/0.0005, abs(direction.y)/0.0005),400.0);	//fixed step size
	direction *= 6.0;

	position.xy *= RENDER_SCALE;
	direction.xy *= RENDER_SCALE;
	
	vec3 newPos = position + direction*noise;
	// literally shadow bias to fight shadow acne due to precision problems when comparing sampled depth and marched position
	//newPos += direction*0.3;


	for (int i = 0; i < int(samples); i++) {
		float samplePos;
		
		#if defined DISTANT_HORIZONS || defined VOXY
			if(depthCheck) {
				samplePos = texelFetch(dhVoxyDepthTex1, ivec2(newPos.xy/texelSize),0).x;
			} else
		#endif
			{
				samplePos = texelFetch(depthtex2, ivec2(newPos.xy/texelSize),0).x,hand;
			}

		if(samplePos < newPos.z && samplePos > 0.0){// && (samplePos <= max(minZ,maxZ) && samplePos >= min(minZ,maxZ))){
			shadows = 0.0;
			break;
		} 
	
		newPos += direction;
	}

	return clamp(shadows*NdotL, 1.0-FLASHLIGHT_SHADOWS_STRENGTH, 1.0);
}
#endif

#ifdef RAIN_ON_GLASS
float RG_N(float t) {
    return fract(sin(t * 12345.564) * 7658.76);
}
vec3 RG_N13(float p) {
    vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec3((p3.x+p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

float RG_S(float a, float b, float t) {
    return clamp((t - a) / (b - a), 0.0, 1.0);
}

float RG_Saw(float b, float t) {
    float s = smoothstep(0.0, b, t);
    return s * smoothstep(1.0, b, t);
}

float RG_Bubble(vec2 p, vec2 center, float radius) {
    float d = length(p - center);
    float outer = smoothstep(radius, radius * 0.7, d);
    float inner = smoothstep(radius * 0.5, radius * 0.8, d);
    float rim = outer * inner;
    vec2 hlOfs = center + vec2(-radius * 0.3, radius * 0.35);
    float hl = smoothstep(radius * 0.25, 0.0, length(p - hlOfs)) * 0.9;
    return rim * 0.55 + hl;
}

vec4 RG_ComputeRealisticDrop(vec2 uv) {
    vec2 p = vec2(uv.x, 1.0 - uv.y) - 0.5;
    
    float elongation = 1.0 + clamp(-p.y * 2.0, 0.0, 1.0) * 2.8;
    vec2 p_body = vec2(p.x * elongation, p.y - 0.02);
    
    float topRadius = 2.5;
    float bottomRadius = 4.5;
    float verticalBias = mix(topRadius, bottomRadius, clamp(p.y * -2.0 + 0.5, 0.0, 1.0));
    float bodyD = length(p_body * vec2(verticalBias, 2.2));
    float bodyMask = smoothstep(0.52, 0.32, bodyD);
    
    float pendantY = 0.38;
    float pendantBulge = smoothstep(0.0, pendantY, -p.y) * 0.12;
    vec2 p_pendant = vec2(p.x * (5.5 + pendantBulge * 8.0), (p.y + 0.28) * 6.5);
    float pendantD = length(p_pendant);
    float pendantMask = smoothstep(0.55, 0.28, pendantD);
    
    float mask = clamp(bodyMask + pendantMask * 0.7, 0.0, 1.0);
    
    vec2 n2_body = p_body * vec2(verticalBias, 2.2) / 0.52;
    vec2 n2_pendant = p_pendant / 0.55;
    vec2 n2 = mix(n2_body, n2_pendant, pendantMask * (1.0 - bodyMask));
    n2 = clamp(n2 * 0.85, -1.0, 1.0);
    float z = sqrt(clamp(1.0 - dot(n2, n2), 0.0, 1.0));
    vec3 n = normalize(vec3(n2, z + 0.001));
    
    float fresnel = pow(1.0 - clamp(n.z, 0.0, 1.0), 4.0);
    float rim = fresnel * mask * 2.5;
    
    vec2 hlOfs = vec2(-0.06, 0.12);
    float hlD = length((p - hlOfs) * vec2(9.0, 7.0));
    float highlight = smoothstep(0.20, 0.0, hlD) * 2.8;
    
    vec2 hl2Ofs = vec2(0.05, -0.15);
    float hl2D = length((p - hl2Ofs) * vec2(12.0, 10.0));
    float highlight2 = smoothstep(0.15, 0.0, hl2D) * 1.2;
    
    float causticD = length(p_body * vec2(4.0, 1.8));
    float caustic = smoothstep(0.55, 0.25, causticD) * smoothstep(0.08, 0.35, causticD) * 0.28;
    
    float shadowD = length((p - vec2(0.0, -0.18)) * vec2(7.0, 5.0));
    float shadow = smoothstep(0.15, 0.55, shadowD) * 0.7 * bodyMask;
    
    float interiorGrad = smoothstep(0.52, 0.05, bodyD) * 0.18;
    float extras = rim + highlight + highlight2 + caustic + interiorGrad - shadow;
    
    return vec4(n.xy, extras, mask);
}
vec2 RG_DropPositionAt(float ti, float nx, float uniqueSeed, float pathType) {
    float fall = clamp(ti * ti * 0.6 + ti * 0.4, 0.0, 1.0);
    float y = 1.05 - fall * 1.18;

    float xOffset = 0.0;
    if (pathType < 0.25) {
        float lean = (fract(uniqueSeed * 2.1) - 0.5) * 2.2;
        xOffset = lean * fall;
    } else if (pathType < 0.50) {
        float seg1 = (fract(uniqueSeed * 3.3) - 0.5) * 1.8;
        float seg2 = (fract(uniqueSeed * 5.1) - 0.5) * 1.8;
        xOffset = mix(seg1 * clamp(fall * 3.0, 0.0, 1.0), seg2 * fall, smoothstep(0.25, 0.55, fall));
    } else if (pathType < 0.75) {
        float k1 = (fract(uniqueSeed * 4.7) - 0.5) * 1.6;
        float k2 = (fract(uniqueSeed * 6.3) - 0.5) * 1.4;
        float k3 = (fract(uniqueSeed * 8.1) - 0.5) * 1.2;
        xOffset = (k1 * smoothstep(0.0, 0.3, fall) + k2 * smoothstep(0.3, 0.6, fall) + k3 * smoothstep(0.6, 0.9, fall)) * fall;
    } else {
        float diag = (fract(uniqueSeed * 9.1) - 0.5) * 1.5;
        float wobble = sin(fall * 5.0 + uniqueSeed * 6.28) * 0.18;
        xOffset = (diag + wobble) * fall;
    }

    return vec2(nx + xOffset, y);
}

vec2 RG_ProjectFlowUV(vec2 uv, vec2 flowDir) {
    vec2 f = normalize(flowDir + vec2(0.0001, 0.0));
    vec2 side = vec2(-f.y, f.x);
    return vec2(dot(uv, side), dot(uv, f));
}

float RG_FaceInteriorMask(vec2 uv, float width) {
    return smoothstep(width, width + 0.025, uv.x) *
           smoothstep(width, width + 0.025, uv.y) *
           smoothstep(width, width + 0.025, 1.0 - uv.x) *
           smoothstep(width, width + 0.025, 1.0 - uv.y);
}

vec3 RG_GlassTintFromId(uint id, vec3 fallback) {
    vec3 tint = fallback;
    if (id == 302u) tint = vec3(0.03, 0.03, 0.04);
    else if (id == 303u) tint = vec3(0.08, 0.14, 0.80);
    else if (id == 304u) tint = vec3(0.36, 0.20, 0.10);
    else if (id == 305u) tint = vec3(0.00, 0.58, 0.68);
    else if (id == 306u) tint = vec3(0.20, 0.22, 0.24);
    else if (id == 307u) tint = vec3(0.14, 0.46, 0.08);
    else if (id == 308u) tint = vec3(0.30, 0.64, 0.95);
    else if (id == 309u) tint = vec3(0.58, 0.58, 0.56);
    else if (id == 310u) tint = vec3(0.48, 0.86, 0.10);
    else if (id == 311u) tint = vec3(0.72, 0.18, 0.78);
    else if (id == 312u) tint = vec3(0.96, 0.48, 0.06);
    else if (id == 313u) tint = vec3(0.96, 0.48, 0.68);
    else if (id == 314u) tint = vec3(0.38, 0.14, 0.68);
    else if (id == 315u) tint = vec3(0.78, 0.06, 0.04);
    else if (id == 316u) tint = vec3(0.92);
    else if (id == 317u) tint = vec3(0.98, 0.86, 0.08);
    else if (id == 318u) tint = vec3(0.18, 0.20, 0.22);
    return clamp(tint, vec3(0.02), vec3(1.0));
}

float RG_StaticDrops(vec2 uv, float t);

#ifdef IS_LPV_ENABLED
bool RG_IsRainOpenAbove(ivec3 voxelPos) {
    for (int stepY = 1; stepY <= 64; stepY++) {
        uint columnID = imageLoad(imgVoxelMask, voxelPos + ivec3(0, stepY, 0)).r;
        if (columnID == 0u || IsGlassVoxelId(columnID)) continue;
        return false;
    }
    return true;
}

bool RG_IsRainReachableFromSide(ivec3 glassVoxelPos, ivec3 sideStep) {
    for (int sideDist = 1; sideDist <= 10; sideDist++) {
        ivec3 sidePos = glassVoxelPos + sideStep * sideDist;
        uint sideID = imageLoad(imgVoxelMask, sidePos).r;
        if (sideID != 0u && !IsGlassVoxelId(sideID)) return false;
        if (RG_IsRainOpenAbove(sidePos)) return true;
    }
    return false;
}

bool RG_IsGlassRainExposed(ivec3 glassVoxelPos, vec3 worldNormal) {
    bool exposed = RG_IsRainOpenAbove(glassVoxelPos);
    exposed = exposed || RG_IsRainOpenAbove(glassVoxelPos + ivec3( 1, 0, 0));
    exposed = exposed || RG_IsRainOpenAbove(glassVoxelPos + ivec3(-1, 0, 0));
    exposed = exposed || RG_IsRainOpenAbove(glassVoxelPos + ivec3( 0, 0, 1));
    exposed = exposed || RG_IsRainOpenAbove(glassVoxelPos + ivec3( 0, 0,-1));
    exposed = exposed || RG_IsRainReachableFromSide(glassVoxelPos, ivec3( 1, 0, 0));
    exposed = exposed || RG_IsRainReachableFromSide(glassVoxelPos, ivec3(-1, 0, 0));
    exposed = exposed || RG_IsRainReachableFromSide(glassVoxelPos, ivec3( 0, 0, 1));
    exposed = exposed || RG_IsRainReachableFromSide(glassVoxelPos, ivec3( 0, 0,-1));
    return exposed;
}
#endif

vec4 RG_DropInCell(vec2 cellOffset, vec2 st, float t, vec2 grid, vec2 baseID, out float outSize, out float outSpeed, out float outSlip) {
    vec2 id = baseID + cellOffset;
    vec3 n = RG_N13(id.x * 35.2 + id.y * 2376.1 + 7.77);
    vec3 m = RG_N13(id.x * 71.5 + id.y * 119.3 + 3.14);

    float sizeRand = m.x;
    float sizeClass = sizeRand < 0.55 ? 0.62 : (sizeRand < 0.88 ? 1.0 : 1.45);
    float speed = (0.25 + n.y * 0.35) * mix(0.65, 1.1, smoothstep(0.5, 1.6, sizeClass));

    float ti = fract(t * speed + n.z);

    float pausePos = 0.2 + m.y * 0.5;
    float pauseLen = 0.05 + m.z * 0.1;
    float inPause = step(pausePos, ti) * step(ti, pausePos + pauseLen);
    float effectiveTi = ti - inPause * (ti - pausePos) * 0.98;

    float uniqueSeed = n.x * 17.3 + m.z * 31.7 + id.x * 0.137 + id.y * 0.091;
    float pathType = fract(uniqueSeed * 7.3);

    vec2 pos = RG_DropPositionAt(effectiveTi, n.x, uniqueSeed, pathType);
    vec2 posPrev = RG_DropPositionAt(max(effectiveTi - 0.018, 0.0), n.x, uniqueSeed, pathType);
    vec2 vel = (pos - posPrev) / 0.018;

    outSize = sizeClass;
    outSpeed = speed;
    outSlip = smoothstep(0.05, 0.5, effectiveTi);

    return vec4(pos, vel);
}
vec3 RG_DropLayer2(vec2 uv, float t) {
    uv.y += t * 0.58;
    vec2 grid = vec2(12.0, 6.0);
    vec2 id0 = floor(uv * grid);
    uv.y += RG_N(id0.x) * 0.85;
    vec2 id = floor(uv * grid);
    vec2 st = fract(uv * grid);

    float mySize, mySpeed, mySlip;
    vec4 myDrop = RG_DropInCell(vec2(0.0), st, t, grid, id, mySize, mySpeed, mySlip);
    vec2 myPos = myDrop.xy;
    vec2 myVel = myDrop.zw;

    vec3 n2 = RG_N13(id.x * 91.3 + id.y * 57.7 + 1.23);
    vec2 neighbor1Pos = vec2(n2.x + sin(t * (0.42 + n2.y * 0.3) + n2.z * 6.28) * 0.08,
                            1.05 - fract(t * (0.38 + n2.z * 0.4) + n2.x) * 1.18) + vec2(-1.0, 0.0);
    vec2 delta1 = neighbor1Pos - myPos;
    float prox1 = smoothstep(0.38, 0.10, length(delta1 * vec2(1.0, 0.7)));
    float sizeN1 = n2.x < 0.55 ? 0.62 : (n2.x < 0.88 ? 1.0 : 1.55);

    vec3 n3 = RG_N13(id.x * 43.1 + id.y * 113.9 + 5.77);
    vec2 neighbor2Pos = vec2(n3.x + sin(t * (0.45 + n3.y * 0.35) + n3.z * 6.28) * 0.08,
                            1.05 - fract(t * (0.41 + n3.z * 0.38) + n3.x) * 1.18) + vec2(1.0, 0.0);
    vec2 delta2 = neighbor2Pos - myPos;
    float prox2 = smoothstep(0.38, 0.10, length(delta2 * vec2(1.0, 0.7)));
    float sizeN2 = n3.x < 0.55 ? 0.62 : (n3.x < 0.88 ? 1.0 : 1.55);

    float mergeBoost = prox1 * (sizeN1 + mySize) * 0.28 + prox2 * (sizeN2 + mySize) * 0.28;
    vec2 mergePull = normalize(delta1 + vec2(0.0001)) * prox1 * 0.03 + normalize(delta2 + vec2(0.0001)) * prox2 * 0.03;
    float effectiveSize = mySize + mergeBoost * 0.6;
    vec2 finalPos = myPos + mergePull * mergeBoost;

    vec2 drop_local_uv = (st - finalPos) / max(effectiveSize * 0.95, 0.4) + 0.5;
    float velMag = length(myVel);
    vec2 velDir = velMag > 0.0001 ? myVel / velMag : vec2(0.0, -1.0);
    float rotBlend = smoothstep(0.05, 0.35, velMag);
    float c = mix(1.0, -velDir.y, rotBlend);
    float s = mix(0.0, -velDir.x, rotBlend);
    vec2 q = drop_local_uv - 0.5;
    vec2 rotatedUV = vec2(q.x * c + q.y * s, q.x * -s + q.y * c) + 0.5;
    vec4 drop = RG_ComputeRealisticDrop(rotatedUV);
    float dropMask = drop.w * smoothstep(1.7, 0.55, length((st - finalPos) / max(effectiveSize, 0.4)));

    float trailMaxLen = 0.5 + effectiveSize * 0.25;
    float trailFront = trailMaxLen * mySlip;

    vec2 fromDrop = st - finalPos;
    vec2 trailDir = -velDir;
    float alongTrail = dot(fromDrop, trailDir);
    float xDist = abs(fromDrop.x * trailDir.y - fromDrop.y * trailDir.x);
    float inTrailRange = step(0.001, alongTrail) * step(alongTrail, trailFront);
    float relY = clamp(alongTrail / max(trailFront, 0.001), 0.0, 1.0);

    float trailWidth = (0.035 + effectiveSize * 0.045) * smoothstep(1.0, 0.0, relY);
    float core = (1.0 - smoothstep(0.0, trailWidth, xDist)) * inTrailRange;
    float film = (1.0 - smoothstep(trailWidth, trailWidth * 2.2, xDist)) * 0.2 * inTrailRange;

    float fadeOut = smoothstep(1.0, 0.6, relY);
    float trailOpacity = fadeOut * mySlip * (0.4 + effectiveSize * 0.4);

    float trail = (core * 0.8 + film) * trailOpacity;

    float headFilm = (1.0 - smoothstep(0.0, 0.10 + effectiveSize * 0.04, length(fromDrop + velDir * (0.05 + effectiveSize * 0.03)))) * 0.18 * effectiveSize * mySlip;

    return vec3(max(dropMask, headFilm * 0.5), trail, drop.z * dropMask + trail * 0.04);
}

vec3 RG_HorizontalDropShape(vec2 uv, vec2 dropPos, vec2 velDir, float sizeClass, float slip, float edgeFade, float dropScale) {
    vec2 diff = uv - dropPos;
    float menuScale = mix(0.70, 3.50, smoothstep(0.005, 1.75, dropScale));
    float radius = mix(0.006, 0.016, clamp((sizeClass - 0.62) / 0.83, 0.0, 1.0)) * menuScale;
    float dropDist = length(diff / max(radius, 0.001));
    vec2 localUV = diff / max(radius * 2.15, 0.001) + 0.5;

    velDir = length(velDir) > 0.001 ? normalize(velDir) : vec2(0.0, -1.0);
    float rc = -velDir.y;
    float rs = -velDir.x;
    vec2 q = localUV - 0.5;
    vec2 rotatedUV = vec2(q.x * rc + q.y * rs, q.x * -rs + q.y * rc) + 0.5;
    vec4 drop = RG_ComputeRealisticDrop(rotatedUV);
    float dropMask = drop.w * smoothstep(1.10, 0.48, dropDist) * edgeFade;

    vec2 trailDir = -velDir;
    float alongTrail = dot(diff, trailDir);
    float xDist = abs(diff.x * trailDir.y - diff.y * trailDir.x);
    float trailMaxLen = (0.010 + radius * 0.25) * slip;
    float inTrailRange = step(0.001, alongTrail) * step(alongTrail, trailMaxLen);
    float relY = clamp(alongTrail / max(trailMaxLen, 0.001), 0.0, 1.0);
    float trailWidth = (0.002 + radius * 0.08) * smoothstep(1.0, 0.0, relY);
    float core = (1.0 - smoothstep(0.0, trailWidth, xDist)) * inTrailRange;
    float film = (1.0 - smoothstep(trailWidth, trailWidth * 2.4, xDist)) * 0.025 * inTrailRange;
    float trail = (core * 0.05 + film) * smoothstep(1.0, 0.45, relY) * slip * edgeFade;

    return vec3(dropMask, trail, drop.z * dropMask + trail * 0.002);
}

vec3 RG_DropsHorizontalFace(vec2 faceUV, vec2 faceID, float t, float radialSign, float l0, float l1, float l2, float density, float dropScale) {
    vec3 result = vec3(0.0);
    vec2 center = vec2(0.5);
    float layerWeight = max(l1, l2);
    
    float densityCutoff = mix(0.70, 0.98, clamp(density, 0.0, 1.0));
    int iterations = (radialSign > 0.0) ? 112 : 72;

    for (int i = 0; i < iterations; i++) {
        float fi = float(i);
        vec3 n = RG_N13(dot(faceID, vec2(37.13, 91.71)) + fi * 19.19 + 4.7);
        vec3 m = RG_N13(dot(faceID, vec2(13.57, 61.33)) + fi * 31.41 + 8.2);
        if (RG_N(fi + dot(faceID, vec2(11.7, 29.3))) > densityCutoff) continue;

        float sizeClass = m.x < 0.56 ? 0.62 : (m.x < 0.88 ? 1.0 : 1.45);
        float speed = (0.48 + n.y * 0.52) * mix(0.85, 1.35, smoothstep(0.5, 1.6, sizeClass));
        float ti = fract(t * speed + n.z);
        float eased = ti * ti * (3.0 - 2.0 * ti);
        float slip = smoothstep(0.03, 0.30, ti);

        vec2 dropPos;
        vec2 velDir;
        float edgeFade;
        if (radialSign > 0.0) {
            vec2 start = mix(vec2(n.x, m.y), center + (vec2(n.x, m.y) - 0.5) * 0.40, 0.45);
            start = clamp(start, vec2(0.12), vec2(0.88));
            velDir = start - center;
            velDir = length(velDir) > 0.001 ? normalize(velDir) : normalize(vec2(n.x - 0.5, m.z - 0.5) + vec2(0.001, 0.0));
            float distToEdge = 1.0 - length(start - center) * 1.414;
            vec2 sideCurve = vec2(-velDir.y, velDir.x) * sin(ti * 6.28 + m.z * 6.28) * (0.015 + 0.02 * m.y) * smoothstep(0.05, 0.80, ti);
            dropPos = start + velDir * distToEdge * eased + sideCurve;
            edgeFade = RG_FaceInteriorMask(dropPos, -0.05) * smoothstep(1.0, 0.75, ti);
        } else {
            float side = floor(n.x * 4.0);
            float ec = 0.1 + 0.8 * m.y;
            vec2 ep = (side < 1.0) ? vec2(ec, -0.05) : ((side < 2.0) ? vec2(1.05, ec) : ((side < 3.0) ? vec2(ec, 1.05) : vec2(-0.05, ec)));
            vec2 target = center + (vec2(m.z, n.y) - 0.5) * 0.25;
            velDir = normalize(target - ep);
            dropPos = mix(ep, target, eased) + vec2(-velDir.y, velDir.x) * sin(ti * 6.28 + m.z * 6.28) * 0.015 * smoothstep(0.02, 0.75, ti);
            edgeFade = RG_FaceInteriorMask(dropPos, -0.07) * smoothstep(0.0, 0.15, ti) * smoothstep(1.0, 0.85, ti);
        }

        vec3 d = RG_HorizontalDropShape(faceUV, dropPos, velDir, sizeClass, slip, edgeFade, dropScale);
        result.x = max(result.x, d.x * layerWeight);
        result.y = max(result.y, d.y * layerWeight * 0.02);
        result.z += d.z * layerWeight;
    }

    result.x = smoothstep(0.12, 0.90, result.x);
    return result;
}

float RG_StaticDrops(vec2 uv, float t) {
    uv *= 40.0;
    vec2 id = floor(uv);
    uv = fract(uv) - 0.5;
    vec3 n = RG_N13(id.x * 107.45 + id.y * 3543.654);
    vec2 p = (n.xy - 0.5) * 0.7;
    float d = length(uv - p);
    float fade = RG_Saw(0.025, fract(t * 0.1 + n.z));
    float sizeVar = 0.25 + n.z * 0.15;
    return smoothstep(sizeVar + 0.10, 0.0, d) * fract(n.z * 10.0) * fade;
}

vec3 RG_Drops(vec2 uv, float t, float l0, float l1, float l2) {
    float s = RG_StaticDrops(uv, t) * l0;
    vec3 m1 = RG_DropLayer2(uv * 0.85, t) * l1;
    vec3 m2 = RG_DropLayer2(uv * 1.40 + 3.77, t * 1.12 + 0.5) * l2;
    vec3 m3 = RG_DropLayer2(uv * 1.90 + vec2(5.31, 2.14), t * 0.88 + 1.1) * l1 * 0.6;
    float c = smoothstep(0.22, 1.0, s + m1.x + m2.x + m3.x);
    float trail = max(max(m1.y, m2.y), m3.y);
    trail = max(trail, smoothstep(0.15, 0.95, s) * 0.12);
    return vec3(c, trail, m1.z + m2.z + m3.z * 0.6);
}

#endif

/* RENDERTARGETS:2,7,11,14 */


void main() {
	#if defined ENTITIES
		if (ENTITY_SHADOW_LIKE == 1) discard;
	#endif

bool isInternalFace = false;
if (gl_FragCoord.x * texelSize.x < 1.0  && gl_FragCoord.y * texelSize.y < 1.0 )	{
	
	vec3 FragCoord = gl_FragCoord.xyz;
	float mipmapBias = bias();

	float BN = blueNoise();

	#ifdef TAA
		vec2 tempOffset = offsets[framemod8];
		vec3 viewPos = toScreenSpace(FragCoord*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize, 0.0));
		vec3 vPosStable = toScreenSpace(FragCoord*vec3(texelSize/RENDER_SCALE,1.0)); // Jitter-free
	#else
		vec3 viewPos = toScreenSpace(FragCoord*vec3(texelSize/RENDER_SCALE,1.0));
		vec3 vPosStable = viewPos;
	#endif

	// Use mat4 multiplication to include the translation part (eye height, etc.)
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 feetPlayerPosStable = (gbufferModelViewInverse * vec4(vPosStable, 1.0)).xyz;
	vec3 worldPos = feetPlayerPos + cameraPosition;
	vec3 worldPosStable = feetPlayerPosStable + cameraPosition;
	vec3 normalMatWorld = viewToWorld(normalMat.xyz);

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// MATERIAL MASKS ////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
	
	float MATERIALS = normalMat.w;

	// 1.0 = water mask
	// 0.9 = entity mask
	// 0.8 = reflective entities
	// 0.7 = reflective blocks
	// 0.6 = nether portal
	// 0.4 = translucent particles
	// 0.3 = hand mask

	#ifdef HAND
		MATERIALS = 0.3;
	#endif

	// bool isHand = abs(MATERIALS - 0.1) < 0.01;
	bool isWater = MATERIALS > 0.99;
	bool isReflectiveEntity = abs(MATERIALS - 0.2) < 0.01;
	vec3 _glassCheckPos = feetPlayerPos - normalMatWorld * 0.1;
	bool isPanelGlass = false;
	#ifdef IS_LPV_ENABLED
	uint _panelCheck = imageLoad(imgVoxelMask, ivec3(floor(GetLpvPosition(_glassCheckPos)))).r;
	isPanelGlass = IsGlassVoxelId(_panelCheck);
	#endif
	bool isReflective = abs(MATERIALS - 0.1) < 0.01 || isWater || isReflectiveEntity;
	if(isPanelGlass) isReflective = true;
	bool isEntity = abs(MATERIALS - 0.4) < 0.01 || isReflectiveEntity;
	bool isNetherPortal =  abs(MATERIALS - 0.6) < 0.01;

////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////// ALBEDO /////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	vec2 lightmap = lmtexcoord.zw;
	

	
	#ifndef COLORWHEEL
		#ifdef IRIS_FEATURE_TEXTURE_FILTERING
		gl_FragData[0] = textureFilteringMode == 1 ? sampleRGSS(gtexture, lmtexcoord.xy, 1.0 / vec2(textureSize(gtexture, 0))) : sampleNearest(gtexture, lmtexcoord.xy, 1.0 / vec2(textureSize(gtexture, 0)));
		gl_FragData[0] *= color;
		#else
		gl_FragData[0] = texture(gtexture, lmtexcoord.xy, mipmapBias) * color;
		#endif


#ifdef IS_LPV_ENABLED
	if(normalMat.w < 0.99 && normalMat.w > 0.05) {
		vec3 lpvPos = GetLpvPosition(_glassCheckPos);
		ivec3 voxelPos = ivec3(floor(lpvPos));

uint _aPX = imageLoad(imgVoxelMask, voxelPos + ivec3( 1,0,0)).r;
uint _aNX = imageLoad(imgVoxelMask, voxelPos + ivec3(-1,0,0)).r;
uint _aPZ = imageLoad(imgVoxelMask, voxelPos + ivec3( 0,0, 1)).r;
uint _aNZ = imageLoad(imgVoxelMask, voxelPos + ivec3( 0,0,-1)).r;
uint _aPY = imageLoad(imgVoxelMask, voxelPos + ivec3( 0, 1,0)).r;
uint _aNY = imageLoad(imgVoxelMask, voxelPos + ivec3( 0,-1,0)).r;
bool adjPX = IsGlassVoxelId(_aPX);
bool adjNX = IsGlassVoxelId(_aNX);
bool adjPZ = IsGlassVoxelId(_aPZ);
bool adjNZ = IsGlassVoxelId(_aNZ);
bool adjPY = IsGlassVoxelId(_aPY);
bool adjNY = IsGlassVoxelId(_aNY);

		vec3 worldNormal = normalMatWorld;
		vec3 absNormal = abs(worldNormal);
		bool facingX = absNormal.x > 0.5;
		bool facingZ = absNormal.z > 0.5;
		bool facingY = absNormal.y > 0.5;

		if(facingX) isInternalFace = (worldNormal.x > 0.5) ? adjPX : adjNX;
		else if(facingZ) isInternalFace = (worldNormal.z > 0.5) ? adjPZ : adjNZ;
		else if(facingY) isInternalFace = (worldNormal.y > 0.5) ? adjPY : adjNY;



		vec3 blockFract = fract(worldPos);
		vec2 uv;
		if(facingY) uv = blockFract.xz;
		else if(facingX) uv = blockFract.zy;
		else uv = blockFract.xy;
		float frameWidth = 0.05;
		float borderMask = 0.0;

		if(facingY) {
			if(!adjPX) borderMask = max(borderMask, smoothstep(1.0 - frameWidth, 1.0, uv.x));
			if(!adjNX) borderMask = max(borderMask, 1.0 - smoothstep(0.0, frameWidth, uv.x));
			if(!adjPZ) borderMask = max(borderMask, smoothstep(1.0 - frameWidth, 1.0, uv.y));
			if(!adjNZ) borderMask = max(borderMask, 1.0 - smoothstep(0.0, frameWidth, uv.y));
		} else if(facingX) {
			if(!adjPZ) borderMask = max(borderMask, smoothstep(1.0 - frameWidth, 1.0, uv.x));
			if(!adjNZ) borderMask = max(borderMask, 1.0 - smoothstep(0.0, frameWidth, uv.x));
			if(!adjPY) borderMask = max(borderMask, smoothstep(1.0 - frameWidth, 1.0, uv.y));
			if(!adjNY) borderMask = max(borderMask, 1.0 - smoothstep(0.0, frameWidth, uv.y));
		} else if(facingZ) {
			if(!adjPX) borderMask = max(borderMask, smoothstep(1.0 - frameWidth, 1.0, uv.x));
			if(!adjNX) borderMask = max(borderMask, 1.0 - smoothstep(0.0, frameWidth, uv.x));
			if(!adjPY) borderMask = max(borderMask, smoothstep(1.0 - frameWidth, 1.0, uv.y));
			if(!adjNY) borderMask = max(borderMask, 1.0 - smoothstep(0.0, frameWidth, uv.y));
		}

		uint voxelID = imageLoad(imgVoxelMask, voxelPos).r;
		#ifdef CONNECTED_GLASS
		#ifndef END_SHADER
		if(IsGlassVoxelId(voxelID)) {
			if (voxelID == 301u || voxelID == 516u) {
				if (isInternalFace) discard;
				gl_FragData[0].a = mix(0.0, gl_FragData[0].a, borderMask);
				gl_FragData[0].rgb *= borderMask;
				if (borderMask < 0.01) gl_FragData[0].a = 0.0;
			} else if (IsColoredGlassVoxelId(voxelID) || voxelID == 318u) {
				float minAlpha = (voxelID == 318u) ? 0.32 : 0.15;
				gl_FragData[0].a = mix(minAlpha, gl_FragData[0].a, borderMask);
			}
		}
		#endif
		#endif
		#ifdef END_SHADER
		if(IsGlassVoxelId(voxelID)) {
			isPanelGlass = true;
			float stableGlassAlpha = (voxelID == 301u || voxelID == 516u) ? 0.18 : 0.34;
			if (voxelID == 318u) stableGlassAlpha = 0.42;
			gl_FragData[0].a = max(gl_FragData[0].a, stableGlassAlpha);
		}
		#endif
	}
#endif
	#else
		vec4 _color = texture(gtexture, lmtexcoord.xy, mipmapBias);
		float ao;
		vec4 overlayColor;

		clrwl_computeFragment(_color, _color, lightmap, ao, overlayColor);
		lightmap = clamp((lightmap - 1.0 / 32.0) * 32.0 / 30.0, 0.0, 1.0);

		gl_FragData[0] = _color;
	#endif

	#if defined IRIS_FEATURE_FADE_VARIABLE && VANILLA_CHUNK_FADING > 0 && !defined HAND && !defined ENTITIES && !defined BLOCKENTITIES
		gl_FragData[0].a *= sqrt(chunkFade);

		#ifdef TAA
			if(sqrt(chunkFade) < BN && isWater) discard;
		#else
			if(sqrt(chunkFade) < R2_dither() && isWater) discard;
		#endif
	#endif

	float UnchangedAlpha = gl_FragData[0].a;

	#ifdef WhiteWorld
		gl_FragData[0].rgb = vec3(1.0);
		gl_FragData[0].a = 1.0/255.0;
	#endif

	vec3 Albedo = toLinear(gl_FragData[0].rgb);



	vec3 shadowPlayerPos = feetPlayerPos + gbufferModelViewInverse[3].xyz;
	#if (defined DISTANT_HORIZONS && DH_CHUNK_FADING > 0) || defined RIPPLE_WATER
		float viewDist = length(shadowPlayerPos); 
	#endif

	#ifndef WhiteWorld
		#ifdef VANILLA_LIKE_WATER
			if (isWater) Albedo *= sqrt(luma(Albedo));
		#else
			if (isWater){
				Albedo = vec3(0.0);
				gl_FragData[0].a = 1.0/255.0;
			}
		#endif
	#endif

	#if defined DISTANT_HORIZONS && DH_CHUNK_FADING > 0 && !defined LIGHTNING
		float ditherFade = smoothstep(0.98 * far, 1.03 * far, viewDist);

		if (step(ditherFade, R2_dither()) == 0.0) discard;
	#endif

	#ifdef LIGHTNING
		if (LIGHTNING_BOLT > 0.0){
			Albedo = 2.5 * vec3(1.0,2.2,6.5);
		} else {
			Albedo *= color.a;
			gl_FragData[0].a = color.a;
		}
	#endif

	#if defined ENTITIES && !defined COLORWHEEL
		Albedo.rgb = mix(Albedo.rgb, entityColor.rgb, pow(entityColor.a, 0.8));
	#endif

	#ifdef COLORWHEEL
		Albedo.rgb = mix(Albedo.rgb, overlayColor.rgb, overlayColor.a);
	#endif

	vec4 GLASS_TINT_COLORS = vec4(Albedo, UnchangedAlpha);
	
	#ifdef BIOME_TINT_WATER
		if (isWater) GLASS_TINT_COLORS.rgb = toLinear(color.rgb);
	#endif

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// NORMALS ///////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	vec3 normal = normalMat.xyz; // in viewSpace
	vec3 geoNormals = viewToWorld(normal).xyz; // for refractions

	#if defined PHYSICSMOD_OCEAN_SHADER && defined PHYSICS_OCEAN
		WavePixelData wave = physics_wavePixel(physics_localPosition.xz, physics_localWaviness, physics_iterationsNormal, physics_gameTime);
		
		#if defined DISTANT_HORIZONS
			float PHYSICS_OCEAN_TRANSITION = 1.0-pow(1.0-pow(1.0-clamp(1.0-length(feetPlayerPos.xz)/max(far,0.0),0,1),5),5);
		#else
			float PHYSICS_OCEAN_TRANSITION = 0.0;
		#endif

		if (isWater){
			if (!gl_FrontFacing) {
   			    wave.normal = -wave.normal;
   			}

			normal = mix(normalize(gl_NormalMatrix * wave.normal), normal, PHYSICS_OCEAN_TRANSITION);
			Albedo = mix(Albedo, vec3(1.0), wave.foam);
			gl_FragData[0].a = mix(1.0/255.0, 1.0, wave.foam);
		}
	#endif

	vec3 worldSpaceNormal = viewToWorld(normal).xyz;
	
	#if defined LARGE_WAVE_DISPLACEMENT && !defined PHYSICS_OCEAN
		if (isWater){
			normal = largeWaveDisplacementNormal;
		}
	#endif

	vec3 tangent2 = normalize(cross(tangent.rgb, normal)*tangent.w);
	mat3 tbnMatrix = mat3(tangent.x, tangent2.x, normal.x,
						  tangent.y, tangent2.y, normal.y,
						  tangent.z, tangent2.z, normal.z);


	vec3 NormalTex = vec3(texture(normals, lmtexcoord.xy, mipmapBias).xy,0.0);
	NormalTex.xy = NormalTex.xy*2.0-1.0;
	NormalTex.z = clamp(sqrt(1.0 - dot(NormalTex.xy, NormalTex.xy)),0.0,1.0);

	vec3 rippleBump = vec3(0.0);

	#if !defined HAND && !defined VANILLA_LIKE_WATER
		if (isWater){
			vec3 playerPos = shadowPlayerPos;
			vec3 waterPos = playerPos;

			vec3 flowDir = normalize(worldSpaceNormal*10.0) * frameTimeCounter * 2.0 * WATER_WAVE_SPEED;
			
			vec2 newPos = worldPos.xy + abs(flowDir.xz);
			newPos = mix(newPos, worldPos.zy + abs(flowDir.zx), clamp(abs(worldSpaceNormal.x),0.0,1.0));
			newPos = mix(newPos, worldPos.xz, clamp(abs(worldSpaceNormal.y),0.0,1.0));
			waterPos.xy = newPos;
		
			waterPos.xyz = getParallaxDisplacement(waterPos, playerPos);

			vec3 bump = getWaveNormal(waterPos, playerPos);

			#ifdef RIPPLE_WATER
				if(viewDist < 35 && rainStrength > 0.0 && rippleAmount > 0.01 && abs(worldSpaceNormal.z) < 0.95 && abs(worldSpaceNormal.x) < 0.95) {
					float effectStrength = smoothstep(0.85, 1.0, lightmap.y) * smoothstep(0.0, 1.0, rippleAmount);
					rippleBump = ripples(worldPos.xz);
					bump += 0.6 * RIPPLE_STRENGTH * rippleBump * rainStrength * effectStrength * smoothstep(35.0, 10.0, viewDist);
				}
			#endif

			bump = normalize(bump);

			float bumpmult = WATER_WAVE_STRENGTH;
			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

			#if WATER_INTERACTION == 1
				// nice little wave effect when leaving water
				vec3 waterPlayerPostion = waterExitedPosition;
				float waterTime = waterExitedTime;
				vec3 playerVelocity = waterExitedVelocity;
				if (isEyeInWater == 1) {
					waterPlayerPostion = waterEnteredPosition;
				 	waterTime = waterEnteredTime;
					playerVelocity = waterEnteredVelocity;
				}

				float distFromWaterPos = length(worldPos - waterPlayerPostion);
				float maxWaveDist = 3.5;
				if (distFromWaterPos < maxWaveDist) {
					float newTime = frameTimeCounter - waterTime;
					newTime *= 2.15;

					float smoothDistFromWaterPos = smoothstep(maxWaveDist, 0.0, distFromWaterPos);
					float waveWidth = 0.2;
					float waveHeight = 0.3 * smoothstep(2.0, 20.0, length(playerVelocity)) + 0.5;

					float enterWave = waveHeight * smoothstep(newTime - waveWidth, newTime, distFromWaterPos-0.1) * smoothstep(newTime + waveWidth, newTime, distFromWaterPos-0.1) * smoothDistFromWaterPos;
			
					bump.y = enterWave + (1.0 - enterWave) * bump.y;
				}
			
			#elif WATER_INTERACTION == 2

				#ifdef PIXELATED_WAVES
					#if WATER_SIM_SCALE == 0
						const float NORMAL_SCALE = 20.0;
					#elif WATER_SIM_SCALE == 1
						const float NORMAL_SCALE = 40.0;
					#else
						const float NORMAL_SCALE = 80.0;
					#endif

					ivec2 normalSize = imageSize(waveSim2);
					vec2 centeredUV = (worldPos.xz - previousCameraPositionWave2.xz) * NORMAL_SCALE;
					centeredUV += normalSize * 0.5;

					if(centeredUV.x < normalSize.x && centeredUV.x > 0.0 && centeredUV.y < normalSize.y && centeredUV.y > 0.0 && abs(worldSpaceNormal.y) > 0.5 && !noSimOngoing) {
						vec4 waves = imageLoad(waveSim2, ivec2(centeredUV));
				#else
					#if WATER_SIM_DISTANCE == 1
						const float NORMAL_SCALE = 0.04;
					#elif WATER_SIM_DISTANCE == 2
						const float NORMAL_SCALE = 0.02;
					#elif WATER_SIM_DISTANCE == 3
						const float NORMAL_SCALE = 0.015;
					#else
						const float NORMAL_SCALE = 0.01;
					#endif

					vec2 waveUV = (worldPos.xz - previousCameraPositionWave2.xz) * NORMAL_SCALE;
					if(length(waveUV) < 0.5 && abs(worldSpaceNormal.y) > 0.5 && !noSimOngoing) {
						vec4 waves = texture(waveSim2Sampler, waveUV+0.5);
				#endif
						vec3 waveNormals = normalize(vec3(waves.z, waves.w, 1.0));
						bump = mix(bump, waveNormals, clamp(WATER_SIM_STRENGTH*sqrt(sqrt(abs(waves.x))), 0.0, 1.0));
						bump = normalize(bump);
					}
			#endif

			NormalTex.xyz = bump;
		}
	#endif

	// tangent space normals for refraction
	vec2 TangentNormal = NormalTex.xy;
	
	#if defined PHYSICSMOD_OCEAN_SHADER && defined PHYSICS_OCEAN
		rippleBump *= physics_localWaviness;
		float bumpmult = mix(isWater ? 1.0 : NORMAL_MAP_MULT, isWater ? PHYSICS_OCEAN_TRANSITION : NORMAL_MAP_MULT, smoothstep(0.0, 0.1, physics_localWaviness));

		normal = applyBump(tbnMatrix, NormalTex.xyz, bumpmult, rippleBump);
	#else
		normal = applyBump(tbnMatrix, NormalTex.xyz, isWater ? 1.0 : NORMAL_MAP_MULT, rippleBump);
	#endif

	worldSpaceNormal = viewToWorld(normal);
	
	#if defined PHYSICSMOD_OCEAN_SHADER && defined PHYSICS_OCEAN
		if (isWater) TangentNormal = mix(NormalTex.xy, normalize(wave.normal).xz, smoothstep(0.0, 0.1, physics_localWaviness));
	#endif

	gl_FragData[2].r = encodeVec2(TangentNormal*0.5+0.5);

	vec4 blockBreak = texelFetch(colortex11, ivec2(gl_FragCoord.xy), 0);

	if(blockBreak.a > 0.99) {
		gl_FragData[2].gba = blockBreak.gba;
	} else {
		#if defined ENTITIES && defined IS_IRIS
			float nameTagMask = 0.0;
			if(NAMETAG > 0) nameTagMask = 1.0;
		#else
			const float nameTagMask = 0.0;
		#endif

		gl_FragData[2].gba = vec3(encodeVec2(GLASS_TINT_COLORS.rg), encodeVec2(GLASS_TINT_COLORS.ba), nameTagMask);
	}

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// SPECULARS /////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	vec3 SpecularTex = texture(specular, lmtexcoord.xy, mipmapBias).rga;
	
////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// DIFFUSE LIGHTING //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	// lightmap.y = 1.0;
	
	#ifndef OVERWORLD_SHADER
		lightmap.y = 1.0;
	#endif
	
	#if defined Hand_Held_lights && !defined LPV_ENABLED
		#ifdef IS_IRIS
			vec3 playerCamPos = cameraPosition - relativeEyePosition;
		#else
			vec3 playerCamPos = cameraPosition;
		#endif
		
		if(heldItemId > 999 || heldItemId2 > 999){ 
			float pointLight = clamp(1.0-length((worldPos)-playerCamPos)/HANDHELD_LIGHT_RANGE,0.0,1.0);
			lightmap.x  = mix(lightmap.x , 0.9, pointLight*pointLight);
		}

	#endif

	vec3 Indirect_lighting = vec3(0.0);
	vec3 MinimumLightColor = vec3(1.0);

	vec3 Direct_lighting = vec3(0.0);

	#ifdef OVERWORLD_SHADER
		vec3 DirectLightColor = lightSourceColorSSBO/2400.0;
		vec3 AmbientLightColor = averageSkyCol_CloudsSSBO/900.0;

		#ifdef USE_CUSTOM_DIFFUSE_LIGHTING_COLORS
			DirectLightColor = luma(DirectLightColor) * vec3(DIRECTLIGHT_DIFFUSE_R,DIRECTLIGHT_DIFFUSE_G,DIRECTLIGHT_DIFFUSE_B);
			AmbientLightColor = luma(AmbientLightColor) * vec3(INDIRECTLIGHT_DIFFUSE_R,INDIRECTLIGHT_DIFFUSE_G,INDIRECTLIGHT_DIFFUSE_B);
		#endif
		
		if(!isWater && isEyeInWater == 1){
			float distanceFromWaterSurface = cameraPosition.y - waterEnteredAltitude;
			float waterdepth = max(-(feetPlayerPos.y + distanceFromWaterSurface),0.0);

			DirectLightColor *= exp(-vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B) * (waterdepth/abs(WsunVec.y)));
			DirectLightColor *= pow(waterCaustics(worldPos, WsunVec, -(feetPlayerPos.y + distanceFromWaterSurface))*WATER_CAUSTICS_BRIGHTNESS, WATER_CAUSTICS_POWER);
		}

		float NdotL = clamp((-15 + dot(normal, normalize(WsunVec*mat3(gbufferModelViewInverse)))*255.0) / 240.0  ,0.0,1.0);
		float Shadows = 1.0;

		float shadowMapFalloff = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / (shadowDistance+16),0.0)*5.0,1.0));
		float shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / shadowDistance,0.0)*5.0,1.0));

		float LM_shadowMapFallback = min(max(lightmap.y-0.8, 0.0) * 25,1.0);

		Shadows = ComputeShadowMap(DirectLightColor, shadowPlayerPos, shadowMapFalloff, BN, geoNormals);

		// Shadows = mix(LM_shadowMapFallback, Shadows, shadowMapFalloff2);
		Shadows *= mix(LM_shadowMapFallback,1.0,shadowMapFalloff2);

		Shadows *= GetCloudShadow(worldPos, WsunVec);


		Direct_lighting = DirectLightColor * NdotL * Shadows;

		vec3 indirectNormal = worldSpaceNormal / dot(abs(worldSpaceNormal),vec3(1.0));
		float SkylightDir = clamp(indirectNormal.y*0.7+0.3,0.0,1.0);

		float skylight = mix(0.2 + 2.3*(1.0-lightmap.y), 2.5, SkylightDir)/2.5;
		AmbientLightColor *= skylight;

		Indirect_lighting = doIndirectLighting(AmbientLightColor, MinimumLightColor, lightmap.y);
	#endif

	#ifdef NETHER_SHADER
		Indirect_lighting = volumetricsFromTex(worldSpaceNormal, colortex4, 0).rgb / 1200.0 / 1.5;
	#endif

	#ifdef END_SHADER

		#ifdef END_LIGHTNING
			float vortexBounds = clamp(vortexBoundRange - length(feetPlayerPos+cameraPosition), 0.0,1.0);
		#else
			float vortexBounds = 1.0;
		#endif

        vec3 lightPos = LightSourcePosition(worldPos, cameraPosition,vortexBounds);

		float lightningflash = texelFetch(colortex4,ivec2(1,1),0).x/150.0;
		vec3 lightColors = LightSourceColors(vortexBounds, lightningflash);
		
		float end_NdotL = clamp(dot(worldSpaceNormal, normalize(-lightPos))*0.5+0.5,0.0,1.0);
		end_NdotL *= end_NdotL;

		float fogShadow = GetEndFogShadow(worldPos, lightPos);
		float endPhase = endFogPhase(lightPos);

		Direct_lighting = lightColors * endPhase * end_NdotL * fogShadow;

		#ifdef END_ISLAND_LIGHT
			vec3 WsunVec = END_LIGHT_DIR;
			vec3 DirectLightColor = vec3(VORTEX_LIGHT_COL_R,VORTEX_LIGHT_COL_G,VORTEX_LIGHT_COL_B);

			float NdotL = clamp((-15 + dot(normal, normalize(WsunVec*mat3(gbufferModelViewInverse)))*255.0) / 240.0  ,0.0,1.0);
			float Shadows = 1.0;

			float shadowMapFalloff = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / (shadowDistance+16),0.0)*5.0,1.0));
			float shadowMapFalloff2 = smoothstep(0.0, 1.0, min(max(1.0 - length(feetPlayerPos) / shadowDistance,0.0)*5.0,1.0));

			float LM_shadowMapFallback = min(max(lightmap.y-0.8, 0.0) * 25,1.0);

			Shadows = ComputeShadowMap(DirectLightColor, shadowPlayerPos, shadowMapFalloff, BN, geoNormals);

			// Shadows = mix(LM_shadowMapFallback, Shadows, shadowMapFalloff2);
			Shadows *= mix(LM_shadowMapFallback,1.0,shadowMapFalloff2);

			Direct_lighting = DirectLightColor * end_NdotL * Shadows;
		#endif

		vec3 AmbientLightColor = vec3(AmbientLightEnd_R,AmbientLightEnd_G,AmbientLightEnd_B) ;
			
		vec3 endIndirectLightDir = normalize(-lightPos);
		float endIndirectFacing = clamp(dot(worldSpaceNormal, endIndirectLightDir) * 0.5 + 0.5, 0.0, 1.0);
		Indirect_lighting = AmbientLightColor * mix(0.34, 1.0, endIndirectFacing);
		Indirect_lighting *= 0.1;
		if ((blockID >= BLOCK_GLASS && blockID <= BLOCK_GLASS_YELLOW) || blockID == 516) {
			Direct_lighting *= 0.35;
			Indirect_lighting = max(Indirect_lighting, AmbientLightColor * 0.09 + vec3(0.025, 0.018, 0.045));
			gl_FragData[0].a = max(gl_FragData[0].a, 0.22);
		}
	#endif

	///////////////////////// BLOCKLIGHT LIGHTING OR LPV LIGHTING OR FLOODFILL COLORED LIGHTING
	vec3 flatWorldNormal = normalMatWorld;
	#ifdef IS_LPV_ENABLED
		vec3 normalOffset = vec3(0.0);

		if (any(greaterThan(abs(flatWorldNormal), vec3(1.0e-6))))
			normalOffset = 0.5*worldSpaceNormal;

		#if LPV_NORMAL_STRENGTH > 0
			if (any(greaterThan(abs(normal), vec3(1.0e-6)))) {
				vec3 texNormalOffset = -normalOffset + worldSpaceNormal;
				normalOffset = mix(normalOffset, texNormalOffset, (LPV_NORMAL_STRENGTH*0.01));
			}
		#endif

		vec3 lpvPos = GetLpvPosition(feetPlayerPos) + normalOffset;
	#else
		const vec3 lpvPos = vec3(0.0);
	#endif

	#ifdef LIGHTNING
		vec3 lightColor = vec3(1.0);
		gl_FragData[0].a = max(gl_FragData[0].a, 1.0/255.0);
	#else
		vec3 lightColor = vec3(TORCH_R,TORCH_G,TORCH_B);
	#endif

	#ifdef MAIN_SHADOW_PASS
		Indirect_lighting += doBlockLightLighting(lightColor, lightmap.x, feetPlayerPos, lpvPos, viewPos, false, BN, worldSpaceNormal, false);
	#else
		Indirect_lighting += doBlockLightLighting(lightColor, lightmap.x, feetPlayerPos, lpvPos);
	#endif
	
	vec4 flashLightSpecularData = vec4(0.0);
	#ifdef FLASHLIGHT
		#if defined FLASHLIGHT_SHADOWS && defined MAIN_SHADOW_PASS && !defined HAND && defined MAIN_SHADOW_PASS
			vec3 newViewPos = viewPos + vec3(-0.25, 0.2, 0.0);
			float flashlightshadows = SSRT_FlashLight_Shadows(viewPos, false, -newViewPos, BN, worldSpaceNormal, false);
		#else
			const float flashlightshadows = 1.0;
		#endif
		Indirect_lighting += flashlightshadows * calculateFlashlight(FragCoord.xy*texelSize/RENDER_SCALE, viewPos, vec3(0.0), worldSpaceNormal, flashLightSpecularData, false);
	#endif


vec3 FinalColor = (Indirect_lighting + Direct_lighting) * Albedo;

	///////////////////////////////////////////////////////
////////////////////////	EMANRUX		////////////////////////
	///////////////////////////////////////////////////////

bool hasFrost = false;
float frostAmount = 0.0;

#ifdef FROST_ON_GLASS
#ifdef IS_LPV_ENABLED
float frostWeather = max(rainStrength, snowAmount);
bool frostGlassSurface = isPanelGlass || ((blockID >= 301 && blockID <= 318) || blockID == 516);
if(isSnowBiome && frostWeather > 0.02 && frostGlassSurface)
{

    vec3 worldNormal = normalMatWorld;
    vec2 frostUV;
    if(abs(worldNormal.x) > 0.5)      frostUV = worldPosStable.zy;
    else if(abs(worldNormal.z) > 0.5) frostUV = worldPosStable.xy;
    else                               frostUV = worldPosStable.xz;
    frostUV *= 0.18;

    float frostWeatherFast = pow(frostWeather, 2.5);
    float growth = clamp(frostWeatherFast * 1.4, 0.0, 0.95);
    float frost = 0.0;
    if (!isInternalFace) {
        for(int i = 0; i < 12; i++)
        {
            float scale = 10.0 + float(i) * 6.0;
            vec2 uv = frostUV * scale;
            vec2 cell = floor(uv);
            vec2 local = fract(uv) - 0.5;
            float rand  = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
            float rand2 = fract(sin(dot(cell, vec2(269.5, 183.3))) * 23421.631);
            float angle = rand * 6.28318;
            vec2 dir = vec2(cos(angle), sin(angle));
            float branch    = dot(local, dir);
            float thickness = abs(dot(local, vec2(-dir.y, dir.x)));
            float trunk =
                smoothstep(0.03, 0.0, thickness) *
                smoothstep(-0.1, 0.4, branch);
            float side =
                sin(branch * 18.0 + rand * 20.0) *
                smoothstep(0.02, 0.0, thickness * 1.8);
            float crystal = trunk + side * 0.5;
            float subAngle = angle + rand2 * 2.0 - 1.0;
            vec2 subDir = vec2(cos(subAngle), sin(subAngle));
            float subBranch = dot(local, subDir);
            float subThick  = abs(dot(local, vec2(-subDir.y, subDir.x)));
            float subCrystal =
                smoothstep(0.02, 0.0, subThick) *
                smoothstep(0.0, 0.35, subBranch);
            crystal += subCrystal * 0.6;
            frost = max(frost, crystal * (1.0 - float(i) * 0.07));
        }
        frost *= growth;
        float baseFill = texture(noisetex, frostUV * 0.3).r * 0.35 * growth;
        frost = max(frost, baseFill);
    }
    if(frost > 0.02)
    {
        hasFrost = true;
        frostAmount = clamp(frost, 0.0, 1.0);

        vec3 frostColor = mix(vec3(0.34, 0.43, 0.55), vec3(0.72, 0.82, 0.92), frostAmount);
        vec3 final = frostColor * (Indirect_lighting + Direct_lighting + 0.02);
	FinalColor = mix(FinalColor, max(FinalColor * 0.88, final), frostAmount * 0.80);
	FinalColor += frostColor * frostAmount * 0.028;
	gl_FragData[0].a = max(gl_FragData[0].a, frostAmount * 0.68);
    }

}
#endif
#endif

vec3 RainLighting = vec3(0.0);
#ifdef RAIN_ON_GLASS
	bool isDryBiomeLocal = isAridBiome;
    vec2 rg_n = vec2(0.0);
    float rg_drop = 0.0, rg_trail = 0.0;

	#ifdef IS_LPV_ENABLED
	if (!isDryBiomeLocal)
	{
		ivec3 voxPlayer = ivec3(floor(GetLpvPosition(vec3(0.0))));
		for(int dy = 0; dy <= 70; dy += 5) {
			uint b = imageLoad(imgVoxelMask, voxPlayer + ivec3(0, -dy, 0)).r;
			if(b == 84u || b == 89u || b == 54u || b == 80u) { isDryBiomeLocal = true; break; }
		}
	}
	#endif

	if(rainStrength > 0.05 && !isSnowBiome && !isDryBiomeLocal){

		vec3 _worldNormal = normalMatWorld;
		vec3 _absNormal = abs(_worldNormal);
		
		#ifdef IS_LPV_ENABLED
		uint _glassID = imageLoad(imgVoxelMask, ivec3(floor(GetLpvPosition(feetPlayerPos - normalMatWorld * 0.1)))).r;
		if((_glassID >= 301u && _glassID <= 318u) || _glassID == 516u) {
			vec2 dropUV = worldPos.xz;
			if(_absNormal.x > 0.5) dropUV = worldPos.zy;
			else if(_absNormal.z > 0.5) dropUV = worldPos.xy;

			bool isHorizontal = _absNormal.y > 0.5;
			bool skipRain = false;
			if (isInternalFace) skipRain = true;
			ivec3 glassVoxelPos = ivec3(floor(GetLpvPosition(feetPlayerPos - normalMatWorld * 0.1)));
			if (!RG_IsGlassRainExposed(glassVoxelPos, _worldNormal)) skipRain = true;

			if (!skipRain) {

				float lightFactor = dot(Indirect_lighting + Direct_lighting, vec3(0.33)) + 0.05;
				vec3 dropTint = vec3(0.92, 0.93, 0.95);
				bool isColored = (_glassID >= 302u && _glassID <= 318u);
				if (isColored) {
					vec3 glassCol = GLASS_TINT_COLORS.rgb;
					float l = dot(glassCol, vec3(0.2126, 0.7152, 0.0722));
					dropTint = mix(vec3(l), glassCol * 1.5, 0.8);
					dropTint = normalize(dropTint + 0.1) * 1.5;
				}

			#if RAIN_ON_GLASS_MODE == 1

				vec2 scaledUV = dropUV * 8.0;
				vec2 cellID = floor(scaledUV);
				vec2 cellUV = fract(scaledUV);
				float rand  = fract(sin(dot(cellID, vec2(127.1, 311.7))) * 43758.5453);
				float rand2 = fract(sin(dot(cellID, vec2(269.5, 183.3))) * 12345.6789);
				float rand3 = fract(sin(dot(cellID, vec2(53.7, 251.3))) * 77777.7777);

				if(rand3 < RAIN_DENSITY) {
					float speed = RAIN_SPEED + rand * RAIN_SPEED_VARIANCE;
					float timeOffset = rand2 * 10.0;
					float dropPos = 1.0 - fract(frameTimeCounter * speed * 0.1 + timeOffset);

					vec2 diff;
					float tip;
					diff = cellUV - vec2(rand, dropPos);

					diff.y *= (1.0 - RAIN_TRAIL);
					tip = 0.0;

					float dist = length(diff);
					float drop = max(1.0 - smoothstep(0.0, RAIN_SIZE, dist), tip);
					drop *= rainStrength;

					RainLighting += drop * RAIN_LIGHT_BRIGHTNESS * lightFactor * dropTint * 1.5;
					FinalColor = mix(FinalColor, FinalColor * 0.55, drop * 0.55);
					gl_FragData[0].a = max(gl_FragData[0].a, drop * 0.82);
				}
#elif RAIN_ON_GLASS_MODE == 2
    float rg_density = clamp(RAIN_REALISTIC_DENSITY, 0.10, 1.0);
    float rg_size = clamp(RAIN_REALISTIC_DROP_SIZE * 0.42, 0.18, 1.15);
    float rg_trailSetting = clamp(RAIN_REALISTIC_TRAILS, 0.0, 1.0);

    float rg_static = smoothstep(0.60, 1.0, rg_density) * 0.08;
    float rg_layer1 = smoothstep(0.16, 0.70, rg_density);
    float rg_layer2 = smoothstep(0.00, 0.55, rg_density);

    float rg_t = frameTimeCounter * RAIN_REALISTIC_SPEED * 0.30;

    vec3 rg_c;
    vec2 rg_e = vec2(0.0012, 0.0);
    vec3 rg_dx, rg_dy;

    if (isHorizontal) {
        float radialSign = (_worldNormal.y > 0.5) ? 1.0 : -1.0;
        vec2 rg_faceUV = fract(dropUV);
        vec2 rg_faceID = floor(dropUV);
        rg_c = RG_DropsHorizontalFace(rg_faceUV, rg_faceID, rg_t, radialSign, rg_static, rg_layer1, rg_layer2, rg_density, RAIN_REALISTIC_DROP_SIZE);
        float h_val = (rg_c.x + rg_c.y * 0.15) * rainStrength;
        vec2 h_grad = vec2(dFdx(h_val), dFdy(h_val)) * 450.0;
        rg_dx = vec3(rg_c.x + h_grad.x, rg_c.y, rg_c.z);
        rg_dy = vec3(rg_c.x + h_grad.y, rg_c.y, rg_c.z);
    } else {
        vec2 rg_uv_base = dropUV * vec2(1.0, 0.78);
        vec2 rg_uv = rg_uv_base / rg_size * 0.55;
        rg_c  = RG_Drops(rg_uv,            rg_t, rg_static, rg_layer1, rg_layer2);
        rg_dx = RG_Drops(rg_uv + rg_e,     rg_t, 0.0, rg_layer1, rg_layer2);
        rg_dy = RG_Drops(rg_uv + rg_e.yx,  rg_t, 0.0, rg_layer1, rg_layer2);
    }

    float rg_surface = rg_c.x + rg_c.y * 0.42;
    rg_n = vec2(
        rg_dx.x + rg_dx.y * 0.42 - rg_surface,
        rg_dy.x + rg_dy.y * 0.42 - rg_surface
    ) * 2.05;


    rg_drop = rg_c.x * rainStrength;
    float rg_extras = rg_c.z * rainStrength;
    rg_trail = rg_c.y * rainStrength * rg_trailSetting;

    float rimGrad = length(rg_n);
    float rg_highlight = pow(clamp(rimGrad, 0.0, 1.0), 3.5) * RAIN_REALISTIC_HIGHLIGHTS * 0.90;
    float internalGlow = (smoothstep(0.15, 0.85, rg_drop) + rg_trail * 0.38) * 0.38 * RAIN_REALISTIC_HIGHLIGHTS;

    vec3 rg_tint = vec3(1.0);
    if (_glassID >= 302u && _glassID <= 318u) {
        vec3 glassTint = RG_GlassTintFromId(_glassID, GLASS_TINT_COLORS.rgb);
        float tintLuma = dot(glassTint, vec3(0.2126, 0.7152, 0.0722));
        rg_tint = mix(vec3(max(tintLuma, 0.08)), glassTint, 0.86);
    }

    float wetDarken = clamp(rg_trail * 0.16 + rg_drop * 0.06, 0.0, 0.24);
    FinalColor = mix(FinalColor, FinalColor * mix(vec3(0.90), rg_tint, 0.24), wetDarken);

    float rg_lightBoost = (_glassID == 301u) ? 0.18 : 0.08;
    RainLighting += (rg_highlight * 1.10 + internalGlow * 0.95 + rg_extras * 0.7) * rg_tint * (Indirect_lighting + Direct_lighting + rg_lightBoost);

    float rg_alphaMult = (_glassID == 301u) ? 0.16 : 0.28;
    float rg_trailMult = (_glassID == 301u) ? 0.09 : 0.16;
    gl_FragData[0].a = max(gl_FragData[0].a, max(rg_drop * rg_alphaMult, rg_trail * rg_trailMult));
#endif
			}
		}
		#endif
	}
#endif

	#if EMISSIVE_TYPE == 2 || EMISSIVE_TYPE == 3
		Emission(FinalColor, Albedo, SpecularTex.b);
	#endif

#ifdef CUSTOM_NETHER_PORTAL
if(isNetherPortal) {
    float t = frameTimeCounter;

    #ifdef IS_LPV_ENABLED
    ivec3 baseVoxel = ivec3(floor(GetLpvPosition(feetPlayerPos)));
    uint basePortalId = imageLoad(imgVoxelMask, baseVoxel).r;
    if(basePortalId != 337u) {
        ivec3 backVoxel = ivec3(floor(GetLpvPosition(feetPlayerPos - normalMatWorld * 0.45)));
        uint backPortalId = imageLoad(imgVoxelMask, backVoxel).r;
        if(backPortalId == 337u) {
            baseVoxel = backVoxel;
        } else {
            ivec3 frontVoxel = ivec3(floor(GetLpvPosition(feetPlayerPos + normalMatWorld * 0.45)));
            if(imageLoad(imgVoxelMask, frontVoxel).r == 337u) baseVoxel = frontVoxel;
        }
    }
    #else
    ivec3 baseVoxel = ivec3(0);
    #endif
    
    float _fwX = floor(worldPos.x);
    float _fwY = floor(worldPos.y);
    float _fwZ = floor(worldPos.z);

    float minX = _fwX + 0.5, maxX = _fwX + 0.5;
    float minY = _fwY + 0.5, maxY = _fwY + 0.5;
    float minZ = _fwZ + 0.5, maxZ = _fwZ + 0.5;

    bool facingZ = abs(normalMatWorld.z) > 0.5;
    bool facingX = abs(normalMatWorld.x) > 0.5;

    #ifdef IS_LPV_ENABLED
    if (facingZ) {
        for(int i=1; i<=21; i++) {
            if (imageLoad(imgVoxelMask, baseVoxel + ivec3(i, 0, 0)).r == 337u) maxX = _fwX + float(i) + 0.5;
            else break;
        }
        for(int i=1; i<=21; i++) {
            if (imageLoad(imgVoxelMask, baseVoxel - ivec3(i, 0, 0)).r == 337u) minX = _fwX - float(i) + 0.5;
            else break;
        }
        for(int i=1; i<=21; i++) {
            if (imageLoad(imgVoxelMask, baseVoxel + ivec3(0, i, 0)).r == 337u) maxY = _fwY + float(i) + 0.5;
            else break;
        }
        for(int i=1; i<=21; i++) {
            if (imageLoad(imgVoxelMask, baseVoxel - ivec3(0, i, 0)).r == 337u) minY = _fwY - float(i) + 0.5;
            else break;
        }
    } else if (facingX) {
        for(int i=1; i<=21; i++) {
            if (imageLoad(imgVoxelMask, baseVoxel + ivec3(0, 0, i)).r == 337u) maxZ = _fwZ + float(i) + 0.5;
            else break;
        }
        for(int i=1; i<=21; i++) {
            if (imageLoad(imgVoxelMask, baseVoxel - ivec3(0, 0, i)).r == 337u) minZ = _fwZ - float(i) + 0.5;
            else break;
        }
        for(int i=1; i<=21; i++) {
            if (imageLoad(imgVoxelMask, baseVoxel + ivec3(0, i, 0)).r == 337u) maxY = _fwY + float(i) + 0.5;
            else break;
        }
        for(int i=1; i<=21; i++) {
            if (imageLoad(imgVoxelMask, baseVoxel - ivec3(0, i, 0)).r == 337u) minY = _fwY - float(i) + 0.5;
            else break;
        }
    }
    #endif

    vec2 p;
    float spread;
    if (facingZ) {
        vec2 portalCenter = vec2((minX + maxX) * 0.5, (minY + maxY) * 0.5);
        p = worldPos.xy - portalCenter;
        spread = max(maxX - minX, maxY - minY) * 0.5 + 0.5;
    } else {
        vec2 portalCenter = vec2((minZ + maxZ) * 0.5, (minY + maxY) * 0.5);
        p = worldPos.zy - portalCenter;
        spread = max(maxZ - minZ, maxY - minY) * 0.5 + 0.5;
    }

    if(spread < 1.05) {
        vec2 portalPlane = facingZ ? worldPos.xy : worldPos.zy;
        const float fallbackSpan = 64.0;
        vec2 fallbackCenter = floor(portalPlane / fallbackSpan) * fallbackSpan + fallbackSpan * 0.5;
        p = portalPlane - fallbackCenter;
        spread = fallbackSpan * 0.52;
    }

    float portalQuality = 1.0 - smoothstep(120.0, 240.0, length(feetPlayerPos));
    float dist = length(p);
    float angle = atan(p.y, p.x);

    float twist = mix(4.5, 1.5, smoothstep(1.5, 4.0, spread));
    twist *= mix(0.72, 1.0, portalQuality);
    angle += (t * 0.6) + (dist * twist);
    vec2 polarP = vec2(cos(angle), sin(angle)) * dist;

    float noiseDensity = mix(4.0, 2.0, smoothstep(1.5, 4.0, spread));
    noiseDensity *= mix(0.58, 1.0, portalQuality);
    float noise = 0.5 + 0.5 * sin(polarP.x * noiseDensity + t) * cos(polarP.y * noiseDensity - t);
    noise += 0.25 * sin(dist * (noiseDensity * 2.0) - t * 1.5);
    noise = clamp(noise, 0.0, 1.0);

    vec3 colorFondo  = vec3(0.002, 0.0, 0.005);
    vec3 colorNebula = vec3(0.25, 0.0, 0.5);
    vec3 colorBrillo = vec3(0.4, 0.0, 0.7);

    float darkCenter = smoothstep(0.0, spread * 0.75, dist);

    vec3 finalPortal = mix(colorFondo, colorNebula, noise * darkCenter);
    finalPortal = mix(finalPortal, colorBrillo, (1.0 - noise) * 0.15 * darkCenter);
	gl_FragData[0].a = max(gl_FragData[0].a, 0.98);

    float stars = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
    stars = smoothstep(0.997, 1.0, stars);
    finalPortal += stars * mix(0.55, 1.5, portalQuality) * darkCenter;

    finalPortal *= 0.7;
    FinalColor = mix(FinalColor, finalPortal, 0.98);
}
#endif
////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// SPECULAR LIGHTING /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

	#ifdef LIGHTNING
		#undef FORWARD_SPECULAR
	#endif

	#if defined FORWARD_SPECULAR

		float harcodedF0 = 0.02;
		
		// if nothing is chosen, no smoothness and no reflectance
		vec2 specularValues = vec2(1.0, 0.0); 

		
		// hardcode specular values for select blocks like glass, water, and slime
		if(isReflective) specularValues = vec2(1.0, harcodedF0);

		// detect if the specular texture is used, if it is, overwrite hardcoded values
		if(SpecularTex.r > 0.0 && SpecularTex.g <= 1.0) specularValues = SpecularTex.rg;

		float f0 = isReflective ? max(specularValues.g, harcodedF0) : specularValues.g;
		if(isPanelGlass) f0 = 0.1;
		bool isHand = false;

		#ifdef HAND
			isHand = true;
			f0 = max(specularValues.g, harcodedF0);
		#endif
		
		float roughness = specularValues.r; 
		
		if(UnchangedAlpha <= 0.0 && !isReflective) f0 = 0.0;
		if(isPanelGlass) {
			f0 = 0.1;
			roughness = 0.0;
		}
		if (f0 > 0.0){
			if(isReflective) f0 = max(f0, harcodedF0);
			
			float reflectance = 0.0;

			#if !defined OVERWORLD_SHADER
				vec3 sunVec = vec3(0.0);
				vec3 DirectLightColor = sunVec;
				float Shadows = 0.0;
			#else
				vec3 sunVec = WsunVec;
			#endif
			
			vec3 specularReflections = specularReflections(viewPos, shadowPlayerPos, normalize(feetPlayerPos), sunVec, vec2(BN, interleaved_gradientNoise_temporal()), flatWorldNormal, worldSpaceNormal, roughness, f0, Albedo, FinalColor*gl_FragData[0].a, DirectLightColor * Shadows * Shadows, lightmap.y, isHand, isWater, reflectance, flashLightSpecularData);
			
			gl_FragData[0].a = gl_FragData[0].a + (1.0-gl_FragData[0].a) * reflectance;
		
			gl_FragData[0].rgb = clamp(specularReflections / max(gl_FragData[0].a, 0.045) * 0.1, 0.0, 65000.0);
			gl_FragData[0].rgb += RainLighting * 0.1;
			
		}else{
			gl_FragData[0].rgb = clamp(FinalColor / max(gl_FragData[0].a, 0.045) * 0.1, 0.0, 65000.0);
			gl_FragData[0].rgb += RainLighting * 0.1;
		}
	#else
		gl_FragData[0].rgb = (FinalColor / max(gl_FragData[0].a, 0.045) + RainLighting) * 0.1;
	#endif

	#if defined ENTITIES && !defined COLORWHEEL
		// do not allow specular to be very visible in these regions on entities
		// this helps with specular on slimes, and entities with skin overlays like piglins/players
    	if (!gl_FrontFacing) {
			gl_FragData[0] = vec4(FinalColor*0.1, UnchangedAlpha);
		}
	#endif
	
	#if defined DISTANT_HORIZONS && defined DH_OVERDRAW_PREVENTION && !defined HAND && !defined NETHER_SHADER
		#if OVERDRAW_MAX_DISTANCE == 0
			float maxOverdrawDistance = far;
		#else
			float maxOverdrawDistance = OVERDRAW_MAX_DISTANCE;
		#endif
	 
		bool WATER = texelFetch(colortex7, ivec2(gl_FragCoord.xy), 0).a > 0.0 && length(feetPlayerPos) > clamp(far-16.0*4.0, 16.0, maxOverdrawDistance) && texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).x >= 1.0;

		if(WATER && isWater) {
			gl_FragData[0].a = 0.0;
			MATERIALS = 0.0;
		}
	#endif

	gl_FragData[1] = vec4(Albedo, MATERIALS);




	#if DEBUG_VIEW == debug_DH_WATER_BLENDING
		if(gl_FragCoord.x*texelSize.x < 0.47) gl_FragData[0] = vec4(0.0);
	#endif
	#if DEBUG_VIEW == debug_NORMALS
		gl_FragData[0].rgb = worldSpaceNormal.xyz * 0.1;
		gl_FragData[0].a = 1.0;
	#endif
	#if DEBUG_VIEW == debug_INDIRECT
		gl_FragData[0].rgb = Indirect_lighting * 0.1;
	#endif
	#if DEBUG_VIEW == debug_DIRECT
		gl_FragData[0].rgb = Direct_lighting * 0.1;
	#endif

	float weatherMask = 1.0;
	if (MATERIALS > 0.05 && MATERIALS < 0.9) weatherMask = 0.0; // Mark translucents as 'non-solid' for rain occlusion
	#if defined RAIN_ON_GLASS && RAIN_ON_GLASS_MODE == 2
		if (rg_drop + rg_trail > 0.01) {
			gl_FragData[3] = vec4(clamp(rg_n * 0.5 + 0.5, 0.0, 1.0), rg_drop, rg_trail);
		} else {
			gl_FragData[3] = vec4(weatherMask, 1, encodeVec2(lightmap.x, lightmap.y), 1);
		}
	#else
		gl_FragData[3] = vec4(weatherMask, 1, encodeVec2(lightmap.x, lightmap.y), 1);
	#endif

	#if defined ENTITIES && defined IS_IRIS && !defined COLORWHEEL
		if(NAMETAG > 0) {
			#ifndef OVERWORLD_SHADER
				lightmap.y = 0.0;
			#endif
			vec3 nameTagLighting = Albedo.rgb * max(max(lightmap.y*lightmap.y*lightmap.y , lightmap.x*lightmap.x*lightmap.x), 0.025);
			gl_FragData[0] = vec4(nameTagLighting.rgb * 0.1, UnchangedAlpha * 0.75);
		}
	#endif
}
}
