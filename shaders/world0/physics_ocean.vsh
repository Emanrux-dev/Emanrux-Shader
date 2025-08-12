#ifndef MC_OS_MAC
	#version 430 compatibility
#else
	#version 120
#endif

#define PHYSICSMOD_VERTEX
#define PHYSICSMOD_OCEAN_SHADER
#define OVERWORLD_SHADER

#include "/dimensions/all_translucent.vsh"