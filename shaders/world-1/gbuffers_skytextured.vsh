#ifndef MC_OS_MAC
	#version 430 compatibility
#else
	#version 120
#endif

void main() {
	gl_Position = ftransform();
}