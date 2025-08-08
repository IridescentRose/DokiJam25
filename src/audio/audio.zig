const std = @import("std");
const assert = std.debug.assert;
const zaudio = @import("zaudio");
const util = @import("../core/util.zig");

var initialized: bool = false;

var engine: *zaudio.Engine = undefined;
pub const Clip = struct {
    sound: *zaudio.Sound,

    pub fn load_from_file(path: [:0]const u8, stream: bool, spatial: bool) !Clip {
        return Clip{
            .sound = try engine.createSoundFromFile(path, .{ .flags = .{
                .stream = stream,
                .no_spatialization = !spatial,
            } }),
        };
    }

    pub fn deinit(self: *Clip) void {
        self.sound.destroy();
    }

    pub fn set_position(self: *Clip, pos: [3]f32) void {
        self.sound.setPosition(pos);
    }
};

var clip: Clip = undefined;

pub fn set_listener_position(pos: [3]f32) void {
    engine.setListenerPosition(0, pos);
}

pub fn set_listener_direction(dir: [3]f32) void {
    engine.setListenerDirection(0, dir);
}

pub fn init() !void {
    assert(!initialized);

    zaudio.init(util.allocator());

    engine = try zaudio.Engine.create(null);

    set_listener_position([_]f32{ 0.0, 0.0, 0.0 });
    set_listener_direction([_]f32{ 1.0, 0.0, 1.0 });

    clip = try Clip.load_from_file("test.mp3", false, true);
    clip.set_position([_]f32{ 10.0, 0.0, 0.0 });
    try clip.sound.start();

    initialized = true;
    assert(initialized);
}

pub fn deinit() void {
    assert(initialized);

    clip.deinit();

    engine.destroy();
    zaudio.deinit();

    initialized = false;
    assert(!initialized);
}
