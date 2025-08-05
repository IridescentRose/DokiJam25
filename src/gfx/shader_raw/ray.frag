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

// SSBO of all chunks
layout(binding = 1, std430) buffer ChunkBuffer {
   uint data[];
} voxels;


const int CHUNK_BLOCKS = 16; // Number of blocks in each chunk
const int SUB_BLOCKS_PER_BLOCK = 8;
const int SUBVOXEL_SIZE = SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK;

// Shrink the scene
const float GRID_SCALE = 8.0;

uint getVoxel(ivec3 p) {

   if(any(lessThan(p, ivec3(0))) || any(greaterThanEqual(p, ivec3(CHUNK_BLOCKS * SUB_BLOCKS_PER_BLOCK)))) {
      return 0; // Out of bounds, treat as empty voxel
   }

   ivec3 blockCoord = ivec3(p.x / SUB_BLOCKS_PER_BLOCK, p.y / SUB_BLOCKS_PER_BLOCK, p.z / SUB_BLOCKS_PER_BLOCK);
   ivec3 subCoord = ivec3(p.x % SUB_BLOCKS_PER_BLOCK, p.y % SUB_BLOCKS_PER_BLOCK, p.z % SUB_BLOCKS_PER_BLOCK);

    // Base index for the block
    int blockIndex = ((blockCoord.y * CHUNK_BLOCKS + blockCoord.z) * CHUNK_BLOCKS + blockCoord.x)
                     * SUBVOXEL_SIZE;

    // Offset within the block
    int subIndex = (subCoord.y * SUB_BLOCKS_PER_BLOCK + subCoord.z) * SUB_BLOCKS_PER_BLOCK
                   + subCoord.x;

    int idx = blockIndex + subIndex;
    return voxels.data[idx];
} 

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


   mask      = lessThanEqual(sideDist, min(sideDist.yzx, sideDist.zxy));
   sideDist += vec3(mask) * deltaDist;
   mapPos   += ivec3(mask) * rayStep;

   uint voxel = 0;
   for (int i = 0; i < 511; i++) {
      // 1) figure out which axis we cross next
      mask      = lessThanEqual(sideDist, min(sideDist.yzx, sideDist.zxy));
      sideDist += vec3(mask) * deltaDist;
      mapPos   += ivec3(mask) * rayStep;

      // 2) now sample that new cell
      voxel     = getVoxel(mapPos);
      uint material  = voxel & 0xFFu;
      if (material != 0u) {
         break;
      }
   }

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

    // Color shading
    if ((voxel & 0xFFu) != 0u) {
        FragColor = vec4(vec3(
            float((voxel >> 8) & 0xFFu),
            float((voxel >> 16) & 0xFFu),
            float((voxel >> 24) & 0xFFu)
        ) / 255.0, 1.0);
    } else {
      FragColor = vec4(0.0);
    }
}