const std = @import("std");
const c = @import("../consts.zig");
const State = @import("../../core/State.zig");
const input = @import("../../core/input.zig");
const gfx = @import("../../gfx/gfx.zig");
const util = @import("../../core/util.zig");
const Self = @This();
const Chunk = @import("../chunk.zig");
const Voxel = @import("../voxel.zig");
const Transform = @import("../../gfx/transform.zig");

tex: gfx.texture.Texture,
angle: f32,
voxel: Voxel,
chunk: Chunk,
transform: Transform,

fn init(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    self.tex = try gfx.texture.load_image_from_file("doki.png");
    self.angle = 0;
    self.voxel = Voxel.init(self.tex);
    self.transform = Transform.new();

    self.transform.scale = @splat(1.0 / 20.0);
    self.transform.pos[2] = -1.2;
    self.transform.size = @splat(20.0);

    try self.voxel.build();

    self.chunk = try Chunk.new(@splat(-8));

    var rng = std.Random.DefaultPrng.init(42);

    for (0..c.CHUNK_SUB_BLOCKS) |y| {
        for (0..c.CHUNK_SUB_BLOCKS) |z| {
            for (0..c.CHUNK_SUB_BLOCKS) |x| {
                try self.chunk.subvoxels.append(util.allocator(), .{
                    .flags = undefined,
                    .state = undefined,
                    .material = if (x % 2 == 0 and y % 2 == 0 and z % 2 == 0) .Dirt else .Air,
                    .color = [_]u8{ rng.random().int(u8) % 0xD5, rng.random().int(u8) % 0x8A, 0x00 },
                });
            }
        }
    }

    self.chunk.subvoxels.shrinkAndFree(util.allocator(), self.chunk.subvoxels.len);

    self.chunk.populated = true;
}

fn deinit(ctx: *anyopaque) void {
    var self = util.ctx_to_self(Self, ctx);
    self.voxel.deinit();
    self.chunk.deinit();
}

fn update(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    self.angle += 0.25;

    try self.chunk.update();
}

fn draw(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    gfx.clear_color(0.8, 1.0, 0.8, 1);
    gfx.clear();

    self.transform.rot[1] = self.angle;

    gfx.shader.set_model(self.transform.get_matrix());
    self.voxel.draw();
    self.chunk.draw();
}

pub fn state(self: *Self) State {
    return .{ .ptr = self, .tab = .{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
    } };
}
