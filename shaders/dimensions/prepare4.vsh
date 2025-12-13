#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"
uniform vec2 texelSize;

void main() {
	gl_Position = ftransform()*0.5+0.5;
	gl_Position.xy = gl_Position.xy*vec2(18.+258*2,258.)*texelSize;
	gl_Position.xy = gl_Position.xy*2.-1.0;
}