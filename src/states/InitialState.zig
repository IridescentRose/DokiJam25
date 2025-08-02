const State = @import("../State.zig");
const window = @import("../window.zig");

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
