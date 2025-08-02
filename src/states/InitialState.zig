const std = @import("std");
const State = @import("../core/State.zig");
const input = @import("../core/input.zig");
const gfx = @import("../gfx/gfx.zig");

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
    gfx.clear_color(1, 1, 1, 1);
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
