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
        .mouse_capture = true,
        .open_gl = true,
        .resizable = false,
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
    // OPENGL
    // TODO: Do we want this here?
    _ = sdl3.c.SDL_GL_SwapWindow(window.value);
}

pub fn context() sdl3.c.SDL_GLContext {
    return sdl3.c.SDL_GL_CreateContext(window.value);
}

pub fn set_title(title: [:0]const u8) !void {
    assert(initialized);
    window.setTitle(title);
}

pub fn get_width() !usize {
    return (try window.getSize()).width;
}

pub fn get_height() !usize {
    return (try window.getSize()).height;
}
