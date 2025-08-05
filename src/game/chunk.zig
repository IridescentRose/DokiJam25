const std = @import("std");
const gfx = @import("../gfx/gfx.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");
const world = @import("world.zig");
const Transform = @import("../gfx/transform.zig");
const ChunkMesh = @import("chunkmesh.zig");

pub const AtomKind = enum(u8) {
    Air,
    Dirt,
    Stone,
    Water,
};

pub const AtomFlags = packed struct(u8) {
    reserved: u8,
};

pub const Atom = struct {
    material: AtomKind,
    color: [3]u8,

    comptime {
        if (@sizeOf(Atom) != 4) {
            @compileError("Atom struct size must be 4 bytes");
        }
    }
};

subvoxels: std.ArrayList(Atom),
cmesh: ChunkMesh,

const Self = @This();

pub fn new() !Self {
    var res: Self = .{
        .subvoxels = std.ArrayList(Atom).init(util.allocator()),
        .cmesh = try ChunkMesh.new(),
    };

    try res.subvoxels.resize(c.CHUNK_SUBVOXEL_SIZE);
    @memset(res.subvoxels.items, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });

    return res;
}

pub fn deinit(self: *Self) void {
    self.cmesh.deinit();
    self.subvoxels.deinit();
}

pub fn get_index(v: [3]usize) usize {
    return (v[1] * c.CHUNK_SUB_BLOCKS + v[2]) * c.CHUNK_SUB_BLOCKS + v[0];
}

pub fn update(self: *Self) !void {
    self.cmesh.clear();
    try self.cmesh.vertices.appendSlice(util.allocator(), &[_]ChunkMesh.Vertex{
        ChunkMesh.Vertex{
            .vert = [_]f32{ -1, 1, 0 },
        },
        ChunkMesh.Vertex{
            .vert = [_]f32{ -1, -1, 0 },
        },
        ChunkMesh.Vertex{
            .vert = [_]f32{ 1, -1, 0 },
        },
        ChunkMesh.Vertex{
            .vert = [_]f32{ 1, 1, 0 },
        },
    });
    try self.cmesh.indices.appendSlice(util.allocator(), &[_]u32{ 0, 1, 2, 2, 3, 0 });
    self.cmesh.update_chunk_data(@ptrCast(@alignCast(self.subvoxels.items)));
    self.cmesh.update();
}

pub fn draw(self: *Self) void {
    self.cmesh.draw();
}
