const gfx = @import("../gfx/gfx.zig");

pub const top_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{ .vert = [_]f32{ -0.5, 0.5, -0.5 } },
    gfx.Mesh.Vertex{ .vert = [_]f32{ -0.5, 0.5, 0.5 } },
    gfx.Mesh.Vertex{ .vert = [_]f32{ 0.5, 0.5, 0.5 } },
    gfx.Mesh.Vertex{ .vert = [_]f32{ 0.5, 0.5, -0.5 } },
};

pub const SUB_BLOCKS_PER_BLOCK = 8;
pub const CHUNK_BLOCKS = 16;
pub const CHUNK_SUB_BLOCKS = CHUNK_BLOCKS * SUB_BLOCKS_PER_BLOCK;
pub const CHUNK_SUBVOXEL_SIZE = CHUNK_SUB_BLOCKS * CHUNK_SUB_BLOCKS * CHUNK_SUB_BLOCKS;
pub const SUBVOXEL_SIZE = SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK;

pub const CHUNK_RADIUS = 5;
pub const CHUNK_ACTUAL_DIAMETER = CHUNK_RADIUS * 2 + 1;
pub const MAX_CHUNKS = CHUNK_ACTUAL_DIAMETER * CHUNK_ACTUAL_DIAMETER;
