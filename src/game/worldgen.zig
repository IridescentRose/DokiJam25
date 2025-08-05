const std = @import("std");
const Chunk = @import("chunk.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");
const znoise = @import("znoise");

const gen = znoise.FnlGenerator{
    .seed = 1337,
    .frequency = 1.0 / 16.0,
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

var stencil: []Chunk.Atom = undefined;

pub fn init(s: u32) !void {
    var rng = std.Random.DefaultPrng.init(s);
    stencil = try util.allocator().alloc(Chunk.Atom, c.SUBVOXEL_SIZE);
    for (stencil) |*atom| {
        const gray = rng.random().int(u8) % 32 + 96;
        atom.* = .{
            .material = .Stone,
            .color = [_]u8{ gray, gray, gray },
        };
    }
}

pub fn deinit() void {
    util.allocator().free(stencil);
}

pub fn fill(chunk: *Chunk, location: [2]isize) !void {
    const before = std.time.nanoTimestamp();

    const blocks_per_chunk = @as(f64, @floatFromInt(c.CHUNK_BLOCKS));

    for (0..c.CHUNK_BLOCKS) |y| {
        for (0..c.CHUNK_BLOCKS) |z| {
            for (0..c.CHUNK_BLOCKS) |x| {
                const xf = @as(f64, @floatFromInt(x));
                const yf = @as(f64, @floatFromInt(y));
                const zf = @as(f64, @floatFromInt(z));

                const xlf = @as(f64, @floatFromInt(location[0]));
                const zlf = @as(f64, @floatFromInt(location[1]));

                const world_x = xf + xlf * blocks_per_chunk;
                const world_y = yf;
                const world_z = zf + zlf * blocks_per_chunk;

                const noise_val = gen.noise2(@floatCast(world_x), @floatCast(world_z));
                const h = (noise_val + 1.0) * 5.0;

                const bcoord = Chunk.get_block_index([_]usize{ x, y, z });

                if (yf < h - 3) {
                    @memcpy(chunk.subvoxels.items[bcoord .. bcoord + c.SUBVOXEL_SIZE], stencil);
                } else if (yf >= h - 3 and yf < h) {
                    for (0..c.SUB_BLOCKS_PER_BLOCK) |sy| {
                        for (0..c.SUB_BLOCKS_PER_BLOCK) |sz| {
                            for (0..c.SUB_BLOCKS_PER_BLOCK) |sx| {
                                const sub_bcoord = Chunk.get_sub_block_index([_]usize{ sx, sy, sz });

                                const sub_xf = world_x + @as(f64, @floatFromInt(sx)) / @as(f64, @floatFromInt(c.SUB_BLOCKS_PER_BLOCK));
                                const sub_yf = world_y + @as(f64, @floatFromInt(sy)) / @as(f64, @floatFromInt(c.SUB_BLOCKS_PER_BLOCK));
                                const sub_zf = world_z + @as(f64, @floatFromInt(sz)) / @as(f64, @floatFromInt(c.SUB_BLOCKS_PER_BLOCK));

                                const sub_noiseval = gen.noise2(@floatCast(sub_xf), @floatCast(sub_zf));

                                const sub_h = (sub_noiseval + 1.0) * 5.0;

                                if (sub_yf < sub_h) {
                                    chunk.subvoxels.items[bcoord + sub_bcoord] = .{
                                        .material = .Stone,
                                        .color = stencil[sub_bcoord].color,
                                    };
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    chunk.populated = true;
    chunk.dirty = true;

    const after = std.time.nanoTimestamp();
    std.debug.print("Filled chunk at {any}, {any} in {any}us\n", .{ location[0], location[1], @divTrunc((after - before), std.time.ns_per_us) });
}
