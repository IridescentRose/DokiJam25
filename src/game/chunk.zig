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
curr_idx: u32,

const Self = @This();

pub fn new(world_pos: [3]f32) !Self {
    var res: Self = .{
        .dirty = true,
        .subvoxels = std.MultiArrayList(Atom){},
        .transform = Transform.new(),
        .populated = false,
        .mesh = try gfx.Mesh.new(),
        .curr_idx = 0,
    };

    res.transform.pos = world_pos;
    res.transform.scale = @splat(1.0 / 16.0);
    res.transform.size = @splat(16.0);
    return res;
}

pub fn deinit(self: *Self) void {
    self.mesh.deinit();
    self.subvoxels.deinit(util.allocator());
}

fn get_index(v: [3]usize) usize {
    return ((v[1] * c.CHUNK_SUB_BLOCKS) + v[2]) * c.CHUNK_SUB_BLOCKS + v[0];
}

fn try_add_face(self: *Self, face_data: []const gfx.Mesh.Vertex, neighbor_v: [3]usize, v: [3]usize) !void {
    const idx = get_index(neighbor_v);
    const block_type: AtomKind = self.subvoxels.items(.material)[idx];

    if (block_type == .Air) {
        try self.add_face(face_data, v);
    }
}

fn add_face(self: *Self, face_data: []const gfx.Mesh.Vertex, v: [3]usize) !void {
    try self.mesh.vertices.appendSlice(util.allocator(), face_data);

    const idx = get_index(v);
    const val: [3]u8 = self.subvoxels.items(.color)[idx];

    for (0..4) |i| {
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].vert.x += @intCast(v[0]);
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].vert.y += @intCast(v[1]);
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].vert.z += @intCast(v[2]);
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].col[0] = val[0];
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].col[1] = val[1];
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].col[2] = val[2];
    }

    try self.mesh.indices.appendSlice(util.allocator(), &[_]u32{
        self.curr_idx + 0, self.curr_idx + 1, self.curr_idx + 2, self.curr_idx + 2, self.curr_idx + 3, self.curr_idx + 0,
    });

    self.curr_idx += 4;
}

pub fn update(self: *Self) !void {
    if (!self.dirty)
        return;

    if (!self.populated)
        return;
    const before = std.time.nanoTimestamp();

    if (self.mesh.indices.items.len != 0) {
        self.mesh.indices.clearAndFree(util.allocator());
        self.mesh.vertices.clearAndFree(util.allocator());
    }

    self.curr_idx = 0;

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
                    try self.try_add_face(&c.front_face, [_]usize{ x, y, z + 1 }, v);
                } else {
                    try self.add_face(&c.front_face, v);
                }

                if (z > 0) {
                    try self.try_add_face(&c.back_face, [_]usize{ x, y, z - 1 }, v);
                } else {
                    try self.add_face(&c.back_face, v);
                }

                if (y + 1 < c.CHUNK_SUB_BLOCKS) {
                    try self.try_add_face(&c.top_face, [_]usize{ x, y + 1, z }, v);
                } else {
                    try self.add_face(&c.top_face, v);
                }

                if (y > 0) {
                    try self.try_add_face(&c.bot_face, [_]usize{ x, y - 1, z }, v);
                } else {
                    try self.add_face(&c.bot_face, v);
                }

                if (x + 1 < c.CHUNK_SUB_BLOCKS) {
                    try self.try_add_face(&c.right_face, [_]usize{ x + 1, y, z }, v);
                } else {
                    try self.add_face(&c.right_face, v);
                }

                if (x > 0) {
                    try self.try_add_face(&c.left_face, [_]usize{ x - 1, y, z }, v);
                } else {
                    try self.add_face(&c.left_face, v);
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
