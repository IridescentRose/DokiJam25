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

const Config = struct {
    width: u32,
    height: u32,
    vsync: bool,
    fps: u32,
};

var config = Config{
    .width = 1280,
    .height = 720,
    .vsync = true,
    .fps = 60,
};

fn parse_config() !void {
    var file = try std.fs.cwd().openFile("config.txt", .{});
    defer file.close();

    const buf = try file.readToEndAlloc(util.allocator(), 1024);
    defer util.allocator().free(buf);

    var lines = std.mem.splitSequence(u8, buf, "\r\n");
    var curr_line = lines.first();

    while (true) {
        var parts = std.mem.splitSequence(u8, curr_line, "=");
        const key = std.mem.trim(u8, parts.first(), " \t");
        if (parts.next()) |value| {
            const intval = try std.fmt.parseInt(u32, value, 10);
            if (std.mem.eql(u8, key, "vsync")) {
                config.vsync = intval != 0;
            } else if (std.mem.eql(u8, key, "fps")) {
                config.fps = intval;
            } else if (std.mem.eql(u8, key, "width")) {
                config.width = intval;
            } else if (std.mem.eql(u8, key, "height")) {
                config.height = intval;
            }
        }

        // Move to the next line
        if (lines.next()) |next_line| {
            curr_line = next_line;
        } else {
            break; // No more lines to process
        }
    }
}

pub fn init(state: State) !void {
    util.init();

    parse_config() catch |err| {
        std.debug.print("Failed to parse config: {}\n", .{err});
        return err;
    };

    try sdl3.init(init_flags);
    input.init();
    try gfx.init(config.width, config.height, "DOKIJAM25!");

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

fn handle_updates() void {
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
            .mouse_wheel => |t| {
                input.scroll_pos -= @intFromFloat(t.scroll_y);

                const SCROLL_MAX = 10; // Arbitrary limit for scroll position
                const SCROLL_MIN = -5; // Arbitrary limit for scroll position
                input.scroll_pos = std.math.clamp(input.scroll_pos, SCROLL_MIN, SCROLL_MAX);
            },
            else => {
                // std.debug.print("Received unknown event! {any}\n", .{event});
            },
        }
    }
}

pub fn event_loop() !void {
    const frame_rate = config.fps;
    const frame_time_ns = std.time.ns_per_s / frame_rate;

    var next_frame_start = std.time.nanoTimestamp() + frame_time_ns;

    var fps: usize = 0;
    var second_timer = std.time.nanoTimestamp() + std.time.ns_per_s;

    while (running) {
        const now = std.time.nanoTimestamp();

        handle_updates();

        if (std.time.nanoTimestamp() > second_timer) {
            std.debug.print("FPS: {}\n", .{fps});
            fps = 0;
            second_timer = std.time.nanoTimestamp() + std.time.ns_per_s;
        }
        fps += 1;

        if (now < next_frame_start and config.vsync) {
            // Poll for events
            var new_time = std.time.nanoTimestamp();
            while (new_time < next_frame_start) {
                new_time = std.time.nanoTimestamp();
                handle_updates();

                // This doesn't guarantee a stable frame rate, but it helps prevent busy-waiting
                std.Thread.sleep(std.time.ns_per_ms);
            }
        }

        // Simulation update w/ input
        try sm.update();

        // Build draw list
        try sm.draw();

        // Commit to GPU and render to screen
        try gfx.finalize();

        next_frame_start += frame_time_ns;

        const drift_limit_ns = frame_time_ns * 2;
        const curr_time = std.time.nanoTimestamp();

        if (curr_time > next_frame_start + drift_limit_ns) {
            next_frame_start = curr_time;
            std.debug.print("Fell 2 frames behind!\n", .{});
        }
    }
}
