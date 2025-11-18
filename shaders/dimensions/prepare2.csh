// Base water ripple shader from https://www.shadertoy.com/view/wdtyDH
// heavily edited

#include "/lib/settings.glsl"
layout (local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

#if WATER_SIM_SCALE == 0
    #if WATER_SIM_DISTANCE == 1
        const ivec3 workGroups = ivec3(16, 16, 1);
    #elif WATER_SIM_DISTANCE == 2
        const ivec3 workGroups = ivec3(32, 32, 1);
    #elif WATER_SIM_DISTANCE == 3
        const ivec3 workGroups = ivec3(48, 48, 1);
    #else
        const ivec3 workGroups = ivec3(64, 64, 1);
    #endif
#elif WATER_SIM_SCALE == 1
    #if WATER_SIM_DISTANCE == 1
        const ivec3 workGroups = ivec3(32, 32, 1);
    #elif WATER_SIM_DISTANCE == 2
        const ivec3 workGroups = ivec3(64, 64, 1);
    #elif WATER_SIM_DISTANCE == 3
        const ivec3 workGroups = ivec3(96, 96, 1);
    #else
        const ivec3 workGroups = ivec3(128, 128, 1);
    #endif
#else
    #if WATER_SIM_DISTANCE == 1
        const ivec3 workGroups = ivec3(64, 64, 1);
    #elif WATER_SIM_DISTANCE == 2
        const ivec3 workGroups = ivec3(128, 128, 1);
    #elif WATER_SIM_DISTANCE == 3
        const ivec3 workGroups = ivec3(192, 192, 1);
    #else
        const ivec3 workGroups = ivec3(256, 256, 1);
    #endif
#endif


layout (rg16f) uniform image2D waveSim;
layout (rgba16f) uniform image2D waveSim2;

const ivec2 resolution = ivec2(workGroups.x * 32, workGroups.y * 32);

uniform int frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 relativeEyePosition;

#include "/lib/SSBOs.glsl"

// Make this a smaller number for a smaller timestep.
// Don't make it bigger than 1.4 or the universe will explode.
#if WATER_SIM_SCALE == 0
    const float delta = 0.6;
#elif WATER_SIM_SCALE == 1
    const float delta = 1.0;
#else
    const float delta = 1.4;
#endif

void main() {
    #if WATER_INTERACTION == 2
    if (abs(frameTimeCounter - lastFrameTimeCount) > WATER_SIM_FRAMETIME && (!noSimOngoing || onWaterSurface)) {
        if (frameCounter == 0) return;
        ivec2 imgCoord = ivec2(gl_GlobalInvocationID.xy);
        float dist = length(imgCoord-0.5*resolution);
        if (dist >= resolution.x) return;

        ivec2 sampledCoord = imgCoord;
        sampledCoord = clamp(sampledCoord, ivec2(1), resolution - ivec2(1));
        
        vec2 oldState = imageLoad(waveSim, sampledCoord).rg;

        float pressure = oldState.x;
        float pVel = oldState.y;

        #if WATER_SIM_FRAMERATE == 30
            int offset = 2;
        #else
            int offset = 1;
        #endif
        
        float p_down = imageLoad(waveSim, clamp(sampledCoord + ivec2(0, -offset), ivec2(offset), resolution - ivec2(offset))).r;
        float p_left = imageLoad(waveSim, clamp(sampledCoord + ivec2(-offset, 0), ivec2(offset), resolution - ivec2(offset))).r;
        float p_right = imageLoad(waveSim, clamp(sampledCoord + ivec2(offset, 0), ivec2(offset), resolution - ivec2(offset))).r;
        float p_up = imageLoad(waveSim, clamp(sampledCoord + ivec2(0, offset), ivec2(offset), resolution - ivec2(offset))).r;

        // Change values so the screen boundaries aren't fixed.
        //if (imgCoord.x == 0.5) p_left = p_right;
        //if (imgCoord.x == resolution.x - 0.5) p_right = p_left;
        //if (imgCoord.y == 0.5) p_down = p_up;
        //if (imgCoord.y == resolution.y - 0.5) p_up = p_down;


        // Apply horizontal wave function
        pVel += delta * (-2.0 * pressure + p_right + p_left) / 4.0;
        // Apply vertical wave function (these could just as easily have been one line)
        pVel += delta * (-2.0 * pressure + p_up + p_down) / 4.0;
        
        // Change pressure by pressure velocity
        pressure += delta * pVel;
        
        // "Spring" motion. This makes the waves look more like water waves and less like sound waves.
        pVel -= 0.0014 * delta * pressure;
        
        // Velocity damping so things eventually calm down
        pVel *= 1.0 - 0.003 * delta;
        
        // Pressure damping to prevent it from building up forever.
        float distFade = smoothstep(0.49*resolution.x, 0.4*resolution.x, dist);
        pressure *= 0.985 * distFade;
        pVel *= distFade;

        if (onWaterSurface) {
            vec3 velocity = (cameraPosition-relativeEyePosition-previousCameraPositionWave)/frameTime;
            velocity.y *= 1.15;
            float speed = length(velocity);

            float size = 10.0;
            if(inBoat) {
                size += 26.0 * smoothstep(0.0, 10.0, speed);
            } else if (inShip) {
                size += 61.0 * smoothstep(0.0, 10.0, speed);
            } else {
                size += 10.0 * smoothstep(0.1, 13.0, speed);
            }
            #if WATER_SIM_SCALE == 0
                size *= 0.5;
            #else
                size *= WATER_SIM_SCALE;
            #endif

            float upOrDown = step(-0.1, cameraPosition.y-relativeEyePosition.y-previousCameraPositionWave.y)*2.0-1.0;

            pressure += smoothstep(size, 0.7*size, dist) * upOrDown;
        }

        imageStore(waveSim2, imgCoord, vec4(pressure, pVel, (p_right - p_left) / 2.0, (p_up - p_down) / 2.0));
    }
    #endif
}