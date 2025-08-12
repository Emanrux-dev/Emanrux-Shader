#ifndef MC_OS_MAC
	#version 430 compatibility
#else
	#version 120
#endif

#include "/lib/settings.glsl"


//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	gl_FragData[0] = vec4(0.0);
}
