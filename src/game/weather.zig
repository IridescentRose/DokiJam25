const std = @import("std");

seed: u64,
time_til_next_rain: usize,
time_til_end_rain: usize,
is_raining: bool,

const Self = @This();

pub fn init(seed: u64) Self {
    var rng = std.Random.DefaultPrng.init(seed);
    return .{
        .is_raining = false,
        .time_til_end_rain = rng.random().int(u32) % 20000,
        .time_til_next_rain = rng.random().int(u32) % 45000,
        .seed = seed,
    };
}

pub fn update(self: *Self) void {
    if (self.is_raining) {
        self.time_til_end_rain -= 1;
        if (self.time_til_end_rain == 0) {
            self.is_raining = false;
        }
    } else {
        self.time_til_next_rain -= 1;
        if (self.time_til_next_rain == 0) {
            self.is_raining = true;
            var rng = std.Random.DefaultPrng.init(self.seed);
            self.time_til_end_rain = rng.random().int(u32) % 20000;
            self.time_til_next_rain = rng.random().int(u32) % 85000;
        }
    }
}
