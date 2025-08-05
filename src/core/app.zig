const std = @import("std");
const sdl3 = @import("sdl3");
const State = @import("State.zig");
const sm = @import("statemachine.zig");
const input = @import("input.zig");
const util = @import("util.zig");
const gfx = @import("../gfx/gfx.zig");

pub var running = true;

const init_flags = sdl3.InitFlags{
    .video = true,
    .audio = true,
};

pub fn init(width: u32, height: u32, title: [:0]const u8, state: State) !void {
    util.init();
    input.init();

    try sdl3.init(init_flags);
    try gfx.init(width, height, title);

    try sm.init(state);
}

pub fn deinit() void {
    sm.deinit();

    gfx.deinit();

    sdl3.quit(init_flags);
    sdl3.shutdown();

    input.deinit();
    util.deinit();
}

pub fn event_loop() !void {
    // TODO: Customize?
    // const frame_rate = 60;
    // const frame_time_ns = std.time.ns_per_s / frame_rate;

    // var next_frame_start = std.time.nanoTimestamp() + frame_time_ns;
    while (running) {
        // const now = std.time.nanoTimestamp();

        // if (now < next_frame_start) {
        // Poll for events
        // var new_time = std.time.nanoTimestamp();
        // while (new_time < next_frame_start) {
        while (sdl3.events.poll()) |event| {
            switch (event) {
                .quit, .terminating => running = false,
                .key_down, .key_up => |t| {
                    if (t.scancode != null) {
                        if (input.get_key_callback(t.scancode.?)) |cbd| {
                            cbd.cb(cbd.ctx, t.down);
                        }
                    }
                },
                .mouse_button_down, .mouse_button_up => |t| {
                    if (input.get_mouse_callback(t.button)) |cbd| {
                        cbd.cb(cbd.ctx, t.down);
                    }
                },
                .mouse_motion => |t| {
                    if (input.mouse_relative_handle) |h| {
                        h.cb(h.ctx, t.x_rel, t.y_rel);
                    }
                },
                else => {
                    // std.debug.print("Received unknown event! {any}\n", .{event});
                },
            }
        }

        // new_time = std.time.nanoTimestamp();
        // TODO: Sleep so we don't hang this thread forever? (Within system limitations)
        // }
        // } else {
        // TODO: Make this more serious
        //     std.debug.print("Event handling skipped, running late!\n", .{});
        // }

        // Simulation update w/ input
        try sm.update();

        // Build draw list
        try sm.draw();

        // Commit to GPU and render to screen
        try gfx.finalize();

        // next_frame_start += frame_time_ns;

        // const drift_limit_ns = frame_time_ns * 2;
        // const curr_time = std.time.nanoTimestamp();

        // if (curr_time > next_frame_start + drift_limit_ns) {
        //     next_frame_start = curr_time;
        //     std.debug.print("Fell 2 frames behind!\n", .{});
        // }
    }
}
