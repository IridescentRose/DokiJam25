const std = @import("std");
const app = @import("core/app.zig");
const MenuState = @import("game/states/MenuState.zig");

// Shim
pub fn main() !void {
    var state: MenuState = undefined;

    try app.init(state.state());
    defer app.deinit();

    try app.event_loop();
}
