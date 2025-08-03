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

fn try_add_face(self: *Self, face_data: []const gfx.Mesh.Vertex, neighbor_v: [3]usize, v: [3]usize) !void {
    const idx = self.get_index(neighbor_v);
    const val: [4]u8 = std.mem.toBytes(self.texture.data[idx]);

    if (val[3] != 255) {
        try self.add_face(face_data, v);
    }
}

fn add_face(self: *Self, face_data: []const gfx.Mesh.Vertex, v: [3]usize) !void {
    try self.mesh.vertices.appendSlice(util.allocator(), face_data);

    const idx = self.get_index(v);
    const val: [4]u8 = std.mem.toBytes(self.texture.data[idx]);
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

pub fn build(self: *Self) !void {
    _ = self;
    // if (!self.built) {
    //     self.mesh = try gfx.Mesh.new();
    //     self.built = true;
    // } else {
    //     self.mesh.vertices.clearAndFree(util.allocator());
    //     self.mesh.indices.clearAndFree(util.allocator());
    // }

    // self.curr_idx = 0;

    // const width: usize = @intCast(self.texture.width);
    // const height: usize = @intCast(self.texture.height);
    // const layers: usize = @divTrunc(height, width);

    // for (0..layers) |y| {
    //     for (0..width) |z| {
    //         for (0..width) |x| {
    //             const v = [_]usize{ x, y, z };
    //             const idx = self.get_index(v);
    //             const val: [4]u8 = std.mem.toBytes(self.texture.data[idx]);

    //             // If transparent, ignore
    //             if (val[3] != 255)
    //                 continue;

    //             if (z + 1 < width) {
    //                 try self.try_add_face(&c.front_face, [_]usize{ x, y, z + 1 }, v);
    //             } else {
    //                 try self.add_face(&c.front_face, v);
    //             }

    //             if (z > 0) {
    //                 try self.try_add_face(&c.back_face, [_]usize{ x, y, z - 1 }, v);
    //             } else {
    //                 try self.add_face(&c.back_face, v);
    //             }

    //             if (y + 1 < layers) {
    //                 try self.try_add_face(&c.top_face, [_]usize{ x, y + 1, z }, v);
    //             } else {
    //                 try self.add_face(&c.top_face, v);
    //             }

    //             if (y > 0) {
    //                 try self.try_add_face(&c.bot_face, [_]usize{ x, y - 1, z }, v);
    //             } else {
    //                 try self.add_face(&c.bot_face, v);
    //             }

    //             if (x + 1 < width) {
    //                 try self.try_add_face(&c.right_face, [_]usize{ x + 1, y, z }, v);
    //             } else {
    //                 try self.add_face(&c.right_face, v);
    //             }

    //             if (x > 0) {
    //                 try self.try_add_face(&c.left_face, [_]usize{ x - 1, y, z }, v);
    //             } else {
    //                 try self.add_face(&c.left_face, v);
    //             }
    //         }
    //     }
    // }

    // self.mesh.update();
}

pub fn draw(self: *Self) void {
    if (self.built) {
        self.mesh.draw();
    }
}
