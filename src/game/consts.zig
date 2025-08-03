const gfx = @import("../gfx/gfx.zig");

pub const top_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 1, .z = 0, .face = 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 1, .z = 1, .face = 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 1, .z = 1, .face = 0 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 1, .z = 0, .face = 0 },
    },
};
pub const bot_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 0, .z = 1, .face = 1 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 0, .z = 1, .face = 1 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 0, .z = 0, .face = 1 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 0, .z = 0, .face = 1 },
    },
};
pub const front_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 0, .z = 1, .face = 2 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 0, .z = 1, .face = 2 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 1, .z = 1, .face = 2 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 1, .z = 1, .face = 2 },
    },
};
pub const back_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 1, .z = 0, .face = 3 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 0, .z = 0, .face = 3 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 0, .z = 0, .face = 3 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 1, .z = 0, .face = 3 },
    },
};
pub const right_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 0, .z = 0, .face = 4 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 1, .z = 0, .face = 4 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 1, .z = 1, .face = 4 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 1, .y = 0, .z = 1, .face = 4 },
    },
};
pub const left_face = [_]gfx.Mesh.Vertex{
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 1, .z = 1, .face = 5 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 1, .z = 0, .face = 5 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 0, .z = 0, .face = 5 },
    },
    gfx.Mesh.Vertex{
        .col = [_]u8{ 255, 255, 255 },
        .vert = .{ .x = 0, .y = 0, .z = 1, .face = 5 },
    },
};

pub const SUB_BLOCKS_PER_BLOCK = 16;
pub const CHUNK_BLOCKS = 16;
pub const CHUNK_SUB_BLOCKS = CHUNK_BLOCKS * SUB_BLOCKS_PER_BLOCK;
