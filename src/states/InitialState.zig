const std = @import("std");
const State = @import("../core/State.zig");
const input = @import("../core/input.zig");
const gl = @import("../gfx/gl.zig");

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
    gl.viewport(0, 0, 1280, 720);
    gl.clearColor(1, 1, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

pub fn state(self: *Self) State {
    return .{ .ptr = self, .tab = .{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
    } };
}
