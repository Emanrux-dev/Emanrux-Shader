#ifdef MC_OS_MAC
	#ifndef MC_OS_MAC
	#version 430 compatibility
#else
	#version 120
#endif
#else
	#version 430 compatibility
#endif

#define WEATHER
#define OVERWORLD_SHADER

#include "/dimensions/all_particles.fsh"