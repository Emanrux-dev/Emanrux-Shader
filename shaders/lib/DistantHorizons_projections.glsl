/////// ALL OF THIS IS BASED OFF OF THE DISTANT HORIZONS EXAMPLE PACK BY NULL

uniform mat4 dhPreviousProjection;
uniform mat4 dhProjectionInverse;
uniform mat4 dhProjection;

uniform mat4 vxProj;
uniform mat4 vxProjInv;
uniform mat4 vxProjPrev;

#ifdef DISTANT_HORIZONS
	#define dhVoxyProjection dhProjection
	#define dhVoxyProjectionInverse dhProjectionInverse
	#define dhVoxyProjectionPrev dhPreviousProjection
#else
	#define dhVoxyProjection vxProj
	#define dhVoxyProjectionInverse vxProjInv
	#define dhVoxyProjectionPrev vxProjPrev
#endif

vec3 toScreenSpace_DH( vec2 texcoord, float depth, float DHdepth ) {

	vec4 viewPos = vec4(0.0);
	vec3 feetPlayerPos = vec3(0.0);
	vec4 iProjDiag = vec4(0.0);

	#if defined DISTANT_HORIZONS || defined VOXY
    	if (depth < 1.0) {
	#endif
			iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);

    		feetPlayerPos = vec3(texcoord, depth) * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
			viewPos.xyz /= viewPos.w;
	
	#if defined DISTANT_HORIZONS || defined VOXY
		} else {
			iProjDiag = vec4(dhVoxyProjectionInverse[0].x, dhVoxyProjectionInverse[1].y, dhVoxyProjectionInverse[2].zw);

    		feetPlayerPos = vec3(texcoord, DHdepth) * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + dhVoxyProjectionInverse[3];
			viewPos.xyz /= viewPos.w;
		}
	#endif

    return viewPos.xyz;
}
vec3 toClipSpace3_DH( vec3 viewSpacePosition, bool depthCheck ) {

	#if defined DISTANT_HORIZONS || defined VOXY
		mat4 projectionMatrix = depthCheck ? dhVoxyProjection : gbufferProjection;
   		return projMAD(projectionMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#else
    	return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#endif

}

mat4 DH_shadowProjectionTweak( in mat4 projection){
	
	#ifdef DH_SHADOWPROJECTIONTWEAK
		
		float _far = (3.0 * far);

		#if defined DISTANT_HORIZONS || defined VOXY
		    _far = 2.0 * dhVoxyFarPlane;
		#endif
		
		mat4 newProjection = projection;
		newProjection[2][2] = -2.0 / _far;
		newProjection[3][2] = 0.0;

		return newProjection;
	#else
		return projection;
	#endif
}
