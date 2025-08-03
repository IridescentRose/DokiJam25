const std = @import("std");
const State = @import("../../core/State.zig");
const input = @import("../../core/input.zig");
const gfx = @import("../../gfx/gfx.zig");
const util = @import("../../core/util.zig");
const Self = @This();
const Voxel = @import("..//voxel.zig");

tex: gfx.texture.Texture,
angle: f32,
voxel: Voxel,
offset: u32,

fn init(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    self.tex = try gfx.texture.load_image_from_file("fire_0.png");
    self.angle = 0;
    self.offset = 0;
    self.voxel = Voxel.init(self.tex);
}

fn deinit(ctx: *anyopaque) void {
    var self = util.ctx_to_self(Self, ctx);
    self.voxel.deinit();
}

fn update(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    self.angle += 0.25;
    self.offset += 1;
}

fn draw(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    gfx.clear_color(0.1, 0.1, 0.1, 1);
    gfx.clear();

    const translation1 = gfx.zm.translation(@floatFromInt(@divTrunc(-self.tex.width, 2)), @floatFromInt(@divTrunc(-self.tex.width, 2)), @floatFromInt(@divTrunc(-self.tex.width, 2)));
    const rotation = gfx.zm.mul(gfx.zm.rotationX(std.math.degreesToRadians(-90.0)), gfx.zm.rotationY(std.math.degreesToRadians(self.angle)));
    const scaling = gfx.zm.scaling(1.0 / 32.0, 1.0 / 32.0, 1.0 / 32.0);
    const translation = gfx.zm.translation(0, 0, -1.0);
    const model = gfx.zm.mul(gfx.zm.mul(gfx.zm.mul(translation1, scaling), rotation), translation);
    gfx.shader.set_model(model);
    gfx.shader.set_has_tex(false);

    try self.voxel.build(self.offset);

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
