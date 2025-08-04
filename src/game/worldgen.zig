const std = @import("std");
const Chunk = @import("chunk.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");
const znoise = @import("znoise");

const gen = znoise.FnlGenerator{
    .seed = 1337,
    .frequency = 1.0 / 128.0,
    .noise_type = .perlin,
    .rotation_type3 = .none,
    .fractal_type = .fbm,
    .octaves = 3,
    .lacunarity = 2.0,
    .gain = 0.5,
    .weighted_strength = 0.0,
    .ping_pong_strength = 2.0,
    .cellular_distance_func = .euclideansq,
    .cellular_return_type = .distance,
    .cellular_jitter_mod = 1.0,
    .domain_warp_type = .opensimplex2,
    .domain_warp_amp = 1.0,
};

pub fn init(s: u32) void {
    _ = s;
    // gen.seed = @bitCast(s);
    // gen.frequency = 0.01;
    // gen.noise_type = .opensimplex2;
}

pub fn fill(chunk: *Chunk, location: [2]isize) !void {
    const allocator = util.allocator();
    const sub = @as(f64, @floatFromInt(c.CHUNK_SUB_BLOCKS));
    const sub_per_block = @as(f64, @floatFromInt(c.SUB_BLOCKS_PER_BLOCK));

    for (0..c.CHUNK_SUB_BLOCKS) |y| {
        for (0..c.CHUNK_SUB_BLOCKS) |z| {
            for (0..c.CHUNK_SUB_BLOCKS) |x| {
                const xf = @as(f64, @floatFromInt(x));
                const yf = @as(f64, @floatFromInt(y));
                const zf = @as(f64, @floatFromInt(z));

                const xlf = @as(f64, @floatFromInt(location[0]));
                const zlf = @as(f64, @floatFromInt(location[1]));

                const world_x = xf + xlf * sub;
                const world_z = zf + zlf * sub;

                const noise_val = gen.noise2(@floatCast(world_x), @floatCast(world_z));
                const h = (noise_val + 1.0) * 0.5 + 3.0;

                const grayscale: u8 = @intFromFloat(@min(@max((noise_val + 1.0) * 0.5 * 255.0, 0.0), 255.0));
                const color = [_]u8{ grayscale, grayscale, grayscale };

                const is_solid = yf < h * sub_per_block;

                try chunk.subvoxels.append(allocator, .{
                    .flags = undefined,
                    .state = undefined,
                    .material = if (is_solid) .Stone else .Air,
                    .color = color,
                });
            }
        }
    }

    chunk.subvoxels.shrinkAndFree(allocator, chunk.subvoxels.len);
    chunk.populated = true;
    chunk.dirty = true;
}
