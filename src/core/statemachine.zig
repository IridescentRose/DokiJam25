const std = @import("std");
const assert = std.debug.assert;

const State = @import("State.zig");

var initialized: bool = false;
var curr_state: State = undefined;

pub fn init(state: State) anyerror!void {
    assert(!initialized);

    curr_state = state;
    try curr_state.init();

    initialized = true;
    assert(initialized);
}

pub fn deinit() void {
    assert(initialized);

    curr_state.deinit();

    initialized = false;
    assert(!initialized);
}

pub fn transition(state: State) anyerror!void {
    assert(initialized);

    curr_state.deinit();
    curr_state = state;
    try curr_state.init();
}

pub fn update() anyerror!void {
    try curr_state.update();
}

pub fn draw(shadow: bool) anyerror!void {
    try curr_state.draw(shadow);
}
