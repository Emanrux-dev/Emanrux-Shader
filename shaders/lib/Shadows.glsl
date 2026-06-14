void GriAndEminShadowFix(
	inout vec3 WorldPos,
	vec3 FlatNormal,
	float transition
){
	transition = 1.0-transition;
	transition *= transition*transition*transition*transition*transition*transition;
	float zoomLevel = mix(0.0, 0.5, transition);

	if(zoomLevel > 0.001 && isEyeInWater != 1) WorldPos = WorldPos - (	fract(WorldPos+cameraPosition - WorldPos*0.0001)*zoomLevel - zoomLevel*0.5);
}

void applyShadowBias(inout vec3 projectedShadowPosition, in vec3 playerPos, in vec3 geoNormals){

	float biasSize = (shadowDistance / shadowMapResolution*2.0) * 2.0;

	float biasDistanceFactor = length(projectedShadowPosition.xy);

	biasDistanceFactor = 1.0 + biasDistanceFactor * ((16.0*8.0) / shadowDistance) * 0.1;
	float normalBiasStrength = 0.15;

	#if defined END_ISLAND_LIGHT && defined END_SHADER
		normalBiasStrength = 0.32;
	#endif

	#if defined CUSTOM_MOON_ROTATION || (defined END_ISLAND_LIGHT && defined END_SHADER)
		projectedShadowPosition += (mat3(customShadowMatrixSSBO) * geoNormals) * biasSize * normalBiasStrength * biasDistanceFactor;
	#else
		projectedShadowPosition += (mat3(shadowModelView) * geoNormals) * biasSize * normalBiasStrength * biasDistanceFactor;
	#endif
}
