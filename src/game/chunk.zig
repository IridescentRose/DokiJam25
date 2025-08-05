const std = @import("std");
const gfx = @import("../gfx/gfx.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");
const world = @import("world.zig");
const Transform = @import("../gfx/transform.zig");

pub const AtomKind = enum(u8) {
    Air,
    Dirt,
    Stone,
};

pub const AtomFlags = packed struct(u8) {
    reserved: u8,
};

pub const Atom = struct {
    material: AtomKind,
    color: [3]u8,
};

transform: Transform,
subvoxels: std.ArrayList(Atom),
mesh: gfx.Mesh,
dirty: bool,
populated: bool,
coord: [3]isize,

const Self = @This();

pub fn new(world_pos: [3]f32, world_coord: [3]isize) !Self {
    var res: Self = .{
        .dirty = true,
        .subvoxels = std.ArrayList(Atom).init(util.allocator()),
        .transform = Transform.new(),
        .populated = false,
        .mesh = try gfx.Mesh.new(),
        .coord = world_coord,
    };

    try res.subvoxels.resize(c.CHUNK_SUBVOXEL_SIZE);
    @memset(res.subvoxels.items, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });

    res.transform.pos = world_pos;
    res.transform.scale = @splat(1.0 / @as(f32, @floatFromInt(c.SUB_BLOCKS_PER_BLOCK)));
    res.transform.size = @splat(0);
    return res;
}

pub fn deinit(self: *Self) void {
    self.mesh.deinit();
    self.subvoxels.deinit();
}

pub fn get_block_index(v: [3]usize) usize {
    return (((v[1] * c.CHUNK_BLOCKS) + v[2]) * c.CHUNK_BLOCKS + v[0]) * c.SUBVOXEL_SIZE;
}

pub fn get_sub_block_index(v: [3]usize) usize {
    return ((v[1] * c.SUB_BLOCKS_PER_BLOCK) + v[2]) * c.SUB_BLOCKS_PER_BLOCK + v[0];
}

// Assumes a sub-block coordinate
pub fn get_index(v: [3]usize) usize {
    const block_coord = [_]usize{
        @intCast(@divFloor(v[0], c.SUB_BLOCKS_PER_BLOCK)),
        @intCast(@divFloor(v[1], c.SUB_BLOCKS_PER_BLOCK)),
        @intCast(@divFloor(v[2], c.SUB_BLOCKS_PER_BLOCK)),
    };

    // std.debug.print("Block coord: {any}, {any}, {any}\n", .{ block_coord[0], block_coord[1], block_coord[2] });

    const block_idx = get_block_index(block_coord);

    const sub_coord = [_]usize{
        @intCast(@mod(v[0], c.SUB_BLOCKS_PER_BLOCK)),
        @intCast(@mod(v[1], c.SUB_BLOCKS_PER_BLOCK)),
        @intCast(@mod(v[2], c.SUB_BLOCKS_PER_BLOCK)),
    };

    const sub_idx = get_sub_block_index(sub_coord);

    return block_idx + sub_idx;
}

fn try_add_face(self: *Self, neighbor_v: [3]isize, v: [3]usize, face: u3) !void {
    const block_type: AtomKind = blk: {
        if (neighbor_v[0] == -1 or neighbor_v[0] == c.CHUNK_SUB_BLOCKS or neighbor_v[1] == -1 or neighbor_v[1] == c.CHUNK_SUB_BLOCKS or neighbor_v[2] == -1 or neighbor_v[2] == c.CHUNK_SUB_BLOCKS) {
            const world_coord = [_]isize{
                self.coord[0] * c.CHUNK_SUB_BLOCKS + neighbor_v[0],
                self.coord[1] * c.CHUNK_SUB_BLOCKS + neighbor_v[1],
                self.coord[2] * c.CHUNK_SUB_BLOCKS + neighbor_v[2],
            };

            break :blk world.get_voxel(world_coord);
        } else {
            const idx = get_index([_]usize{ @intCast(neighbor_v[0]), @intCast(neighbor_v[1]), @intCast(neighbor_v[2]) });
            break :blk self.subvoxels.items[idx].material;
        }
    };

    if (block_type == .Air) {
        try self.add_face(v, face);
    }
}

fn add_face(self: *Self, v: [3]usize, face: u3) !void {
    const idx = get_index(v);
    const val: [3]u8 = self.subvoxels.items[idx].color;

    try self.mesh.instances.append(util.allocator(), .{ .col = val, .vert = .{
        .x = @intCast(v[0]),
        .y = @intCast(v[1]),
        .z = @intCast(v[2]),
        .face = face,
    } });
}

pub fn update(self: *Self) !void {
    if (!self.dirty)
        return;

    if (!self.populated)
        return;
    const before = std.time.nanoTimestamp();

    self.mesh.clear();

    try self.mesh.vertices.appendSlice(util.allocator(), &c.top_face);
    try self.mesh.indices.appendSlice(util.allocator(), &[_]u32{ 0, 1, 2, 2, 3, 0 });

    for (0..c.CHUNK_SUB_BLOCKS) |y| {
        for (0..c.CHUNK_SUB_BLOCKS) |z| {
            for (0..c.CHUNK_SUB_BLOCKS) |x| {
                const v = [_]usize{ x, y, z };
                const idx = get_index(v);

                const block_type: AtomKind = self.subvoxels.items[idx].material;
                if (block_type == .Air)
                    continue;

                // TODO: World lookups

                const iv = [_]isize{ @intCast(x), @intCast(y), @intCast(z) };

                try self.try_add_face([_]isize{ iv[0], iv[1], iv[2] + 1 }, v, 2);
                try self.try_add_face([_]isize{ iv[0], iv[1], iv[2] - 1 }, v, 3);
                try self.try_add_face([_]isize{ iv[0], iv[1] + 1, iv[2] }, v, 0);
                try self.try_add_face([_]isize{ iv[0], iv[1] - 1, iv[2] }, v, 1);
                try self.try_add_face([_]isize{ iv[0] + 1, iv[1], iv[2] }, v, 5);
                try self.try_add_face([_]isize{ iv[0] - 1, iv[1], iv[2] }, v, 4);
            }
        }
    }

    // Fix overalloc
    self.mesh.vertices.shrinkAndFree(util.allocator(), self.mesh.vertices.items.len);
    self.mesh.indices.shrinkAndFree(util.allocator(), self.mesh.indices.items.len);

    self.dirty = false;
    self.mesh.update();

    const after = std.time.nanoTimestamp();
    std.debug.print("Built chunk in {}us!\n", .{@divTrunc(after - before, std.time.ns_per_us)});
}

pub fn draw(self: *Self) void {
    if (self.mesh.indices.items.len != 0 and self.populated) {
        // self.transform.rot[1] += 0.1;
        gfx.shader.set_model(self.transform.get_matrix());

        self.mesh.draw();
    }
}
