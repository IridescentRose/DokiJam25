const std = @import("std");
const gfx = @import("../gfx/gfx.zig");
const util = @import("../core/util.zig");

const Self = @This();

const top_face = [_]gfx.Mesh.Vertex{
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
const bot_face = [_]gfx.Mesh.Vertex{
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
const front_face = [_]gfx.Mesh.Vertex{
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
const back_face = [_]gfx.Mesh.Vertex{
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
const right_face = [_]gfx.Mesh.Vertex{
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
const left_face = [_]gfx.Mesh.Vertex{
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
    self.mesh.deinit();
}

fn get_index(self: *Self, v: [3]usize, offset: usize) usize {
    const width: usize = @intCast(self.texture.width);
    return ((((v[1] + offset) % 32) * width) + v[2]) * width + v[0];
}

fn try_add_face(self: *Self, face_data: []const gfx.Mesh.Vertex, neighbor_v: [3]usize, v: [3]usize, offset: usize) !void {
    const idx = self.get_index(neighbor_v, offset);
    const val: [4]u8 = std.mem.toBytes(self.texture.data[idx]);

    if (val[3] != 255) {
        try self.add_face(face_data, v, offset);
    }
}

fn add_face(self: *Self, face_data: []const gfx.Mesh.Vertex, v: [3]usize, offset: usize) !void {
    try self.mesh.vertices.appendSlice(util.allocator(), face_data);

    const idx = self.get_index(v, offset);
    const val: [4]u8 = std.mem.toBytes(self.texture.data[idx]);
    for (0..4) |i| {
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].vert[0] += @floatFromInt(v[0]);
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].vert[1] += @floatFromInt(v[1]);
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].vert[2] += @floatFromInt(v[2]);
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].col[0] = val[0];
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].col[1] = val[1];
        self.mesh.vertices.items[self.mesh.vertices.items.len - i - 1].col[2] = val[2];
    }

    try self.mesh.indices.appendSlice(util.allocator(), &[_]u32{
        self.curr_idx + 0, self.curr_idx + 1, self.curr_idx + 2, self.curr_idx + 2, self.curr_idx + 3, self.curr_idx + 0,
    });

    self.curr_idx += 4;
}

pub fn build(self: *Self, offset: u32) !void {
    if (!self.built) {
        self.mesh = try gfx.Mesh.new();
        self.built = true;
    } else {
        self.mesh.vertices.clearAndFree(util.allocator());
        self.mesh.indices.clearAndFree(util.allocator());
    }

    self.curr_idx = 0;

    const width: usize = @intCast(self.texture.width);
    const height: usize = @intCast(self.texture.height);
    const layers: usize = @divTrunc(height, width);

    for (0..layers) |y| {
        for (0..width) |z| {
            for (0..width) |x| {
                const v = [_]usize{ x, y, z };
                const idx = self.get_index(v, offset);
                const val: [4]u8 = std.mem.toBytes(self.texture.data[idx]);

                // If transparent, ignore
                if (val[3] != 255)
                    continue;

                if (v[2] + 1 < width) {
                    try self.try_add_face(&front_face, [_]usize{ v[0], v[1], v[2] + 1 }, v, offset);
                } else {
                    try self.add_face(&front_face, v, offset);
                }

                if (v[2] > 0) {
                    try self.try_add_face(&back_face, [_]usize{ v[0], v[1], v[2] - 1 }, v, offset);
                } else {
                    try self.add_face(&back_face, v, offset);
                }

                if (v[1] + 1 < layers) {
                    try self.try_add_face(&top_face, [_]usize{ v[0], v[1] + 1, v[2] }, v, offset);
                } else {
                    try self.add_face(&top_face, v, offset);
                }

                if (v[1] > 0) {
                    try self.try_add_face(&bot_face, [_]usize{ v[0], v[1] - 1, v[2] }, v, offset);
                } else {
                    try self.add_face(&bot_face, v, offset);
                }

                if (v[0] + 1 < width) {
                    try self.try_add_face(&right_face, [_]usize{ v[0] + 1, v[1], v[2] }, v, offset);
                } else {
                    try self.add_face(&right_face, v, offset);
                }

                if (v[0] > 0) {
                    try self.try_add_face(&left_face, [_]usize{ v[0] - 1, v[1], v[2] }, v, offset);
                } else {
                    try self.add_face(&left_face, v, offset);
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
