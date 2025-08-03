const gfx = @import("../gfx/gfx.zig");

pub const top_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 1, 0 },
        .norm = [_]f32{ 0, 1, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 1, 1 },
        .norm = [_]f32{ 0, 1, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 1, 1 },
        .norm = [_]f32{ 0, 1, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .norm = [_]f32{ 0, 1, 0 },
        .vert = [_]f32{ 1, 1, 0 },
    },
};
pub const bot_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 0, 1 },
        .norm = [_]f32{ 0, -1, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 0, 1 },
        .norm = [_]f32{ 0, -1, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 0, 0 },
        .norm = [_]f32{ 0, -1, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 0, 0 },
        .norm = [_]f32{ 0, -1, 0 },
    },
};
pub const front_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 0, 1 },
        .norm = [_]f32{ 0, 0, 1 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 0, 1 },
        .norm = [_]f32{ 0, 0, 1 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 1, 1 },
        .norm = [_]f32{ 0, 0, 1 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 1, 1 },
        .norm = [_]f32{ 0, 0, 1 },
    },
};
pub const back_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 1, 0 },
        .norm = [_]f32{ 0, 0, -1 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 0, 0 },
        .norm = [_]f32{ 0, 0, -1 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 0, 0 },
        .norm = [_]f32{ 0, 0, -1 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 1, 0 },
        .norm = [_]f32{ 0, 0, -1 },
    },
};
pub const right_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 0, 0 },
        .norm = [_]f32{ 1, 0, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 1, 0 },
        .norm = [_]f32{ 1, 0, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 1, 1 },
        .norm = [_]f32{ 1, 0, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 1, 0, 1 },
        .norm = [_]f32{ 1, 0, 0 },
    },
};
pub const left_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 1, 1 },
        .norm = [_]f32{ -1, 0, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 1, 0 },
        .norm = [_]f32{ -1, 0, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 0, 0 },
        .norm = [_]f32{ -1, 0, 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255, 255 },
        .tex = [_]f32{ 0, 0 },
        .vert = [_]f32{ 0, 0, 1 },
        .norm = [_]f32{ -1, 0, 0 },
    },
};

pub const SUB_BLOCKS_PER_BLOCK = 16;
pub const CHUNK_BLOCKS = 16;
pub const CHUNK_SUB_BLOCKS = CHUNK_BLOCKS * SUB_BLOCKS_PER_BLOCK;
