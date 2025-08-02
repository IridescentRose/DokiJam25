const std = @import("std");
const State = @import("../core/State.zig");
const input = @import("../core/input.zig");
const window = @import("../window.zig");

const Self = @This();

fn key_down(ctx: *anyopaque, down: bool) void {
    _ = ctx;
    std.debug.print("ESCAPE KEY {s}\n", .{if (down) "DOWN" else "UP"});
}
fn mouse_down(ctx: *anyopaque, down: bool) void {
    _ = ctx;
    std.debug.print("MOUSE LEFT CLICK {s}\n", .{if (down) "DOWN" else "UP"});
}

fn init(ctx: *anyopaque) anyerror!void {
    try input.register_key_callback(.escape, .{
        .ctx = ctx,
        .cb = key_down,
    });
    try input.register_mouse_callback(.left, .{
        .ctx = ctx,
        .cb = mouse_down,
    });
}

fn deinit(ctx: *anyopaque) void {
    _ = ctx;
}

fn update(ctx: *anyopaque) anyerror!void {
    _ = ctx;
    const pos = input.get_mouse_position();
    std.debug.print("MOUSE POS: {any}\n", .{pos});
}

fn draw(ctx: *anyopaque) anyerror!void {
    _ = ctx;
    const surface = try window.surface();
    try surface.fillRect(null, surface.mapRgb(128, 30, 255));

    try window.draw();
}

pub fn state(self: *Self) State {
    return .{ .ptr = self, .tab = .{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
    } };
}
