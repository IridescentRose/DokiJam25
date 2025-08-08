const std = @import("std");
const app = @import("core/app.zig");
const InitialState = @import("game/states/InitialState.zig");

// Shim
pub fn main() !void {
    var state: InitialState = undefined;

    try app.init(state.state());
    defer app.deinit();

    try app.event_loop();
}
