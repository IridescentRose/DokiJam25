const std = @import("std");
const gfx = @import("../../gfx/gfx.zig");
const world = @import("../world.zig");
const zm = @import("zmath");

const State = @import("../../core/State.zig");
const Self = @This();

fn init(ctx: *anyopaque) anyerror!void {
    _ = ctx;
    gfx.set_deferred(true);
    try world.init(42);
}

fn deinit(ctx: *anyopaque) void {
    _ = ctx;
    gfx.set_deferred(false);
    world.deinit();
}

fn update(ctx: *anyopaque) anyerror!void {
    _ = ctx;
    try world.update();
}

var frame: u32 = 0;
var t: f32 = 0.0;
fn draw(ctx: *anyopaque) anyerror!void {
    _ = ctx;
    gfx.clear_color(0, 0, 0, 1);
    gfx.clear();

    world.draw();

    t += 0.0001;
    frame += 1;

    gfx.shader.use_comp_shader();
    gfx.shader.set_comp_resolution();
    gfx.shader.set_comp_inv_proj(zm.inverse(world.player.camera.get_projection_matrix()));
    gfx.shader.set_comp_inv_view(zm.inverse(world.player.camera.get_view_matrix()));
    gfx.shader.set_comp_time(t);
    gfx.shader.set_comp_frame(@intCast(frame));
    gfx.shader.set_comp_fog_color(zm.Vec{ 0.5, 0.6, 0.7, 1 });
    gfx.shader.set_comp_fog_density(0.1);

    gfx.shader.set_comp_camera_pos(zm.Vec{ world.player.camera.target[0], world.player.camera.target[1], world.player.camera.target[2], 1.0 });
}

pub fn state(self: *Self) State {
    return .{ .ptr = self, .tab = .{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
    } };
}
