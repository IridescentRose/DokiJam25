#version 430
// Based on a shadertoy: https://www.shadertoy.com/view/4dX3zl
// Heavily edited to fit the context of this project

// Outputs
layout(location = 0) out vec4 FragColor;
layout(location = 1) out vec4 outNormal;

// Uniforms
uniform vec2 uResolution; // viewport resolution (in pixels)
uniform mat4 uProjView; // combined projection and view matrix
uniform mat4 uInvProjView; // inverse of the combined projection and view matrix

struct ChunkMeta {
   ivec3 pos; // Chunk position in chunk coordinates
   int offset; // Offset in the voxels buffer where this chunk's data starts
};

// SSBO of all chunks
layout(binding = 1, std430) buffer ChunkBuffer {
   uint voxels[];
};

#define MAX_CHUNKS 121 // 11x11 grid of chunks (5 radius)
layout(binding = 2, std430) readonly buffer ChunkMetaBuffer {
   ChunkMeta metadata[MAX_CHUNKS]; // c.MAX_CHUNKS
};

const int CHUNK_BLOCKS = 16; // Number of blocks in each chunk
const int SUB_BLOCKS_PER_BLOCK = 8;
const int CHUNK_SUB_BLOCKS = CHUNK_BLOCKS * SUB_BLOCKS_PER_BLOCK;
const int SUBVOXEL_SIZE = SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK;

// Shrink the scene
const float GRID_SCALE = 8.0;

// Helper: exact floor‐division for negative coords
ivec3 floorDiv(ivec3 v, int d) {
    ivec3 q = v / d;                       // truncates toward zero
    bvec3 rem = notEqual(v - q * d, ivec3(0));
    bvec3 neg = lessThan(v, ivec3(0));
    q -= ivec3(rem) * ivec3(neg);
    return q;
}

int binarySearchMetadata(ivec3 target) {
    int low = 0;
    int high = MAX_CHUNKS - 1;

    while (low <= high) {
        int mid = (low + high) / 2;
        ivec3 pos = metadata[mid].pos;

        if (all(equal(pos, target))) {
            return mid;
        }

        // YZX ordering comparison
        if (
            pos.y < target.y ||
            (pos.y == target.y && pos.z < target.z) ||
            (pos.y == target.y && pos.z == target.z && pos.x < target.x)
        ) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    return -1; // not found
}

// --------- Per-fragment metadata cache (refreshed only on chunk changes) ----------
struct MetaCache {
    ivec3 ccFull;   // current FULL chunk coord (includes Y)
    int   metaIdx;  // index into metadata[]
    int   offset;   // base voxel offset for this chunk
    bool  valid;
};

void refreshMeta(inout MetaCache mc, ivec3 ccFull) {
    if (mc.valid && all(equal(mc.ccFull, ccFull))) return;
    mc.ccFull  = ccFull;
    mc.metaIdx = binarySearchMetadata(ivec3(ccFull.x, 0, ccFull.z));
    if (mc.metaIdx < 0) {
        mc.valid = false;
        mc.offset = -1;
        return;
    }
    mc.valid  = true;
    mc.offset = metadata[mc.metaIdx].offset;
}


#define DRAW_DISTANCE 512

void main()
{
    // Normalized pixel coordinates [-1 to 1]
    vec2 uv = (gl_FragCoord.xy / uResolution) * 2.0 - 1.0;

    // Camera ray generation
    vec4 nearPt = uInvProjView * vec4(uv, -1.0, 1.0); // Near plane point
    vec4 farPt = uInvProjView * vec4(uv, +1.0, 1.0); // Far plane point
    vec3 rayOrigin = nearPt.xyz / nearPt.w; // Ray origin in world space
    vec3 rayDirection = normalize(farPt.xyz / farPt.w - rayOrigin); // Ray direction in world space

    // Initialized DDA
    ivec3 mapPos = ivec3(floor(rayOrigin * GRID_SCALE)); // Current voxel position
	vec3 deltaDist = abs(vec3(length(rayDirection * GRID_SCALE)) / rayDirection * GRID_SCALE);
    ivec3 rayStep = ivec3(sign(rayDirection * GRID_SCALE));
	vec3 sideDist = (sign(rayDirection * GRID_SCALE) * (vec3(mapPos) - rayOrigin * GRID_SCALE) + (sign(rayDirection * GRID_SCALE) * 0.5) + 0.5) * deltaDist; 
	bvec3 mask;

    float tEnter = 0.0;
    bvec3 hitMask = bvec3(false);
    bool  gotHit = false;

    int i = 0;
    MetaCache mc;
    mc.valid = false;

    // Cache current full chunk and highest_y (world)
    ivec3 ccFull = floorDiv(mapPos, CHUNK_SUB_BLOCKS);
    refreshMeta(mc, ccFull);

    bool oob = false;

    uint voxel = 0;
    if ((voxel & 0xFFu) == 0u) {
        for (i; i < DRAW_DISTANCE; i++) {
            // 1) figure out which axis we cross next
            mask = lessThanEqual(sideDist, min(sideDist.yzx, sideDist.zxy));
            float tCandidate = min(min(sideDist.x, sideDist.y), sideDist.z);
            vec3 maskF = vec3(mask);
            ivec3 maskI = ivec3(mask);
            sideDist += maskF * deltaDist;
            mapPos   += maskI * rayStep;

            // If we crossed into a new chunk, refresh cache
            ivec3 newCC = floorDiv(mapPos, CHUNK_SUB_BLOCKS);
            if (any(notEqual(newCC, ccFull))) {
                ccFull = newCC;
                refreshMeta(mc, ccFull);
            }

            // 2) now sample that new cell            
            if (mapPos.y < 0 || mapPos.y >= CHUNK_SUB_BLOCKS * 4) {
                voxel = 0u;

                oob = true;

                if(mapPos.y >= CHUNK_SUB_BLOCKS * 4 && mapPos.y < CHUNK_SUB_BLOCKS * 4 + 16) 
                    continue; // Skip sampling if we're in the sky layer

                // Otherwise we hit the void
                break;
            }

            if (!mc.valid) voxel = 0u;
            // NOTE: metadata is indexed by XZ only; local XZ are relative to ccFull.xz
            ivec3 chunkCoordXZOnly = ivec3(ccFull.x, 0, ccFull.z);
            ivec3 localPos = mapPos - chunkCoordXZOnly * CHUNK_SUB_BLOCKS;
            int idx = (localPos.y * CHUNK_SUB_BLOCKS + localPos.z) * CHUNK_SUB_BLOCKS + localPos.x;
            voxel =  voxels[uint(mc.offset + idx)];

            uint material  = voxel & 0xFFu;
            if (material != 0u) {
                tEnter  = tCandidate;
                hitMask = mask;
                gotHit  = true;
                break;
            }
        }

        if(!gotHit && !oob) {
            // Half detail
            for (i = 0; i < DRAW_DISTANCE / 2; i++) {
                // 1) figure out which axis we cross next
                mask = lessThanEqual(sideDist, min(sideDist.yzx, sideDist.zxy));
                float tCandidate = min(min(sideDist.x, sideDist.y), sideDist.z);
                vec3 maskF = vec3(mask);
                ivec3 maskI = ivec3(mask);
                sideDist += maskF * deltaDist;
                mapPos   += maskI * rayStep * 2;

                // Refresh cache on chunk-cross and perform at-most-once-per-chunk skip
                ivec3 newCC2 = floorDiv(mapPos, CHUNK_SUB_BLOCKS);
                if (any(notEqual(newCC2, ccFull))) {
                    ccFull = newCC2;
                    refreshMeta(mc, ccFull);
                }

                // 2) now sample that new cell            
                if (mapPos.y < 0 || mapPos.y >= CHUNK_SUB_BLOCKS * 4) {
                    voxel = 0u;
                    break;
                }

                if (!mc.valid) voxel = 0u;
                // NOTE: metadata is indexed by XZ only; local XZ are relative to ccFull.xz
                ivec3 chunkCoordXZOnly = ivec3(ccFull.x, 0, ccFull.z);
                ivec3 localPos = mapPos - chunkCoordXZOnly * CHUNK_SUB_BLOCKS;
                int idx = (localPos.y * CHUNK_SUB_BLOCKS + localPos.z) * CHUNK_SUB_BLOCKS + localPos.x;
                voxel =  voxels[uint(mc.offset + idx)];
                
                uint material  = voxel & 0xFFu;
                if (material != 0u) {
                    tEnter  = tCandidate;
                    hitMask = mask;
                    gotHit  = true;
                    break;
                }
            }
        }

    }

    if (gotHit) {
        // Compute grid-space hit distance
        float tGrid = tEnter;
        // Convert to world-space distance
        float tWorld = tGrid / GRID_SCALE / GRID_SCALE / GRID_SCALE;
        // Compute world-space hit position
        vec3 hitWorld = rayOrigin + rayDirection * tWorld;
        // Project and map to [0,1]
        vec4 clip = uProjView * vec4(hitWorld, 1.0);
        float ndcDepth = clip.z / clip.w * 0.5 + 0.5;


        gl_FragDepth = ndcDepth;
    } else {
        gl_FragDepth = 1.0; // Set depth to far plane if no hit
    }

    // Compute normal from last step
    vec3 normal = vec3(0.0);
    if (gotHit) {
        // Determine which axis was stepped last
        if (mask.x) normal = vec3(-sign(rayDirection.x), 0.0, 0.0);
        else if (mask.y) normal = vec3(0.0, -sign(rayDirection.y), 0.0);
        else normal = vec3(0.0, 0.0, -sign(rayDirection.z));
    }

    // Output normal packed to [0,1]
    outNormal = vec4(normal * 0.5 + 0.5, 1.0);


    // Color shading with voxel AO
    if (gotHit) {
        vec3 baseColor = vec3(
            float((voxel >> 8) & 0xFFu),
            float((voxel >> 16) & 0xFFu),
            float((voxel >> 24) & 0xFFu)
        ) / 255.0;

        FragColor = vec4(baseColor, 1.0);
    } else {
        FragColor = vec4(0.0);
    }
}