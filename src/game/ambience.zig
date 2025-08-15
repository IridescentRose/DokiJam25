const audio = @import("../audio/audio.zig");
const world = @import("world.zig");

var rain_ambient: audio.Clip = undefined;
var day_ambient: audio.Clip = undefined;
var night_ambient: audio.Clip = undefined;

pub fn init() !void {
    rain_ambient = try audio.Clip.load_from_file("rain.mp3", true, false);
    day_ambient = try audio.Clip.load_from_file("day.mp3", true, false);
    night_ambient = try audio.Clip.load_from_file("night.mp3", true, false);
}

pub fn deinit() void {
    rain_ambient.deinit();
    day_ambient.deinit();
    night_ambient.deinit();
}

pub fn update() !void {
    if (world.weather.is_raining) {
        try rain_ambient.start();
        try day_ambient.sound.stop();
        try night_ambient.sound.stop();
    } else if (world.tick % 24000 > 6000 and world.tick % 24000 < 18000) {
        try day_ambient.start();
        try night_ambient.sound.stop();
        try rain_ambient.sound.stop();
    } else {
        try night_ambient.start();
        try day_ambient.sound.stop();
        try rain_ambient.sound.stop();
    }
}
