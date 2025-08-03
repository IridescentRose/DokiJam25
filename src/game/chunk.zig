const std = @import("std");
const gfx = @import("../gfx/gfx.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");
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
    state: u8,
    flags: AtomFlags,
};

transform: Transform,
subvoxels: std.MultiArrayList(Atom),
mesh: gfx.Mesh,
dirty: bool,
populated: bool,

const Self = @This();

pub fn new(world_pos: [3]f32) !Self {
    var res: Self = .{
        .dirty = true,
        .subvoxels = std.MultiArrayList(Atom){},
        .transform = Transform.new(),
        .populated = false,
        .mesh = try gfx.Mesh.new(),
    };

    res.transform.pos = world_pos;
    res.transform.scale = @splat(1.0 / 16.0);
    res.transform.size = @splat(8.0);
    return res;
}

pub fn deinit(self: *Self) void {
    self.mesh.deinit();
    self.subvoxels.deinit(util.allocator());
}

fn get_index(v: [3]usize) usize {
    return ((v[1] * c.CHUNK_SUB_BLOCKS) + v[2]) * c.CHUNK_SUB_BLOCKS + v[0];
}

fn try_add_face(self: *Self, neighbor_v: [3]usize, v: [3]usize, face: u3) !void {
    const idx = get_index(neighbor_v);
    const block_type: AtomKind = self.subvoxels.items(.material)[idx];

    if (block_type == .Air) {
        try self.add_face(v, face);
    }
}

fn add_face(self: *Self, v: [3]usize, face: u3) !void {
    const idx = get_index(v);
    const val: [3]u8 = self.subvoxels.items(.color)[idx];

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

                const block_type: AtomKind = self.subvoxels.items(.material)[idx];
                if (block_type == .Air)
                    continue;

                // TODO: World lookups

                if (z + 1 < c.CHUNK_SUB_BLOCKS) {
                    try self.try_add_face([_]usize{ x, y, z + 1 }, v, 2);
                } else {
                    try self.add_face(v, 2);
                }

                if (z > 0) {
                    try self.try_add_face([_]usize{ x, y, z - 1 }, v, 3);
                } else {
                    try self.add_face(v, 3);
                }

                if (y + 1 < c.CHUNK_SUB_BLOCKS) {
                    try self.try_add_face([_]usize{ x, y + 1, z }, v, 0);
                } else {
                    try self.add_face(v, 0);
                }

                if (y > 0) {
                    try self.try_add_face([_]usize{ x, y - 1, z }, v, 1);
                } else {
                    try self.add_face(v, 1);
                }

                if (x + 1 < c.CHUNK_SUB_BLOCKS) {
                    try self.try_add_face([_]usize{ x + 1, y, z }, v, 4);
                } else {
                    try self.add_face(v, 4);
                }

                if (x > 0) {
                    try self.try_add_face([_]usize{ x - 1, y, z }, v, 5);
                } else {
                    try self.add_face(v, 5);
                }
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
        gfx.shader.set_model(self.transform.get_matrix());

        self.mesh.draw();
    }
}
