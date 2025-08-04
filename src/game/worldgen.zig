const std = @import("std");
const perlin = @import("perlin.zig");
const Chunk = @import("chunk.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");

var seed: f32 = 0.0;

pub fn init(s: u32) void {
    seed = @floatFromInt(s);
}

pub fn fill(chunk: *Chunk, location: [2]u32) !void {
    var rng = std.Random.DefaultPrng.init(@as(u32, @intFromFloat(seed)) + location[0] + location[1] * 3);

    for (0..c.CHUNK_SUB_BLOCKS) |y| {
        for (0..c.CHUNK_SUB_BLOCKS) |x| {
            for (0..c.CHUNK_SUB_BLOCKS) |z| {
                const xf: f64 = @floatFromInt(x);
                const yf: f64 = @floatFromInt(y);
                const zf: f64 = @floatFromInt(z);

                const h = ((perlin.noise(f64, perlin.permutation, .{
                    .x = xf / 128.0,
                    .y = yf / 128.0,
                    .z = zf / 128.0,
                })) + 1.0) / 2.0 * 3.0 + 2.0;

                const color = rng.random().int(u8) % 0x3F + 0x5F;

                if (@as(f32, @floatFromInt(y)) < h * c.SUB_BLOCKS_PER_BLOCK) {
                    try chunk.subvoxels.append(util.allocator(), .{
                        .flags = undefined,
                        .state = undefined,
                        .material = .Stone,
                        .color = [_]u8{ color, color, color },
                    });
                } else {
                    try chunk.subvoxels.append(util.allocator(), .{
                        .flags = undefined,
                        .state = undefined,
                        .material = .Air,
                        .color = [_]u8{ 0, 0, 0 },
                    });
                }
            }
        }
    }

    chunk.subvoxels.shrinkAndFree(util.allocator(), chunk.subvoxels.len);
    chunk.populated = true;
    chunk.dirty = true;
}
