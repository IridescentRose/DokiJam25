const std = @import("std");
const gfx = @import("../gfx/gfx.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");

const Self = @This();

texture: gfx.texture.Texture,
mesh: gfx.Mesh,
built: bool,
curr_idx: u32,

pub fn init(tex: gfx.texture.Texture) Self {
    return .{
        .texture = tex,
        .mesh = undefined,
        .built = false,
        .curr_idx = 0,
    };
}

pub fn deinit(self: *Self) void {
    if (self.built) {
        self.mesh.deinit();
    }
}

fn get_index(self: *Self, v: [3]usize) usize {
    const width: usize = @intCast(self.texture.width);
    return ((v[1] * width) + v[2]) * width + v[0];
}

fn try_add_face(self: *Self, neighbor_v: [3]usize, v: [3]usize, face: u3) !void {
    const idx = self.get_index(neighbor_v);
    const val: [4]u8 = std.mem.toBytes(self.texture.data[idx]);

    if (val[3] != 255) {
        try self.add_face(v, face);
    }
}

fn add_face(self: *Self, v: [3]usize, face: u3) !void {
    const idx = self.get_index(v);
    const val: [4]u8 = std.mem.toBytes(self.texture.data[idx]);

    var instance = gfx.Mesh.Instance{
        .col = undefined,
        .vert = .{
            .x = @intCast(v[0]),
            .y = @intCast(v[1]),
            .z = @intCast(v[2]),
            .face = face,
        },
    };
    instance.col[0] = val[0];
    instance.col[1] = val[1];
    instance.col[2] = val[2];

    try self.mesh.instances.append(util.allocator(), instance);
}

pub fn build(self: *Self) !void {
    if (!self.built) {
        self.mesh = try gfx.Mesh.new();
        self.built = true;
    } else {
        self.mesh.clear();
    }

    self.mesh.clear();

    try self.mesh.vertices.appendSlice(util.allocator(), &c.top_face);
    try self.mesh.indices.appendSlice(util.allocator(), &[_]u32{ 0, 1, 2, 2, 3, 0 });

    const width: usize = @intCast(self.texture.width);
    const height: usize = @intCast(self.texture.height);
    const layers: usize = @divTrunc(height, width);

    for (0..layers) |y| {
        for (0..width) |z| {
            for (0..width) |x| {
                const v = [_]usize{ x, y, z };
                const idx = self.get_index(v);
                const val: [4]u8 = std.mem.toBytes(self.texture.data[idx]);

                // If transparent, ignore
                if (val[3] != 255)
                    continue;

                if (z + 1 < width) {
                    try self.try_add_face([_]usize{ x, y, z + 1 }, v, 2);
                } else {
                    try self.add_face(v, 2);
                }

                if (z > 0) {
                    try self.try_add_face([_]usize{ x, y, z - 1 }, v, 3);
                } else {
                    try self.add_face(v, 3);
                }

                if (y + 1 < layers) {
                    try self.try_add_face([_]usize{ x, y + 1, z }, v, 0);
                } else {
                    try self.add_face(v, 0);
                }

                if (y > 0) {
                    try self.try_add_face([_]usize{ x, y - 1, z }, v, 1);
                } else {
                    try self.add_face(v, 1);
                }

                if (x + 1 < width) {
                    try self.try_add_face([_]usize{ x + 1, y, z }, v, 5);
                } else {
                    try self.add_face(v, 5);
                }

                if (x > 0) {
                    try self.try_add_face([_]usize{ x - 1, y, z }, v, 4);
                } else {
                    try self.add_face(v, 4);
                }
            }
        }
    }

    self.mesh.update();
}

pub fn draw(self: *Self) void {
    if (self.built) {
        self.mesh.draw();
    }
}
