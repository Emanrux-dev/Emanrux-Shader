#ifdef MC_OS_MAC
	#ifndef MC_OS_MAC
	#version 430 compatibility
#else
	#version 120
#endif
#else
	#version 430 compatibility
#endif

#define DAMAGE_BLOCK_EFFECT

#include "/dimensions/all_particles.fsh"