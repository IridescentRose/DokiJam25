#version 430
// Outputs
layout(location = 0) out vec4 FragColor;
layout(location = 1) out vec4 outNormal;

// Uniforms
uniform vec2  uResolution;    // viewport resolution (in pixels)
uniform mat4  uProjView;      // combined projection and view matrix
uniform mat4  uInvProjView;   // inverse of the combined projection and view matrix
uniform bool  uIsShadowPass;  // true if this is a shadow pass

struct ChunkMeta {
    ivec3 pos;   // Chunk position in chunk coordinates
    int   offset;// Offset in the voxels buffer where this chunk's data starts
};

// SSBO of all chunks
layout(binding = 1, std430) buffer ChunkBuffer { uint voxels[]; };

#define MAX_CHUNKS 121 // 11x11 grid of chunks (5 radius)
layout(binding = 2, std430) readonly buffer ChunkMetaBuffer {
    ChunkMeta metadata[MAX_CHUNKS]; // c.MAX_CHUNKS
};

const int CHUNK_BLOCKS = 16;
const int SUB_BLOCKS_PER_BLOCK = 8;
const int CHUNK_SUB_BLOCKS = CHUNK_BLOCKS * SUB_BLOCKS_PER_BLOCK;
const int SUBVOXEL_SIZE = SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK;

// scene scale
const float GRID_SCALE = 8.0;          // grid cells per world unit
const float CELL       = 1.0 / GRID_SCALE; // world units per cell

ivec3 floorDiv(ivec3 v, int d) {
    ivec3 q = v / d; // truncates toward zero
    bvec3 rem = notEqual(v - q * d, ivec3(0));
    bvec3 neg = lessThan(v, ivec3(0));
    q -= ivec3(rem) * ivec3(neg);
    return q;
}

int binarySearchMetadata(ivec3 target) {
    int low = 0, high = MAX_CHUNKS - 1;
    while (low <= high) {
        int mid = (low + high) / 2;
        ivec3 pos = metadata[mid].pos;
        if (all(equal(pos, target))) return mid;

        // YZX ordering comparison
        if ( pos.y < target.y ||
            (pos.y == target.y && pos.z < target.z) ||
            (pos.y == target.y && pos.z == target.z && pos.x < target.x)) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    return -1; // not found
}

struct MetaCache {
    ivec3 ccFull;
    int   metaIdx;
    int   offset;
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

#define DRAW_DISTANCE       384
#define SHADOW_RESOLUTION   512.0

void main()
{
    vec2 resolution = uIsShadowPass ? vec2(SHADOW_RESOLUTION) : uResolution;

    // NDC ray endpoints (use LIGHT PV/INV in shadow pass)
    vec2 uv = (gl_FragCoord.xy / resolution) * 2.0 - 1.0;
    vec4 nearPt = uInvProjView * vec4(uv, -1.0, 1.0);
    vec4 farPt  = uInvProjView * vec4(uv, +1.0, 1.0);
    vec3 rayOrigin    = nearPt.xyz / nearPt.w;
    vec3 rayDirection = normalize(farPt.xyz / farPt.w - rayOrigin);

    // --- DDA in WORLD units ----------------------------------------------------
    // starting cell index
    ivec3 mapPos = ivec3(floor(rayOrigin / CELL));

    // step direction per axis
    ivec3 stepI = ivec3(sign(rayDirection));

    // distances to cross one cell along each axis (world units)
    vec3 invR = vec3(
        (abs(rayDirection.x) > 1e-6) ? 1.0 / rayDirection.x : 1e30,
        (abs(rayDirection.y) > 1e-6) ? 1.0 / rayDirection.y : 1e30,
        (abs(rayDirection.z) > 1e-6) ? 1.0 / rayDirection.z : 1e30
    );
    vec3 tDelta = abs(vec3(CELL) * invR);

    // distance from origin to the first boundary on each axis (world units)
    float nx = (stepI.x > 0 ? (float(mapPos.x) + 1.0) : float(mapPos.x)) * CELL;
    float ny = (stepI.y > 0 ? (float(mapPos.y) + 1.0) : float(mapPos.y)) * CELL;
    float nz = (stepI.z > 0 ? (float(mapPos.z) + 1.0) : float(mapPos.z)) * CELL;

    vec3 tMax = (vec3(nx, ny, nz) - rayOrigin) * invR;

    // marching state
    bvec3 hitMask = bvec3(false);
    bool  gotHit = false;
    bool  oob = false;
    float tEnterWorld = 0.0;

    MetaCache mc; mc.valid = false;
    ivec3 ccFull = floorDiv(mapPos, CHUNK_SUB_BLOCKS);
    refreshMeta(mc, ccFull);

    uint voxel = 0u;

    // full-res march
    for (int step = 0; step < DRAW_DISTANCE; ++step) {
        // pick next boundary
        bvec3 choose = lessThanEqual(tMax, min(tMax.yzx, tMax.zxy));
        float tCandidate = min(min(tMax.x, tMax.y), tMax.z);

        // advance one cell along chosen axis
        if (choose.x) { tMax.x += tDelta.x; mapPos.x += stepI.x; }
        else if (choose.y) { tMax.y += tDelta.y; mapPos.y += stepI.y; }
        else { tMax.z += tDelta.z; mapPos.z += stepI.z; }

        // refresh chunk cache when crossing chunk bounds
        ivec3 newCC = floorDiv(mapPos, CHUNK_SUB_BLOCKS);
        if (any(notEqual(newCC, ccFull))) {
            ccFull = newCC;
            refreshMeta(mc, ccFull);
        }

        // Y bounds (treat outside as empty; allow a "sky" skip band)
        if (mapPos.y < 0 || mapPos.y >= CHUNK_SUB_BLOCKS * 4) {
            voxel = 0u; oob = true;
            if (mapPos.y >= CHUNK_SUB_BLOCKS * 4 && mapPos.y < CHUNK_SUB_BLOCKS * 4 + 256)
                continue; // skip sky band
            break; // void
        }

        if (!mc.valid) { voxel = 0u; continue; }

        // sample current cell
        ivec3 chunkCoordXZOnly = ivec3(ccFull.x, 0, ccFull.z);
        ivec3 localPos = mapPos - chunkCoordXZOnly * CHUNK_SUB_BLOCKS;
        int idx = (localPos.y * CHUNK_SUB_BLOCKS + localPos.z) * CHUNK_SUB_BLOCKS + localPos.x;
        voxel = voxels[uint(mc.offset + idx)];

        if ((voxel & 0xFFu) != 0u) {
            tEnterWorld = tCandidate;   // already in world units
            hitMask     = choose;
            gotHit      = true;
            break;
        }
    }

    // half-res fallback if nothing hit and not out-of-bounds
    if (!gotHit && !oob) {
        for (int step = 0; step < DRAW_DISTANCE / 2; ++step) {
            bvec3 choose = lessThanEqual(tMax, min(tMax.yzx, tMax.zxy));
            float tCandidate = min(min(tMax.x, tMax.y), tMax.z);

            // advance TWO cells along chosen axis
            if (choose.x) { tMax.x += 2.0 * tDelta.x; mapPos.x += 2 * stepI.x; }
            else if (choose.y) { tMax.y += 2.0 * tDelta.y; mapPos.y += 2 * stepI.y; }
            else { tMax.z += 2.0 * tDelta.z; mapPos.z += 2 * stepI.z; }

            ivec3 newCC2 = floorDiv(mapPos, CHUNK_SUB_BLOCKS);
            if (any(notEqual(newCC2, ccFull))) {
                ccFull = newCC2;
                refreshMeta(mc, ccFull);
            }

            if (mapPos.y < 0 || mapPos.y >= CHUNK_SUB_BLOCKS * 4) {
                voxel = 0u; oob = true;
                if (mapPos.y >= CHUNK_SUB_BLOCKS * 4 && mapPos.y < CHUNK_SUB_BLOCKS * 4 + 256)
                    continue;
                break;
            }

            if (!mc.valid) { voxel = 0u; continue; }

            ivec3 chunkCoordXZOnly = ivec3(ccFull.x, 0, ccFull.z);
            ivec3 localPos = mapPos - chunkCoordXZOnly * CHUNK_SUB_BLOCKS;
            int idx = (localPos.y * CHUNK_SUB_BLOCKS + localPos.z) * CHUNK_SUB_BLOCKS + localPos.x;
            voxel = voxels[uint(mc.offset + idx)];

            if ((voxel & 0xFFu) != 0u) {
                tEnterWorld = tCandidate;
                hitMask     = choose;
                gotHit      = true;
                break;
            }
        }
    }

    // depth write (both passes)
    if (gotHit) {
        vec3  hitWorld = rayOrigin + rayDirection * tEnterWorld;
        vec4  clip     = uProjView * vec4(hitWorld, 1.0);
        float ndcDepth = clip.z / clip.w * 0.5 + 0.5;
        gl_FragDepth = clamp(ndcDepth, 0.0, 1.0);
    } else {
        gl_FragDepth = 1.0;
    }

    if (uIsShadowPass) return; // depth-only for shadow map

    // normal from last stepped axis
    vec3 normal = vec3(0.0);
    if (gotHit) {
        if (hitMask.x)      normal = vec3(-sign(rayDirection.x), 0.0, 0.0);
        else if (hitMask.y) normal = vec3(0.0, -sign(rayDirection.y), 0.0);
        else                normal = vec3(0.0, 0.0, -sign(rayDirection.z));
    }
    outNormal = vec4(normal * 0.5 + 0.5, 1.0);

    // albedo
    if (gotHit) {
        vec3 baseColor = vec3(
            float((voxel >>  8) & 0xFFu),
            float((voxel >> 16) & 0xFFu),
            float((voxel >> 24) & 0xFFu)
        ) / 255.0;
        FragColor = vec4(baseColor, 1.0);
    } else {
        FragColor = vec4(0.0);
    }
}
