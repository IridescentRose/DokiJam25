const std = @import("std");
const gfx = @import("../../gfx/gfx.zig");
const world = @import("../world.zig");

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
    gfx.clear_color(128.0 / 255.0, 143.0 / 255.0, 204.0 / 255.0, 1);
    gfx.clear();

    world.draw();
}

pub fn state(self: *Self) State {
    return .{ .ptr = self, .tab = .{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
    } };
}
