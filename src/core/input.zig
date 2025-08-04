const std = @import("std");
const assert = std.debug.assert;
const util = @import("util.zig");
const sdl3 = @import("sdl3");

var initialized = false;

pub const InputCallbackFn = *const fn (ctx: *anyopaque, down: bool) void;

pub const InputCallback = struct {
    cb: InputCallbackFn,
    ctx: *anyopaque,
};

const KeyCBMap = std.AutoArrayHashMap(sdl3.Scancode, InputCallback);
const MouseCBMap = std.AutoArrayHashMap(sdl3.mouse.Button, InputCallback);
const MousePosition = @Vector(2, f32);

var keyMap: KeyCBMap = undefined;
var mbMap: MouseCBMap = undefined;

const MouseRelativeFn = *const fn (ctx: *anyopaque, dx: f32, dy: f32) void;

pub const MouseRelativeCallback = struct {
    cb: MouseRelativeFn,
    ctx: *anyopaque,
};

pub var mouse_relative_handle: ?MouseRelativeCallback = null;

pub fn init() void {
    assert(!initialized);

    keyMap = KeyCBMap.init(util.allocator());
    mbMap = MouseCBMap.init(util.allocator());

    initialized = true;
    assert(initialized);
}

pub fn get_mouse_position() MousePosition {
    return MousePosition{ sdl3.mouse.getState().x, sdl3.mouse.getState().y };
}

pub fn register_key_callback(key: sdl3.Scancode, cb: InputCallback) !void {
    assert(initialized);

    try keyMap.put(key, cb);
}

pub fn get_key_callback(key: sdl3.Scancode) ?InputCallback {
    return keyMap.get(key);
}

pub fn unregister_key_callback(key: sdl3.Scancode) void {
    _ = keyMap.orderedRemove(key);
}

pub fn register_mouse_callback(mb: sdl3.mouse.Button, cb: InputCallback) !void {
    assert(initialized);

    try mbMap.put(mb, cb);
}

pub fn get_mouse_callback(mb: sdl3.mouse.Button) ?InputCallback {
    return mbMap.get(mb);
}

pub fn unregister_mouse_callback(mb: sdl3.mouse.Button) void {
    _ = mbMap.orderedRemove(mb);
}

pub fn deinit() void {
    assert(initialized);

    keyMap.deinit();
    mbMap.deinit();

    initialized = false;
    assert(!initialized);
}
