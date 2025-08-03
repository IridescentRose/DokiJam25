const std = @import("std");
const State = @import("../../core/State.zig");
const input = @import("../../core/input.zig");
const gfx = @import("../../gfx/gfx.zig");
const util = @import("../../core/util.zig");
const Self = @This();
const Voxel = @import("../voxel.zig");
const Transform = @import("../../gfx/transform.zig");

tex: gfx.texture.Texture,
angle: f32,
voxel: Voxel,
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
}

fn deinit(ctx: *anyopaque) void {
    var self = util.ctx_to_self(Self, ctx);
    self.voxel.deinit();
}

fn update(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    self.angle += 0.25;
}

fn draw(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    gfx.clear_color(0.8, 0.8, 0.8, 1);
    gfx.clear();

    self.transform.rot[1] = self.angle;

    gfx.shader.set_model(self.transform.get_matrix());
    gfx.shader.set_has_tex(false);

    self.tex.bind();
    self.voxel.draw();
}

pub fn state(self: *Self) State {
    return .{ .ptr = self, .tab = .{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
    } };
}
