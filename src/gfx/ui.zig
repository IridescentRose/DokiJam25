const std = @import("std");
const assert = std.debug.assert;

pub const Sprite = struct {
    offset: [2]f32,
    extent: [2]f32,
    color: [4]u8,
    tex_id: u32,
};

var initialized: bool = false;
var sprites: std.ArrayList(Sprite) = undefined;

pub fn init() !void {
    assert(!initialized);
    initialized = true;

    sprites = std.ArrayList(Sprite).init(std.heap.page_allocator);

    assert(initialized);
}

pub fn deinit() void {
    assert(initialized);

    sprites.deinit();
    initialized = false;

    assert(!initialized);
}

pub fn add_sprite(sprite: Sprite) !void {
    assert(initialized);

    try sprites.append(sprite);
}

pub fn clear_sprites() void {
    assert(initialized);
    sprites.clear();
}

pub fn update() !void {}

pub fn draw() !void {}
