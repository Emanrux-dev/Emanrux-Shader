ivec3 GetVoxelIndex(const in vec3 playerPos) {
	#if !defined IS_LPV_ENABLED && !defined SHADER_GRASS
		vec3 cameraOffset = fract(cameraPosition-relativeEyePosition);
	#else
		vec3 cameraOffset = fract(cameraPosition);
	#endif
	return ivec3(floor(playerPos + cameraOffset) + VoxelSize3/2u);
}

void SetVoxelBlock(const in ivec3 voxelPos, const in uint blockId) {
	if (clamp(voxelPos, ivec3(0), ivec3(VoxelSize-1u)) != voxelPos) return;

	imageStore(imgVoxelMask, voxelPos, uvec4(blockId));
}

void PopulateShadowVoxel(const in vec3 playerPos) {
	uint voxelId = 0u;
	vec3 originPos = playerPos;

	if (
		#ifdef COLORWHEEL
			renderStage == CLRWL_RENDER_STAGE_SOLID || renderStage == CLRWL_RENDER_STAGE_TRANSLUCENT 
		#else
			renderStage == MC_RENDER_STAGE_TERRAIN_SOLID || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT ||
			renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED
		#endif
	)
	{
		float blockID = mc_Entity.x;

		#ifdef COLORWHEEL
			if(mc_Entity.x < 0.0) blockID = blockEntityId;
		#endif

		voxelId = uint(blockID + 0.5);

		#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
			if (voxelId == 0u && at_midBlock.w > 0) voxelId = uint(BLOCK_LIGHT_1 + at_midBlock.w - 1);
		#endif

		if (voxelId == 0u) voxelId = 1u;

		originPos += at_midBlock.xyz/64.0;
	}

	#if !defined IS_LPV_ENABLED && !defined SHADER_GRASS
		ivec3 voxelPos = GetVoxelIndex(originPos+relativeEyePosition);
	#else
		ivec3 voxelPos = GetVoxelIndex(originPos);
	#endif
	
	#if defined LPV_ENTITY_LIGHTS && !defined COLORWHEEL
		if (
			((renderStage == MC_RENDER_STAGE_ENTITIES && (currentRenderedItemId > 0 || entityId > 0)) || renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES)
		) {
			if (renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES) {
				if (blockEntityId > 0 && blockEntityId < 500)
					voxelId = uint(blockEntityId);
			}
			else if (currentRenderedItemId > 100 && currentRenderedItemId < 300) {
				if (entityId != ENTITY_ITEM_FRAME && entityId != ENTITY_PLAYER) {
					voxelId = uint(currentRenderedItemId);

					// offset by a random number that came into my head to make entities and items not interact with grass
					voxelId += 2000u;

					#if defined SHADER_GRASS && REPLACE_SHORT_GRASS < 2
						uint oldID = imageLoad(imgVoxelMask, voxelPos).r;
						if(oldID == 12u) voxelId += 2000u;
					#endif
				}
			}
			else {
				switch (entityId) {
					case ENTITY_BLAZE:
					case ENTITY_END_CRYSTAL:
					// case ENTITY_FIREBALL_SMALL:
					case ENTITY_GLOW_SQUID:
					case ENTITY_MAGMA_CUBE:
					case ENTITY_SPECTRAL_ARROW:
					case ENTITY_TNT:
						voxelId = uint(entityId)+2000u;
						break;
				}
			}
		}
	#endif

	#if WATER_INTERACTION == 2 && !defined COLORWHEEL
		if (
			((renderStage == MC_RENDER_STAGE_ENTITIES && (currentRenderedItemId > 0 || entityId > 0)) || renderStage == MC_RENDER_STAGE_BLOCK_ENTITIES)
		) {
			switch (entityId) {
				case ENTITY_BOAT:
				case ENTITY_SMALLSHIPS:
					voxelId = uint(entityId)+2000u;
					break;
			}
		}
	#endif

	if (voxelId > 0u){
		SetVoxelBlock(voxelPos, voxelId);
	}
		
}