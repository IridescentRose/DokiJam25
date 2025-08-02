const sdl3 = @import("sdl3");
const std = @import("std");
const assert = std.debug.assert;

pub var window: sdl3.video.Window = undefined;
var initialized = false;

pub fn init(width: u32, height: u32, title: [:0]const u8) !void {
    assert(!initialized);

    window = try sdl3.video.Window.init(title, width, height, .{
        .input_focus = true,
        .keyboard_grabbed = true,
        .resizable = true,
        .mouse_capture = true,
    });

    initialized = true;
    assert(initialized);
}

pub fn deinit() void {
    assert(initialized);

    window.deinit();
    initialized = false;
    assert(!initialized);
}

pub fn draw() !void {
    assert(initialized);
    try window.updateSurface();
}

pub fn surface() !sdl3.surface.Surface {
    assert(initialized);
    return window.getSurface();
}

pub fn set_title(title: [:0]const u8) !void {
    assert(initialized);
    window.setTitle(title);
}
