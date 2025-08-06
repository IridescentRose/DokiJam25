const std = @import("std");
const gfx = @import("../../gfx/gfx.zig");
const world = @import("../world.zig");
const zm = @import("zmath");

const State = @import("../../core/State.zig");
const Self = @This();

fn init(ctx: *anyopaque) anyerror!void {
    _ = ctx;
    try world.init(42);
}

fn deinit(ctx: *anyopaque) void {
    _ = ctx;
    world.deinit();
}

fn update(ctx: *anyopaque) anyerror!void {
    _ = ctx;
    try world.update();
}

fn draw(ctx: *anyopaque) anyerror!void {
    _ = ctx;
    gfx.clear_color(130.0 / 255.0, 202.0 / 255.0, 255.0 / 255.0, 1);
    gfx.clear();

    world.draw();

    gfx.shader.use_comp_shader();
    gfx.shader.set_comp_resolution();
    gfx.shader.set_comp_inv_proj(zm.inverse(world.player.camera.get_projection_matrix()));
    gfx.shader.set_comp_inv_view(zm.inverse(world.player.camera.get_view_matrix()));
    gfx.shader.set_comp_sun_dir(zm.Vec{ 0.72, 1, 0, 1 });
    gfx.shader.set_comp_sun_color(zm.Vec{ 0.72, 0.58, 0.48, 1 });
    gfx.shader.set_comp_ambient_color(zm.Vec{ 0.063 * 3, 0.067 * 3, 0.073 * 3, 1 });
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
