#extension GL_ARB_shader_texture_lod : enable

#include "/lib/settings.glsl"
#include "/lib/blocks.glsl"
#include "/lib/entities.glsl"
#include "/lib/items.glsl"
#include "/lib/hsv.glsl"

#ifdef HAND
#undef POM
#endif

#ifndef USE_LUMINANCE_AS_HEIGHTMAP
#ifndef MC_NORMAL_MAP
#undef POM
#endif
#endif

#ifdef POM
#define MC_NORMAL_MAP
#endif

#ifndef COLORWHEEL
	in float VanillaAO;
#endif

const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

const float MAX_OCCLUSION_DISTANCE = MAX_DIST;
const float MIX_OCCLUSION_DISTANCE = MAX_DIST*0.9;
const int   MAX_OCCLUSION_POINTS   = MAX_ITERATIONS;

uniform vec2 texelSize;
uniform int framemod8;

// #ifdef POM
in vec4 texcoordam; // .st for add, .pq for mul
in vec4 texcoord;

vec2 dcdx = dFdx(texcoord.st*texcoordam.pq)*exp2(Texture_MipMap_Bias);
vec2 dcdy = dFdy(texcoord.st*texcoordam.pq)*exp2(Texture_MipMap_Bias);
// #endif

#include "/lib/res_params.glsl"
in vec4 lmtexcoord;

in vec4 color;

uniform float far;

in vec4 normalMat;

#ifdef MC_NORMAL_MAP
	uniform sampler2D normals;
	in vec4 tangent;
	in vec3 FlatNormals;
#endif

#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD
	in vec3 GrassNormals;
#endif

uniform sampler2D specular;
uniform sampler2D texture;
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
uniform float frameTimeCounter;
uniform int frameCounter;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float rainStrength;
uniform sampler2D noisetex;//depth
uniform sampler2D depthtex0;

#if defined VIVECRAFT
	uniform bool vivecraftIsVR;
	uniform vec3 vivecraftRelativeMainHandPos;
	uniform vec3 vivecraftRelativeOffHandPos;
	uniform mat4 vivecraftRelativeMainHandRot;
	uniform mat4 vivecraftRelativeOffHandRot;
#endif

uniform vec4 entityColor;

// in vec3 velocity;

flat in float blockID;

uniform int heldItemId;
uniform int heldItemId2;


uniform float noPuddleAreas;
uniform float nightVision;
uniform vec3 relativeEyePosition;

// float interleaved_gradientNoise(){
// 	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameTimeCounter*51.9521);
// }

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

#ifdef TAA
	#define blueNoise fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter)
#else
	#define blueNoise fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887)
#endif


mat3 inverseMatrix(mat3 m) {
  float a00 = m[0][0], a01 = m[0][1], a02 = m[0][2];
  float a10 = m[1][0], a11 = m[1][1], a12 = m[1][2];
  float a20 = m[2][0], a21 = m[2][1], a22 = m[2][2];

  float b01 = a22 * a11 - a12 * a21;
  float b11 = -a22 * a10 + a12 * a20;
  float b21 = a21 * a10 - a11 * a20;

  float det = a00 * b01 + a01 * b11 + a02 * b21;

  return mat3(b01, (-a22 * a01 + a02 * a21), (a12 * a01 - a02 * a11),
              b11, (a22 * a00 - a02 * a20), (-a12 * a00 + a02 * a10),
              b21, (-a21 * a00 + a01 * a20), (a11 * a00 - a01 * a10)) / det;
}

vec3 viewToWorld(vec3 viewPosition) {
    vec4 pos;
    pos.xyz = viewPosition;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
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

#ifdef MC_NORMAL_MAP
	vec3 applyBump(mat3 tbnMatrix, vec3 bump){
		float bumpmult = NORMAL_MAP_MULT;
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		return normalize(bump*tbnMatrix);
	}
#endif


#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
vec3 toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

#ifdef POM
	vec4 readNormal(in vec2 coord)
	{
		return texture2DGradARB(normals,fract(coord)*texcoordam.pq+texcoordam.st,dcdx,dcdy);
	}
	vec4 readTexture(in vec2 coord)
	{
		return texture2DGradARB(texture,fract(coord)*texcoordam.pq+texcoordam.st,dcdx,dcdy);
	}
#endif


float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}


vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}


const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);


uniform float near;


float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}


vec4 readNoise(in vec2 coord){
	// return texture2D(noisetex,coord*texcoordam.pq+texcoord.st);
		return texture2DGradARB(noisetex,coord*texcoordam.pq + texcoordam.st,dcdx,dcdy);
}
// float EndPortalEffect(
// 	inout vec4 ALBEDO,
// 	vec3 FragPos,
// 	vec3 WorldPos,
// 	mat3 tbnMatrix
// ){	
// 
// 	int maxdist = 25;
// 	int quality = 35;
// 
// 	vec3 viewVec = normalize(tbnMatrix*FragPos);
// 	if ( viewVec.z < 0.0 && length(FragPos) < maxdist) {
// 		float endportalGLow = 0.0;
// 		float Depth = 0.3;
// 		vec3 interval = (viewVec.xyz /-viewVec.z/quality*Depth) * (0.7 + (blueNoise-0.5)*0.1);
// 
// 		vec3 coord = vec3(WorldPos.xz , 1.0);
// 		coord += interval;
// 
// 		for (int loopCount = 0; (loopCount < quality) && (1.0 - Depth + Depth * ( 1.0-readNoise(coord.st).r - readNoise(-coord.st*3).b*0.2 ) ) < coord.p  && coord.p >= 0.0; ++loopCount) {
// 			coord = coord+interval ; 
// 			endportalGLow += (0.3/quality);
// 		}
// 
//   		ALBEDO.rgb = vec3(0.5,0.75,1.0) * sqrt(endportalGLow);
// 
// 		return clamp(pow(endportalGLow*3.5,3),0,1);
// 	}
// }

float bias(){
	// return (Texture_MipMap_Bias + (blueNoise-0.5)*0.5) - (1.0-RENDER_SCALE.x) * 2.0;
	return Texture_MipMap_Bias - (1.0-RENDER_SCALE.x) * 2.0;
}
vec4 texture2D_POMSwitch(
	sampler2D sampler, 
	vec2 lightmapCoord,
	vec4 dcdxdcdy, 
	bool ifPOM,
	float LOD
){
	#if defined POM && (defined WORLD && !defined ENTITIES && !defined HAND || defined COLORWHEEL)
	if(ifPOM){
		return texture2DGradARB(sampler, lightmapCoord, dcdxdcdy.xy, dcdxdcdy.zw);
	}else
	#endif
	{
		return texture2D(sampler, lightmapCoord, LOD);
	}
}

uniform vec3 eyePosition;

void convertHandDepth(inout float depth) {
    float ndcDepth = depth * 2.0 - 1.0;
    ndcDepth /= MC_HAND_DEPTH;
    depth = ndcDepth * 0.5 + 0.5;
}

float getEmission(vec3 Albedo) {
	vec3 hsv = RgbToHsv(Albedo);
    float emissive = smoothstep(0.05, 0.15, hsv.y) * pow(hsv.z, 3.5);
    return emissive * 0.5;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

#if defined HAND || defined ENTITIES || defined BLOCKENTITIES
	/* RENDERTARGETS:1,8,15,2 */
#else
	/* RENDERTARGETS:1,8,15 */
#endif

void main() {
		
	vec3 FragCoord = gl_FragCoord.xyz;

	#ifdef HAND
		convertHandDepth(FragCoord.z);
	#endif
	
	bool ifPOM = false;

	#ifdef POM
		ifPOM = true;
	#endif

	#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD
		bool ShaderGrass = blockID == -15.0;
		if(ShaderGrass) ifPOM = false;
	#else
		bool ShaderGrass = false;
	#endif

	bool SIGN = false;

	if(blockID == BLOCK_SIGN) SIGN = true;

	#ifdef ENTITIES
		// disallow POM to work on item frames.
		if(blockID == ENTITY_ITEM_FRAME) SIGN = true;
	#else
		if(blockID == BLOCK_SIGN) SIGN = true;
	#endif

	if(SIGN) ifPOM = false;

	vec3 normal = normalMat.xyz;

	#ifdef MC_NORMAL_MAP
		vec3 binormal = normalize(cross(tangent.rgb,normal)*tangent.w);
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);
	#endif

	vec2 tempOffset = offsets[framemod8];

	vec3 fragpos = toScreenSpace(FragCoord*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5, 0.0));
	vec3 playerpos = mat3(gbufferModelViewInverse) * fragpos  + gbufferModelViewInverse[3].xyz;
	vec3 worldpos = playerpos + cameraPosition;

	vec2 adjustedTexCoord = lmtexcoord.xy;

#if defined POM && (defined WORLD && !defined ENTITIES && !defined HAND || defined COLORWHEEL)
	// vec2 tempOffset=offsets[framemod8];
	
	#ifndef COLORWHEEL
		adjustedTexCoord = fract(texcoord.st)*texcoordam.pq+texcoordam.st;
	#endif

	// vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	vec3 viewVector = normalize(tbnMatrix*fragpos);
	float dist = length(playerpos);

	float falloff = min(max(1.0-dist/MAX_OCCLUSION_DISTANCE,0.0) * 2.0,1.0);

	falloff = pow(1.0-pow(1.0-falloff,1.0),2.0);

	// falloff =  1;

	float maxdist = MAX_OCCLUSION_DISTANCE;
	if(!ifPOM) maxdist = 0.0;

	gl_FragDepth = gl_FragCoord.z;
	#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD
	 if (falloff > 0.0 && !ShaderGrass)
	#else
	 if (falloff > 0.0)
	#endif
	{
		float depthmap = readNormal(texcoord.st).a;
		float used_POM_DEPTH = 1.0;
		float pomdepth = POM_DEPTH*falloff;

 		if ( viewVector.z < 0.0 && depthmap < 0.9999 && depthmap > 0.00001) {	
			float noise = blueNoise;
			#ifdef Adaptive_Step_length
				vec3 interval = (viewVector.xyz /-viewVector.z/MAX_OCCLUSION_POINTS * pomdepth) * clamp(1.0-pow(depthmap,2),0.1,1.0);
				used_POM_DEPTH = 1.0;
			#else
				vec3 interval = viewVector.xyz /-viewVector.z/MAX_OCCLUSION_POINTS*pomdepth;
			#endif
			vec3 coord = vec3(texcoord.st , 1.0);

			coord += interval * noise * used_POM_DEPTH;

			float sumVec = noise;
			for (int loopCount = 0; (loopCount < MAX_OCCLUSION_POINTS) && (1.0 - pomdepth + pomdepth * readNormal(coord.st).a  ) < coord.p  && coord.p >= 0.0; ++loopCount) {
				coord = coord + interval  * used_POM_DEPTH; 
				sumVec += used_POM_DEPTH; 
			}
	
			if (coord.t < mincoord) {
				if (readTexture(vec2(coord.s,mincoord)).a == 0.0) {
					coord.t = mincoord;
					discard;
				}
			}
			
			adjustedTexCoord = mix(fract(coord.st)*texcoordam.pq+texcoordam.st, adjustedTexCoord, max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));

			vec3 truePos = fragpos + sumVec*inverseMatrix(tbnMatrix)*interval;

			gl_FragDepth = toClipSpace3(truePos).z;
		}
	}
#endif
	if(!ifPOM) adjustedTexCoord = lmtexcoord.xy;
	

	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	ALBEDO		////////////////////////////////
	//////////////////////////////// 				//////////////////////////////// 

	float textureLOD = bias();

	vec2 lmcoord = lmtexcoord.zw;

	#ifndef COLORWHEEL
		vec4 Albedo = color;
		#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && defined WORLD
		if (!ShaderGrass)
		#endif
		{
		 Albedo *= texture2D_POMSwitch(texture, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM, textureLOD);
		}
	#else
		vec4 Albedo = texture2D_POMSwitch(texture, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM, textureLOD);
		vec4 overlayColor;
		float VanillaAO;

		clrwl_computeFragment(Albedo, Albedo, lmcoord, VanillaAO, overlayColor);
		lmcoord = clamp((lmcoord - 1.0 / 32.0) * 32.0 / 30.0, 0.0, 1.0);
		VanillaAO = 1.0 - clamp(VanillaAO, 0,1);
	#endif

	#if REPLACE_SHORT_GRASS < 2 && !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD
		// darken the top of grass blocks a bit
		if(blockID == 85 && viewToWorld(FlatNormals).y > abs(0.9) && !ShaderGrass) Albedo *= smoothstep(-30.0, 25.0, length(playerpos));
	#endif

	#if defined DISTANT_HORIZONS && DH_CHUNK_FADING > 0
			float viewDist = length(playerpos); 
			float ditherFade = smoothstep(0.98 * far, 1.03 * far, viewDist);

			if(step(ditherFade, R2_dither()) == 0.0) discard;
	#endif
	
	#if defined HAND
		if (Albedo.a < 0.1) discard;
	#endif

	float torchlightmap = lmcoord.x;

	#if defined Hand_Held_lights && !defined LPV_ENABLED
		#ifdef IS_IRIS
			vec3 playerCamPos = cameraPosition - relativeEyePosition;
		#else
			vec3 playerCamPos = cameraPosition;
		#endif

		#ifdef VIVECRAFT
        	if (vivecraftIsVR) { 
				playerCamPos = cameraPosition - vivecraftRelativeMainHandPos;
			}
		#endif

		// if(HELD_ITEM_BRIGHTNESS > 0.0) torchlightmap = max(torchlightmap, HELD_ITEM_BRIGHTNESS * clamp( pow(max(1.0-length(worldpos-playerCamPos)/HANDHELD_LIGHT_RANGE,0.0),1.5),0.0,1.0));
		if(heldItemId > 999 || heldItemId2 > 999){ 
			float pointLight = clamp(1.0-(length(worldpos-playerCamPos)-1.)/HANDHELD_LIGHT_RANGE,0.0,1.0);

			if (torchlightmap < 0.99) { 
				torchlightmap = mix(torchlightmap, 0.9, pointLight);
			}
		}

		#ifdef HAND
			torchlightmap *= 0.9;
		#endif
	#endif
	
	#if defined WORLD && !defined ENTITIES && !defined HAND && defined BLOCKENTITIES && !defined COLORWHEEL
		bool PORTAL = false;
		if(blockID == BLOCK_END_PORTAL || blockID == 187) PORTAL = true;

		float endPortalEmission = 0.0;
		if(PORTAL) {
			const float steps = 20;

			vec3 color = vec3(0.0);
			float absorbance = 1.0;

			vec3 worldSpaceNormal = viewToWorld(normal);

			vec3 viewVec = normalize(tbnMatrix*fragpos);
			vec3 correctedViewVec = viewVec;
			
			correctedViewVec.xy = mix(correctedViewVec.xy, vec2( viewVec.y,-viewVec.x), clamp( worldSpaceNormal.y,0,1));
			correctedViewVec.xy = mix(correctedViewVec.xy, vec2(-viewVec.y, viewVec.x), clamp(-worldSpaceNormal.x,0,1)); 
			correctedViewVec.xy = mix(correctedViewVec.xy, vec2(-viewVec.y, viewVec.x), clamp(-worldSpaceNormal.z,0,1));
			
			correctedViewVec.z = mix(correctedViewVec.z, -correctedViewVec.z, clamp(length(vec3(worldSpaceNormal.xz, clamp(-worldSpaceNormal.y,0,1))),0,1)); 
			
			vec2 correctedWorldPos = playerpos.xz + cameraPosition.xz;
			correctedWorldPos = mix(correctedWorldPos,	vec2(-playerpos.x,playerpos.z)	+	vec2(-cameraPosition.x,cameraPosition.z),	clamp(-worldSpaceNormal.y,0,1));
			correctedWorldPos = mix(correctedWorldPos,	vec2( playerpos.z,playerpos.y)	+	vec2( cameraPosition.z,cameraPosition.y),	clamp( worldSpaceNormal.x,0,1));
			correctedWorldPos = mix(correctedWorldPos,	vec2(-playerpos.z,playerpos.y)	+	vec2(-cameraPosition.z,cameraPosition.y),	clamp(-worldSpaceNormal.x,0,1));
			correctedWorldPos = mix(correctedWorldPos,	vec2( playerpos.x,playerpos.y)	+	vec2( cameraPosition.x,cameraPosition.y),	clamp(-worldSpaceNormal.z,0,1));
			correctedWorldPos = mix(correctedWorldPos,	vec2(-playerpos.x,playerpos.y)	+	vec2(-cameraPosition.x,cameraPosition.y),	clamp( worldSpaceNormal.z,0,1));


			vec2 rayDir = ((correctedViewVec.xy) / -correctedViewVec.z) / steps * 5.0 ;
		
			vec2 uv = correctedWorldPos + rayDir * blueNoise;
			uv += rayDir * 10.0;

			vec2 animation = vec2(frameTimeCounter, -frameTimeCounter)*0.01;
			
			for (int i = 0; i < int(steps); i++) {
				
				float verticalGradient = (i + blueNoise)/steps ;
				float verticalGradient2 = exp(-7*(1-verticalGradient*verticalGradient));
			
				float density = max(max(verticalGradient - texture2D(noisetex, uv/256.0 + animation.xy).b*0.5,0.0) - (1.0-texture2D(noisetex, uv/32.0 + animation.xx).r) * (0.4 + 0.1 * (texture2D(noisetex, uv/10.0 - animation.yy).b)),0.0);
			
				float volumeCoeff = exp(-density*(i+1));
				
				vec3 lighting =  vec3(0.5,0.75,1.0) * 0.1 * exp(-10*density) + vec3(0.8,0.3,1.0) * verticalGradient2 * 1.7;
				color += (lighting - lighting * volumeCoeff) * absorbance;;

				absorbance *= volumeCoeff;
				endPortalEmission += verticalGradient*verticalGradient ;
				uv += rayDir;
			}

			Albedo.rgb = clamp(color,0,1);
			endPortalEmission = clamp(endPortalEmission/steps * 1.0,0.0,254.0/255.0);
			
		}
	#endif
	
	#ifdef WhiteWorld
		Albedo.rgb = vec3(0.5);
	#endif

		
	#ifdef AEROCHROME_MODE
		float gray = dot(Albedo.rgb, vec3(0.2, 1.0, 0.07));
		if (
			blockID == BLOCK_AMETHYST_BUD_MEDIUM || blockID == BLOCK_AMETHYST_BUD_LARGE || blockID == BLOCK_AMETHYST_CLUSTER 
			|| blockID == BLOCK_SSS_STRONG || blockID == BLOCK_SSS_WEAK
			|| blockID == BLOCK_GLOW_LICHEN || blockID == BLOCK_SNOW_LAYERS
			|| blockID >= 10 && blockID < 80
		) {
			// IR Reflective (Pink-red)
			Albedo.rgb = mix(vec3(gray), aerochrome_color, 0.7);
		}
		else if(blockID == BLOCK_GRASS) {
		// Special handling for grass block
			float strength = 1.0 - color.b;
			Albedo.rgb = mix(Albedo.rgb, aerochrome_color, strength);
		}
		#ifdef AEROCHROME_WOOL_ENABLED
			else if (blockID == BLOCK_SSS_WEAK_2 || blockID == BLOCK_CARPET) {
			// Wool
				Albedo.rgb = mix(Albedo.rgb, aerochrome_color, 0.3);
			}
		#endif
		else if(blockID == BLOCK_WATER || (blockID >= 300 && blockID < 400))
		{
		// IR Absorbsive? Dark.
			Albedo.rgb = mix(Albedo.rgb, vec3(0.01, 0.08, 0.15), 0.5);
		}
	#endif

	#ifdef WORLD
		if (Albedo.a > 0.1) Albedo.a = normalMat.a;
		else Albedo.a = 0.0;
	#endif

	#ifdef HAND
		if (Albedo.a > 0.1){
			Albedo.a = 0.75;
			gl_FragData[3] = vec4(0.0);
		} else {
			Albedo.a = 1.0;
		}
	#endif
	#if defined PARTICLE_RENDERING_FIX && (defined ENTITIES || defined BLOCKENTITIES)
		gl_FragData[3] = vec4(0.0);
	#endif

	#ifdef COLORWHEEL
		Albedo.a = 0.4;
	#endif

	
	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	NORMAL		////////////////////////////////
	//////////////////////////////// 				//////////////////////////////// 

	#if defined WORLD && defined MC_NORMAL_MAP
		#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD
		if(!ShaderGrass)
		#endif
		{
			vec4 NormalTex = texture2D_POMSwitch(normals, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM,textureLOD).xyzw;
			
			#ifdef MATERIAL_AO
				Albedo.rgb *= NormalTex.b*0.5+0.5;
			#endif

			float Heightmap = 1.0 - NormalTex.w;

			NormalTex.xy = NormalTex.xy * 2.0-1.0;
			NormalTex.z = sqrt(max(1.0 - dot(NormalTex.xy, NormalTex.xy), 0.0));

			normal = applyBump(tbnMatrix, NormalTex.xyz);
		}
	#endif
	
	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	SPECULAR	////////////////////////////////
	//////////////////////////////// 				//////////////////////////////// 
	
	#ifdef WORLD

		#if SSS_TYPE == 1 || SSS_TYPE == 2
			float SSSAMOUNT = 0.0;

			if (ShaderGrass) SSSAMOUNT = 1.0;

			/////// ----- SSS ON BLOCKS ----- ///////
			// strong
			if (
				blockID == BLOCK_SSS_STRONG || blockID == BLOCK_SAPLING || blockID == BLOCK_AIR_WAVING
			) {
				SSSAMOUNT = 1.0;
			}

			// medium
			if (
				blockID == BLOCK_GROUND_WAVING || blockID == BLOCK_GROUND_WAVING_VERTICAL
				|| blockID == BLOCK_GRASS_SHORT || blockID == BLOCK_GRASS_TALL_UPPER || blockID == BLOCK_GRASS_TALL_LOWER
			) {
				SSSAMOUNT = 0.5;
			}
			if (
				blockID == BLOCK_SSS_WEAK || blockID == BLOCK_SSS_WEAK_2 ||
				blockID == BLOCK_GLOW_LICHEN || blockID == BLOCK_SNOW_LAYERS || blockID == BLOCK_CARPET ||
				blockID == BLOCK_AMETHYST_BUD_MEDIUM || blockID == BLOCK_AMETHYST_BUD_LARGE || blockID == BLOCK_AMETHYST_CLUSTER ||
				blockID == BLOCK_BAMBOO || blockID == BLOCK_SAPLING || blockID == BLOCK_VINE
			) {
				SSSAMOUNT = 0.5;
			}
			
			// low
			#ifdef MISC_BLOCK_SSS
				if(
					blockID == BLOCK_SSS_WEIRD || blockID == BLOCK_GRASS
				){
					SSSAMOUNT = 0.5;
				}
			#endif

			#ifdef ENTITIES
				#ifdef MOB_SSS
					/////// ----- SSS ON MOBS----- ///////
					// strong
					if(blockID == ENTITY_SSS_MEDIUM) SSSAMOUNT = 0.75;
			
					// medium
			
					// low
					if(blockID == ENTITY_SSS_WEAK || blockID == ENTITY_PLAYER) SSSAMOUNT = 0.4;
				#endif
			#endif

			#ifdef BLOCKENTITIES
				/////// ----- SSS ON BLOCK ENTITIES----- ///////
				// strong

				// medium
				if(blockID == BLOCK_SSS_WEAK_3) SSSAMOUNT = 0.4;

				// low

			#endif
		#endif

		#if EMISSIVE_TYPE == 1 || EMISSIVE_TYPE == 2
			/////// ----- EMISSIVE STUFF ----- ///////
			float EMISSIVE = 0.0;

			// if(vNameTags > 0) EMISSIVE = 0.9;

			// normal block lightsources
			if(blockID >= 100 && blockID < 300) EMISSIVE = 0.5;

			if(blockID == 266 || blockID == 497) EMISSIVE = 0.2; // sculk stuff

			if(blockID == 195) EMISSIVE = 2.3; // glow lichen

			if(blockID == 185) EMISSIVE = 1.5; // crying obsidian

			if(blockID == 105) EMISSIVE = 2.0; // brewing stand
			
			if(blockID == 236) EMISSIVE = 1.0; // respawn anchor

			if(blockID == 101) EMISSIVE = 0.7; // large amethyst bud

			if(blockID == 103) EMISSIVE = 1.0; // amethyst cluster

			if(blockID == 244) EMISSIVE = 1.5; // soul fire

			#ifdef EMISSIVE_ORES
				if(blockID == 502) EMISSIVE = EMISSIVE_ORES_STRENGTH;
			#endif
		#endif


		vec4 SpecularTex = vec4(0.0);
		#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD
		if (ShaderGrass) {
			SpecularTex = vec4(0.15, 0.025, 1.0, 0.0);
		} else
		#endif
		{
			SpecularTex = texture2D_POMSwitch(specular, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM,textureLOD);
		}

		// SpecularTex.r = max(SpecularTex.r, rainfall);
		// SpecularTex.g = max(SpecularTex.g, max(Puddle_shape*0.02,0.02));

		gl_FragData[1].rg = SpecularTex.rg;

		#if EMISSIVE_TYPE == 0
			gl_FragData[1].a = 0.0;
		#endif

		#if EMISSIVE_TYPE == 1
			gl_FragData[1].a = getEmission(Albedo.rgb) * EMISSIVE;
		#endif

		#if EMISSIVE_TYPE == 2
			gl_FragData[1].a = SpecularTex.a;
			if(SpecularTex.a <= 0.0) gl_FragData[1].a = getEmission(Albedo.rgb) * EMISSIVE;
		#endif

		#if EMISSIVE_TYPE == 3		
			gl_FragData[1].a = SpecularTex.a;
		#endif
		
		#if defined WORLD && !defined ENTITIES && !defined HAND && defined BLOCKENTITIES && !defined COLORWHEEL
			if(PORTAL) gl_FragData[1].a = endPortalEmission;
		#endif

		#if SSS_TYPE == 0
			gl_FragData[1].b = 0.0;
		#endif

		#if SSS_TYPE == 1
			gl_FragData[1].b = SSSAMOUNT;
		#endif

		#if SSS_TYPE == 2
			gl_FragData[1].b = SpecularTex.b;
			if(SpecularTex.b < 65.0/255.0) gl_FragData[1].b = SSSAMOUNT;
		#endif

		#if SSS_TYPE == 3		
			gl_FragData[1].b = SpecularTex.b;
		#endif
	#endif

	// hit glow effect...
	#if defined ENTITIES && !defined COLORWHEEL
		Albedo.rgb = mix(Albedo.rgb, entityColor.rgb, clamp(entityColor.a*1.5,0,1));
	#endif

	#ifdef COLORWHEEL
		Albedo.rgb = mix(Albedo.rgb, overlayColor.rgb, clamp(overlayColor.a*1.5,0,1));
	#endif

	//////////////////////////////// 				////////////////////////////////
	////////////////////////////////	FINALIZE	////////////////////////////////
	//////////////////////////////// 				////////////////////////////////

	#ifdef WORLD
		// apply noise to lightmaps to reduce banding.
		vec2 PackLightmaps = vec2(torchlightmap, lmcoord.y);

		normal = viewToWorld(normal);

		vec3 flatNormals = viewToWorld(FlatNormals);

		#if !defined BLOCKENTITIES && !defined ENTITIES && !defined HAND && defined SHADER_GRASS && !defined COLORWHEEL && defined WORLD
			if (ShaderGrass) {flatNormals = FlatNormals; normal = GrassNormals;}
		#endif

		vec4 data1 = clamp( encode(normal, PackLightmaps), 0.0, 1.0);

		gl_FragData[0] = vec4(encodeVec2(Albedo.x,data1.x),	encodeVec2(Albedo.y,data1.y),	encodeVec2(Albedo.z,data1.z),	encodeVec2(data1.w,Albedo.w));

		gl_FragData[2] = vec4(flatNormals * 0.5 + 0.5, VanillaAO);	
	#endif
	
}