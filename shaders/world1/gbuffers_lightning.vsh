#ifndef MC_OS_MAC
	#version 430 compatibility
#else
	#version 120
#endif

#define WORLD
#define OVERWORLD_SHADER //otherwise it won't work for some reason...
#define LIGHTNING
#define ENTITIES

#include "/dimensions/all_translucent.vsh"