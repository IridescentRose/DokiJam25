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
layout(binding = 2, std430) buffer ChunkMetaBuffer {
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

uint getVoxel(ivec3 p) {
    if (p.y < 0 || p.y >= CHUNK_SUB_BLOCKS * 4)
        return 0u;

    ivec3 chunkCoord = floorDiv(p, CHUNK_SUB_BLOCKS);
    chunkCoord.y = 0; // Ignore Y for chunk search, only X and Z matter
    ivec3 localPos   = p - chunkCoord * CHUNK_SUB_BLOCKS;

    int idx = (localPos.y * CHUNK_SUB_BLOCKS + localPos.z) * CHUNK_SUB_BLOCKS + localPos.x;

    int metaIndex = binarySearchMetadata(chunkCoord);
    if (metaIndex < 0) return 0u;

    uint offset = uint(metadata[metaIndex].offset);
    return voxels[offset + uint(idx)];
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


    // DDA Loops
    uint voxel = getVoxel(mapPos);
    if ((voxel & 0xFFu) == 0u) {
        for (int i = 0; i < DRAW_DISTANCE; i++) {
            // 1) figure out which axis we cross next
            mask = lessThanEqual(sideDist, min(sideDist.yzx, sideDist.zxy));
            vec3 maskF = vec3(mask);
            ivec3 maskI = ivec3(mask);
            sideDist += maskF * deltaDist;
            mapPos   += maskI * rayStep;


            // 2) now sample that new cell
            voxel     = getVoxel(mapPos);
            uint material  = voxel & 0xFFu;
            if (material != 0u) {
                break;
            }
        }

        if(voxel == 0u) {
            // Half detail
            for (int i = 0; i < DRAW_DISTANCE / 2; i++) {
                // 1) figure out which axis we cross next
                mask = lessThanEqual(sideDist, min(sideDist.yzx, sideDist.zxy));
                vec3 maskF = vec3(mask);
                ivec3 maskI = ivec3(mask);
                sideDist += maskF * deltaDist;
                mapPos   += maskI * rayStep * 2;


                // 2) now sample that new cell
                voxel     = getVoxel(mapPos);
                uint material  = voxel & 0xFFu;
                if (material != 0u) {
                    break;
                }
            }
        }

    }


    if ((voxel & 0xFFu) != 0u) {
        // Compute grid-space hit distance
        float tGrid = min(min(sideDist.x, sideDist.y), sideDist.z);
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
    if ((voxel & 0xFFu) != 0u) {
        // Determine which axis was stepped last
        if (mask.x) normal = vec3(-sign(rayDirection.x), 0.0, 0.0);
        else if (mask.y) normal = vec3(0.0, -sign(rayDirection.y), 0.0);
        else normal = vec3(0.0, 0.0, -sign(rayDirection.z));
    }

    // Output normal packed to [0,1]
    outNormal = vec4(normal * 0.5 + 0.5, 1.0);


    // Color shading with voxel AO
    if ((voxel & 0xFFu) != 0u) {
        vec3 baseColor = vec3(
            float((voxel >> 8) & 0xFFu),
            float((voxel >> 16) & 0xFFu),
            float((voxel >> 24) & 0xFFu)
        ) / 255.0;

        // Sample adjacent 6 directions
        int occlusion = 0;
        const ivec3 offsets[3] = ivec3[3](
            ivec3(1, 0, 0),
            ivec3(0, 1, 0),
            ivec3(0, 0, 1)
        );

        for (int i = 0; i < 3; ++i) {
            if ((getVoxel(mapPos + offsets[i]) & 0xFFu) != 0u) occlusion++;
            if ((getVoxel(mapPos - offsets[i]) & 0xFFu) != 0u) occlusion++;
        }

        float ao = 1.0 - float(occlusion) / 3.0;
        ao = mix(0.7, 1.0, ao);
        baseColor *= mix(vec3(1.0), vec3(ao), smoothstep(0.0, 0.7, length(baseColor)));


        FragColor = vec4(baseColor, 1.0);
    } else {
        FragColor = vec4(0.0);
    }
}