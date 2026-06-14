// Hash without Sine
// MIT License...
/* Copyright (c)2014 David Hoskins.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.*/
//----------------------------------------------------------------------------------------
		vec3 hash31(float p)
		{
		   vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
		   p3 += dot(p3, p3.yzx+33.33);
		   return fract((p3.xxy+p3.yzz)*p3.zyx); 
		}

		float hash11(float p)
		{
		    p = fract(p * .1031);
		    p *= p + 33.33;
		    p *= p + p;
		    return fract(p);
		}
	
//----------------------------------------------------------------------------------------

// Integer Hash - II
// - Inigo Quilez, Integer Hash - II, 2017
//   https://www.shadertoy.com/view/XlXcW4
//----------------------------------------------------------------------------------------

		uvec3 iqint2(uvec3 x)
		{
		    const uint k = 1103515245u;

		    x = ((x>>8U)^x.yzx)*k;
		    x = ((x>>8U)^x.yzx)*k;
		    x = ((x>>8U)^x.yzx)*k;

		    return x;
		}

		uvec3 hash(vec2 s)
		{	
		    uvec4 u = uvec4(s, uint(s.x) ^ uint(s.y), uint(s.x) + uint(s.y)); // Play with different values for 3rd and 4th params. Some hashes are okay with constants, most aren't.

		    return iqint2(u.xyz);
		}

//----------------------------------------------------------------------------------------

// vec3 RandomPosition = hash31(frameTimeCounter);
float vortexBoundRange = 300.0;
vec3 ManualLightPos = vec3(ORB_X, ORB_Y, ORB_Z);

float EndFogAmount(){
	return clamp(float(END_FOG_LEVEL) * 0.01, 0.0, 1.0);
}

vec3 LightSourcePosition(vec3 worldPos, vec3 cameraPos, float vortexBounds){

	vec3 vortexPos = -END_LIGHT_DIR * 200.0;

    vec3 lightningPos = worldPos - cameraPos - ManualLightPos;
    
	// snap-to coordinates in worldspace.
	float cellSize = 200.0;
    lightningPos += fract(cameraPos/cellSize)*cellSize - cellSize*0.5;

	// make the position offset to random places (RNG.xyz from non-clearing buffer).
	vec3 randomOffset = (texelFetch(colortex4,ivec2(2,1),0).xyz / 150.0) * 2.0 - 1.0;
	lightningPos -= randomOffset * 2.5;
	
	#ifdef THE_ORB
		cellSize = 200.0;
    	vec3 orbpos = worldPos - cameraPos - ManualLightPos;// - vec3(sin(frameTimeCounter), cos(frameTimeCounter), cos(frameTimeCounter))*100;
    	orbpos += fract(cameraPos/cellSize)*cellSize - cellSize*0.5;

		return orbpos;
	#else
		return mix(lightningPos, vortexPos, vortexBounds);
	#endif
}

float densityAtPosFog(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;

	vec3 p = floor(pos);
	vec3 f = fract(pos);

	f = (f*f) * (3.-2.*f);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	vec2 xy = texture(noisetex, coord).yx;
	return mix(xy.r,xy.g, f.y);
}

// Create a rising swirl centered around some origin.
void SwirlAroundOrigin(inout vec3 alteredOrigin, vec3 origin){

	float radiance = 2.39996 + alteredOrigin.y/1.5 + frameTimeCounter/50;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

    // make the swirl only happen within a radius
    float SwirlBounds = clamp(sqrt(length(vec3(origin.x, origin.y-100,origin.z)) / 200.0 - 1.0)  ,0.0,1.0);
    
    alteredOrigin.xz = mix(alteredOrigin.xz * rotationMatrix, alteredOrigin.xz, SwirlBounds);
}

// control where the fog volume should and should not be using a sphere.
void VolumeBounds(inout float Volume, vec3 Origin){

    vec3 Origin2 = (Origin - vec3(0,100,0));
	Origin2.y *= 0.8;
    float Center1 = length(Origin2);

    float mainIslandClear = 1.0 - smoothstep(70.0, 190.0, length(Origin.xz));
    mainIslandClear *= 1.0 - smoothstep(125.0, 230.0, abs(Origin.y));
    float Bounds = max(1.0 - Center1 / 95.0, 0.0) * 5.0 + mainIslandClear * 1.15;


    float radius = 150.0;
    float thickness = 25.0 * radius;
    float Torus =  (thickness - clamp( pow( length( vec2(length(Origin.xz) - radius, Origin2.y) ),2.0) - radius, 0.0, thickness) ) / thickness;
	
	// Origin2.xz *= 0.5;
	// Origin2.y -= 100;

	// float orb = clamp((1.0 - length(Origin2) / 15.0) * 1.0,0.0,1.0);
    Volume = max(Volume - Bounds - Torus, 0);
	
}

float EndIslandNebulaSpiral(vec3 pos, vec3 samplePos){
	float r = length(pos.xz);
	float heightMask = exp(-pow((pos.y - 72.0) / 92.0, 2.0));
	float ringMask = exp(-pow((r - 205.0) / 72.0, 2.0));
	float angle = atan(pos.z, pos.x);
	float spiralNoise = densityAtPosFog(samplePos * 5.4 + vec3(17.0, 4.0, 9.0));
	float arm = 0.5 + 0.5 * sin(angle * 3.0 - r * 0.034 + pos.y * 0.018 + frameTimeCounter * 0.055 + spiralNoise * 4.2);
	float armMask = smoothstep(0.42, 0.96, arm);
	float softBody = 0.30 + 0.70 * densityAtPosFog(samplePos * 8.5 - vec3(frameTimeCounter * 0.012));
	return ringMask * heightMask * (0.010 + 0.038 * armMask) * softBody;
}

// create the volume shape
float fogShape(in vec3 pos){

	#ifndef TOGGLE_VL_FOG
		return 0.0;
	#endif

	float endFog = EndFogAmount();
	if (endFog <= 0.0) return 0.0;

	float vortexBounds = clamp(vortexBoundRange - length(pos), 0.0,1.0);
	vec3 samplePos = pos*vec3(1.0,1.0/48.0,1.0);
	// float fogYstart = -60;

	// this is below down where you fall to your death.
	float voidZone = max(exp2(-1.0 * sqrt(max(pos.y - -60,0.0))) ,0.0) ;
	float mainIslandCalm = 1.0 - smoothstep(105.0, 245.0, length(pos.xz));
	mainIslandCalm *= 1.0 - smoothstep(140.0, 270.0, abs(pos.y));

	// swirly swirly :DDDDDDDDDDD
    SwirlAroundOrigin(samplePos, pos);
	
	float noise = densityAtPosFog(samplePos * 12.0);
    float erosion = 1.0-densityAtPosFog((samplePos - frameTimeCounter/18) * (124 + (1-noise)*7));
    

	float clumpyFog = max(exp(noise * -mix(10,4,vortexBounds))*mix(2,1,vortexBounds) - erosion*0.32, 0.0) * 0.02;
	clumpyFog *= mix(1.0, 0.72, mainIslandCalm);
    
	// apply limts
    VolumeBounds(clumpyFog, pos);

	float islandSpiral = EndIslandNebulaSpiral(pos, samplePos);

	return (clumpyFog + islandSpiral + voidZone * mix(0.06, 0.038, mainIslandCalm)) * endFog;
}

float EndOuterIslandFogMultiplier(vec3 pos){
	float outerIslands = smoothstep(720.0, 1050.0, length(pos.xz));
	float mainIsland = 1.0 - smoothstep(180.0, 360.0, length(pos.xz));
	return mix(mix(0.32, 0.42, 1.0 - mainIsland), 0.24, outerIslands);
}

float endFogPhase(vec3 LightPos){

    // float mie = exp(length(LightPos) / -150);
    // mie *= mie;
    // mie *= mie;
    // mie *= 100;

    // float mie = 1.0 - clamp(1.0 - length(LightPos) / 100.0,0.0,1.0);
    float mie = exp(length(LightPos) / -50.0);

    return (mie*10.0)*(mie*10.0);
}

vec3 LightSourceColors(float vortexBounds, float lightningflash){

    // vec3 vortexColor = vec3(0.7,0.88,1.0); 
    // vec3 lightningColor = vec3(ORB_R,ORB_G,ORB_B);

    //vec3 vortexColor = vec3(0.3,0.2,1.0);
	vec3 vortexColor = vec3(VORTEX_LIGHT_COL_R,VORTEX_LIGHT_COL_G,VORTEX_LIGHT_COL_B);
    vec3 lightningColor = vec3(END_LIGHTNING_COL_R,END_LIGHTNING_COL_G,END_LIGHTNING_COL_B) * lightningflash;

	#ifdef THE_ORB
		return vec3(ORB_R, ORB_G, ORB_B) * ORB_ColMult;
	#else
		return mix(lightningColor, vortexColor, vortexBounds);
	#endif
}

vec3 LightSourceLighting(vec3 startPos, vec3 lightPos, float noise, float density, vec3 lightColor, float vortexBound){

    float phase = endFogPhase(lightPos);
	float shadow = 0.0;

	for (int j = 0; j < 3; j++){
		vec3 shadowSamplePos = startPos - lightPos * (0.05 + j * (0.25 + 0*0.15));
		shadow += fogShape(shadowSamplePos);
	}


    vec3 finalLighting = lightColor * phase * exp(-7.0 * shadow) ;
	finalLighting += lightColor * phase*phase * (1.0 - exp( -shadow * vec3(0.6,2.0,2))) * (1.0 - exp(-density*density));

	return finalLighting;
}
//Mie phase function
float phaseEND(float x, float g){
    float gg = g * g;
    return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) / 3.14;
}
vec4 GetVolumetricFog(
	vec3 viewPosition,
	float dither,
	float dither2
){
	#ifndef TOGGLE_VL_FOG
		return vec4(0.0,0.0,0.0,1.0);
	#endif
	if (EndFogAmount() <= 0.0) return vec4(0.0,0.0,0.0,1.0);


	/// -------------  RAYMARCHING STUFF ------------- \\\

	vec3 wpos = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	float verticalFactor = abs(normalize(dVWorld).y);
	verticalFactor = pow(verticalFactor, 2.0);

	float rayLength = length(dVWorld);

	#if VL_SAMPLES <= 4
		const int END_VL_SAMPLE_COUNT = 5;
	#elif VL_SAMPLES <= 6
		const int END_VL_SAMPLE_COUNT = 7;
	#elif VL_SAMPLES <= 8
		const int END_VL_SAMPLE_COUNT = 9;
	#elif VL_SAMPLES <= 10
		const int END_VL_SAMPLE_COUNT = 11;
	#else
		const int END_VL_SAMPLE_COUNT = 13;
	#endif

	#if defined DISTANT_HORIZONS || defined VOXY
		int SAMPLECOUNT = END_VL_SAMPLE_COUNT + 2;
		float expFactor = 33.0;
		float maxDist = mix(800.0, 300.0, verticalFactor);
	#else
		int SAMPLECOUNT = END_VL_SAMPLE_COUNT;
		float expFactor = 11.0;
		float maxDist = mix(380.0, 300.0, verticalFactor);
	#endif

	vec3 progressW = vec3(0.0);

	float maxLength = min(rayLength, maxDist)/rayLength;
	
	dVWorld *= maxLength;

	float dL = length(dVWorld);
	
	
	/// -------------  COLOR/LIGHTING STUFF ------------- \\\

	vec3 color = vec3(0.0);
	float absorbance = 1.0;

	float CenterdotV = dot(normalize(vec3(0,100,0)-cameraPosition), normalize(wpos + cameraPosition));

	// float phsething = phaseEND(CenterdotV, 0.35) + phaseEND(CenterdotV, 0.85) ;

	float skyPhase = (0.5 + pow(clamp(normalize(wpos).y*0.5+0.5,0.0,1.0),4.0)*5.0) * 0.1;

	// vec3 hazeColor = normalize(gl_Fog.color.rgb + 1e-6) * 0.1;
    
	float lightningflash = texelFetch(colortex4,ivec2(1,1),0).x/150.0;
	
	for (int i = 0; i < SAMPLECOUNT; i++) {
		float d = (pow(expFactor, float(i+dither)/float(SAMPLECOUNT))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither2)/float(SAMPLECOUNT)) * log(expFactor) / float(SAMPLECOUNT)/(expFactor-1.0);

		vec3 progressP = gbufferModelViewInverse[3].xyz + d*dVWorld;
		vec3 progressW = progressP + cameraPosition;
		

		//------ END STORM EFFECT

			// determine where the vortex area ends and chaotic lightning area begins.
			#ifdef END_LIGHTNING
				float vortexBounds = clamp(vortexBoundRange - length(progressW), 0.0,1.0);
			#else
				float vortexBounds = 1.0;
			#endif

        	vec3 lightPosition = LightSourcePosition(progressW, cameraPosition, vortexBounds);
			vec3 lightColors = LightSourceColors(vortexBounds, lightningflash) * 0.25;

			float endFog = EndFogAmount();
			float outerFogMultiplier = EndOuterIslandFogMultiplier(progressW);
			float volumeDensity = fogShape(progressW) * outerFogMultiplier;
			
			float clearArea =  1.0-min(max(1.0 - length(progressP) / 100,0.0),1.0);
			float stormDensity = min(volumeDensity, clearArea*clearArea * END_STORM_DENSTIY * endFog);
			
			#ifdef THE_ORB
				stormDensity += min(50.0*max(1.0 - length(lightPosition)/10,0.0),1.0);
			#endif
			
			float volumeCoeff = exp(-stormDensity*dd*dL);

			vec3 lightsources = LightSourceLighting(progressW, lightPosition, dither, volumeDensity, lightColors, vortexBounds);
			vec3 indirect = vec3(AmbientLightEnd_R,AmbientLightEnd_G,AmbientLightEnd_B) * 0.2 * (exp((volumeDensity*volumeDensity) * -50) * 0.9 + 0.1) * 0.1;
			
			vec3 stormLighting = indirect + lightsources;
			
			color += (stormLighting - stormLighting*volumeCoeff) * absorbance;
        	absorbance *= volumeCoeff;

		//------ HAZE EFFECT
			// dont make haze contrube to absorbance.
			float hazeDensity = 0.001 * END_HAZE_DENSTIY * endFog * outerFogMultiplier;
			vec3 hazeLighting = vec3(0.37,0.32,0.75) * skyPhase * 0.5;
			color += (hazeLighting - hazeLighting*exp(-hazeDensity*dd*dL)) * absorbance;
	}
	return vec4(color, absorbance);
}

float GetEndFogShadow(vec3 WorldPos, vec3 LightPos){
	#ifndef TOGGLE_VL_FOG
		return 1.0;
	#endif
	if (EndFogAmount() <= 0.0 || END_STORM_DENSTIY <= 0.0) return 1.0;

    float Shadow = 0.0;

	for (int i=0; i < 3; i++){

	    // vec3 shadowSamplePos = WorldPos - LightPos * (pow(i,0.75)*0.25); 
	    vec3 shadowSamplePos = WorldPos - LightPos * (0.01 + pow(i,0.75)*0.25); 
	    Shadow += fogShape(shadowSamplePos)*END_STORM_DENSTIY*EndOuterIslandFogMultiplier(shadowSamplePos);
    }

	return clamp(exp2(Shadow * -10.0),0.0,1.0);
}
