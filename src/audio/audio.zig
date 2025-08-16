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
            .sound = try engine.createSoundFromFile(path, .{
                .flags = .{
                    .stream = stream,
                    .no_spatialization = !spatial, // Enable spatialization when spatial=true
                },
            }),
        };
    }

    pub fn deinit(self: *Clip) void {
        self.sound.destroy();
    }

    pub fn set_position(self: *Clip, pos: [3]f32) void {
        self.sound.setPosition(pos);
    }

    pub fn start(self: *Clip) !void {
        try self.sound.start();
    }
};

// Store multiple clips for the same SFX
var sfx_clips: std.ArrayList(Clip) = undefined;

pub fn set_listener_position(pos: [3]f32) void {
    engine.setListenerPosition(0, pos);
}

pub fn set_listener_direction(dir: [3]f32) void {
    engine.setListenerDirection(0, dir);
}

// Function to play SFX at a specific position with spatialization
pub fn play_sfx_at_position(path: [:0]const u8, pos: [3]f32) !void {
    var clip = try Clip.load_from_file(path, false, true); // Create new sound instance
    clip.set_position(pos);
    try clip.start();
    try sfx_clips.append(clip); // Store for later cleanup
}

pub fn play_sfx_no_position(path: [:0]const u8) !void {
    var clip = try Clip.load_from_file(path, true, false); // Create new sound instance
    try clip.start();
    try sfx_clips.append(clip); // Store for later cleanup
}

pub fn init() !void {
    assert(!initialized);

    zaudio.init(util.allocator());
    engine = try zaudio.Engine.create(null);

    sfx_clips = std.ArrayList(Clip).init(util.allocator());

    set_listener_position([_]f32{ 0.0, 0.0, 0.0 });
    set_listener_direction([_]f32{ 0.0, 0.0, 1.0 });

    initialized = true;
    assert(initialized);
}

pub fn deinit() void {
    assert(initialized);

    // Clean up all SFX clips
    for (sfx_clips.items) |*clip| {
        clip.deinit();
    }
    sfx_clips.deinit();

    engine.destroy();
    zaudio.deinit();

    initialized = false;
    assert(!initialized);
}

pub fn update() void {
    var i: usize = 0;
    while (i < sfx_clips.items.len) {
        if (!sfx_clips.items[i].sound.isPlaying()) {
            sfx_clips.items[i].deinit();
            _ = sfx_clips.swapRemove(i);
        } else {
            i += 1;
        }
    }
}
