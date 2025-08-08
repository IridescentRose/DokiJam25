const std = @import("std");
const gfx = @import("../../gfx/gfx.zig");

const State = @import("../../core/State.zig");
const Self = @This();

fn init(ctx: *anyopaque) anyerror!void {
    _ = ctx;
}

fn deinit(ctx: *anyopaque) void {
    _ = ctx;
}

fn update(ctx: *anyopaque) anyerror!void {
    _ = ctx;
}

fn draw(ctx: *anyopaque) anyerror!void {
    _ = ctx;
    gfx.clear_color(130.0 / 255.0, 202.0 / 255.0, 255.0 / 255.0, 1);
    gfx.clear();
}

pub fn state(self: *Self) State {
    return .{ .ptr = self, .tab = .{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
    } };
}
