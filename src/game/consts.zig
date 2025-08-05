const gfx = @import("../gfx/gfx.zig");

pub const top_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{ .vert = [_]f32{ -0.5, 0.5, -0.5 } },
    gfx.Mesh.Vertex{ .vert = [_]f32{ -0.5, 0.5, 0.5 } },
    gfx.Mesh.Vertex{ .vert = [_]f32{ 0.5, 0.5, 0.5 } },
    gfx.Mesh.Vertex{ .vert = [_]f32{ 0.5, 0.5, -0.5 } },
};

pub const particle_front_face = [_]gfx.ParticleMesh.Vertex{
    gfx.ParticleMesh.Vertex{ .vert = [_]f32{ -0.05, -0.7, 0 } },
    gfx.ParticleMesh.Vertex{ .vert = [_]f32{ 0.05, -0.7, 0 } },
    gfx.ParticleMesh.Vertex{ .vert = [_]f32{ 0.05, 0.7, 0 } },
    gfx.ParticleMesh.Vertex{ .vert = [_]f32{ -0.05, 0.7, 0 } },
};

pub const SUB_BLOCKS_PER_BLOCK = 8;
pub const CHUNK_BLOCKS = 16;
pub const CHUNK_SUB_BLOCKS = CHUNK_BLOCKS * SUB_BLOCKS_PER_BLOCK;
pub const CHUNK_SUBVOXEL_SIZE = CHUNK_SUB_BLOCKS * CHUNK_SUB_BLOCKS * CHUNK_SUB_BLOCKS;
pub const SUBVOXEL_SIZE = SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK * SUB_BLOCKS_PER_BLOCK;
