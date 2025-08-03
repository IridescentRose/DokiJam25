const std = @import("std");
const State = @import("../core/State.zig");
const input = @import("../core/input.zig");
const gfx = @import("../gfx/gfx.zig");
const util = @import("../core/util.zig");
const Self = @This();

mesh: gfx.Mesh,
tex: gfx.texture.Texture,
angle: f32,

fn init(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    self.mesh = try gfx.Mesh.new();
    self.tex = try gfx.texture.load_image_from_file("dirt.png");
    self.angle = 0;

    try self.mesh.vertices.appendSlice(util.allocator(), &[_]gfx.Mesh.Vertex{
        gfx.Mesh.Vertex{
            .vert = [_]f32{ 0.5, 0.5, 0 },
            .col = [_]u8{ 255, 0, 0, 255 },
            .tex = [_]f32{ 0, 0 },
            .norm = [_]f32{ 0, 0, -1 },
        },
        gfx.Mesh.Vertex{
            .vert = [_]f32{ -0.5, 0.5, 0 },
            .col = [_]u8{ 255, 255, 255, 255 },
            .tex = [_]f32{ 1, 0 },
            .norm = [_]f32{ 0, 0, -1 },
        },
        gfx.Mesh.Vertex{
            .vert = [_]f32{ -0.5, -0.5, 0 },
            .col = [_]u8{ 0, 255, 0, 255 },
            .tex = [_]f32{ 1, 1 },
            .norm = [_]f32{ 0, 0, -1 },
        },
        gfx.Mesh.Vertex{
            .vert = [_]f32{ 0.5, -0.5, 0 },
            .col = [_]u8{ 0, 0, 255, 255 },
            .tex = [_]f32{ 0, 1 },
            .norm = [_]f32{ 0, 0, -1 },
        },
    });

    try self.mesh.indices.appendSlice(util.allocator(), &[_]gfx.Mesh.Index{
        0, 1, 2, 2, 3, 0,
    });

    self.mesh.update();
}

fn deinit(ctx: *anyopaque) void {
    var self = util.ctx_to_self(Self, ctx);
    self.mesh.deinit();
}

fn update(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    self.angle += 1.0;
}

fn draw(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    gfx.clear_color(1, 1, 1, 1);
    gfx.clear();

    const model = gfx.zm.mul(gfx.zm.rotationZ(std.math.degreesToRadians(self.angle)), gfx.zm.translation(0, 0, -1.5));
    gfx.shader.set_model(model);
    gfx.shader.set_has_tex(false);

    self.tex.bind();
    self.mesh.draw();
}

pub fn state(self: *Self) State {
    return .{ .ptr = self, .tab = .{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
    } };
}
