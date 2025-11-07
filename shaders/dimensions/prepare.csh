#include "/lib/settings.glsl"
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

#include "/lib/util.glsl"
uniform vec3 cameraPosition;
uniform vec3 relativeEyePosition;

#include "/lib/blocks.glsl"
#include "/lib/entities.glsl"
#include "/lib/lpv_common.glsl"
#include "/lib/lpv_blocks.glsl"
#include "/lib/lpv_buffer.glsl"
#include "/lib/voxel_common.glsl"

uint GetVoxelBlock(const in ivec3 voxelPos) {
    if (clamp(voxelPos, ivec3(0), ivec3(VoxelSize3-1u)) != voxelPos)
        return BLOCK_EMPTY;
    
    return imageLoad(imgVoxelMask, voxelPos).r % 2000u;
}

#include "/lib/SSBOs.glsl"

uniform bool is_sneaking;
uniform float frameTimeCounter;

void main() {
    #if WATER_INTERACTION == 2
    if (abs(frameTimeCounter - lastFrameTimeCount) > WATER_SIM_FRAMETIME) {
        float playerTallness = 1.5;
        if(is_sneaking) playerTallness = 1.2;
        #if !defined IS_LPV_ENABLED && !defined SHADER_GRASS
            vec3 rayStart = vec3(0.0);
        #else
            vec3 rayStart = vec3(-relativeEyePosition);
        #endif
        vec3 LPVpos = GetLpvPosition(rayStart);
        uint BlockID1 = GetVoxelBlock(ivec3(LPVpos));
        uint BlockID2 = GetVoxelBlock(ivec3(LPVpos.x, LPVpos.y - 0.5*playerTallness, LPVpos.z));
        uint BlockID3 = GetVoxelBlock(ivec3(LPVpos.x, LPVpos.y - playerTallness, LPVpos.z));


        // Big shenanigans lol, don't ask, it just works
        if(noSimOngoingCheck == true) {
            noSimOngoing = true;
        } else {
            noSimOngoing = false;
        }
        noSimOngoingCheck = true;
        inShip = false;
        onWaterSurface = false;
        inBoat = false;
        bool inBoat2Frames = inBoatLastFrame;
        inBoatLastFrame = inBoatCurrentFrame;
        inBoatCurrentFrame = false;

        bool inShip2Frames = inShipLastFrame;
        inShipLastFrame = inShipCurrentFrame;
        inShipCurrentFrame = false;

        if(BlockID1 == BLOCK_WATER || BlockID2 == BLOCK_WATER || BlockID3 == BLOCK_WATER) onWaterSurface = true;

        if(BlockID1 == ENTITY_BOAT || BlockID2 == ENTITY_BOAT || BlockID3 == ENTITY_BOAT) inBoatCurrentFrame = true;

        if(BlockID1 == ENTITY_SMALLSHIPS || BlockID2 == ENTITY_SMALLSHIPS || BlockID3 == ENTITY_SMALLSHIPS) inShipCurrentFrame = true;

        if(inBoatCurrentFrame || inBoatLastFrame || inBoat2Frames) inBoat = true;

        if(inShipCurrentFrame || inShipLastFrame || inShip2Frames) inShip = true;
    }
    #endif
}