const std = @import("std");
const app = @import("core/app.zig");
const MenuState = @import("game/states/MenuState.zig");
const GameState = @import("game/states/GameState.zig");

// Shim
pub fn main() !void {
    var state: GameState = undefined;

    try app.init(state.state());
    defer app.deinit();

    try app.event_loop();
}
