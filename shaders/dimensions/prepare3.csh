#include "/lib/settings.glsl"
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#include "/lib/SSBOs.glsl"

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform vec3 relativeEyePosition;

#if IRIS_VERSION >= 11004
  uniform vec3 relativeVehiclePosition;
  uniform bool isRiding;
#endif

void main() {
  #if WATER_INTERACTION == 2
    if (abs(frameTimeCounter - lastFrameTimeCount) > WATER_SIM_FRAMETIME) {
      lastFrameTimeCount = frameTimeCounter;
      
      #if IRIS_VERSION >= 11004
      if(isRiding) {
        previousCameraPositionWave2 = cameraPosition - relativeVehiclePosition;
      } else
      #endif
      {
        previousCameraPositionWave2 = cameraPosition - relativeEyePosition;
      }
    }

    #if IRIS_VERSION >= 11004
    if(isRiding) {
      previousCameraPositionWave = cameraPosition - relativeVehiclePosition;
    } else
    #endif
    {
      previousCameraPositionWave = cameraPosition - relativeEyePosition;
    }
  #endif
}