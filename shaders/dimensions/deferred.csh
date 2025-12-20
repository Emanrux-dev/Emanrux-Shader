#include "/lib/settings.glsl"
#include "/lib/SSBOs.glsl"
#include "/lib/res_params.glsl"
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

uniform vec2 texelSize;
uniform sampler2D colortex6;
uniform float frameTime;
uniform float far;
uniform float near;
uniform int frameCounter;
uniform sampler2D depthtex2;


float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}
//Low discrepancy 2D sequence, integration error is as low as sobol but easier to compute : http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

void main() {
    //////////////////////////////
    /// --- EXPOSURE STUFF --- ///
    //////////////////////////////

	vec2 clampedRes = max(1.0/texelSize,vec2(1920.0,1080.));
	float avgExp = 0.0;
	float avgB = 0.0;
	vec2 resScale = vec2(1920.,1080.)/clampedRes;
	const int maxITexp = 50;
	for (int i = 0; i < maxITexp; i++){
			vec2 ij = R2_samples((frameCounter%2000)*maxITexp+i);
			vec2 tc = 0.5 + (ij-0.5) * 0.7;
			vec3 sp = texture(colortex6, tc/16. * resScale+vec2(0.375*resScale.x+4.5*texelSize.x,.0)).rgb;
			avgExp += log(sqrt(luma(sp)));
			avgB += log(min(dot(sp,vec3(0.07,0.22,0.71)),8e-2));
	}

	avgExp = exp(avgExp/maxITexp);
	avgB = exp(avgB/maxITexp);

	float avgBrightness = clamp(mix(avgExp,avgBrightnessSSBO,0.95),0.00003051757,65000.0);

	float L = max(avgBrightness,1e-8);
	// float keyVal = 1.03-2.0/(log(L*4000/150.*8./3.0+1.0)/log(10.0)+2.0);
	// float expFunc = 0.5+0.5*tanh(log(L));
	
	// float targetExposure = 1.0/log(L+1.05);
	float targetExposure = (EXPOSURE_DARKENING * 0.35)/log(L+1.0 + EXPOSURE_BRIGHTENING * 0.05);
	// float targetExposure = 0.18/log2(L*2.5+1.045)*0.62; // choc original

	float avgL2 = clamp(mix(avgB,avgL2SSBO,0.985),0.00003051757,65000.0);
	float targetrodExposure = max(0.012/log2(avgL2+1.002)-0.1,0.0)*1.2;


	float exposure = max(targetExposure*EXPOSURE_MULTIPLIER, 0.0);

	float currCenterDepth = ld(texture(depthtex2, vec2(0.5)*RENDER_SCALE).r);
	float centerDepth = mix(sqrt(rodExposureDepthSSBO.y/65000.0), currCenterDepth, clamp(DoF_Adaptation_Speed*exp(-0.016/frameTime+1.0)/(6.0+currCenterDepth*far),0.0,1.0));
	centerDepth = centerDepth * centerDepth * 65000.0;

	float rodExposure = targetrodExposure;

	#ifndef AUTO_EXPOSURE
	 exposure = Manual_exposure_value;
	 rodExposure = clamp(log(Manual_exposure_value*2.0+1.0)-0.1,0.0,2.0);
	#endif

    //Exposure values
    exposureSSBO = exposure;
    avgBrightnessSSBO = avgBrightness;
    avgL2SSBO = avgL2;
    rodExposureDepthSSBO = vec2(rodExposure, centerDepth);
}