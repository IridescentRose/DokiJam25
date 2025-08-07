const std = @import("std");
const Chunk = @import("chunk.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");
const znoise = @import("znoise");
const world = @import("world.zig");

const gen = znoise.FnlGenerator{
    .seed = 1337,
    .frequency = 0.25,
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
        const gray = rng.random().int(u8) % 64 + 96;
        atom.* = .{
            .material = .Stone,
            .color = [_]u8{ gray, gray, gray },
        };
    }
}

pub fn deinit() void {
    util.allocator().free(stencil);
}

fn fbm(x: f64, z: f64) f64 {
    return gen.noise2(@floatCast(x), @floatCast(z)); // Normalize to [0, 1]
}

fn clamp(value: f64, min: f64, max: f64) f64 {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

fn height_at(x: f64, z: f64) f64 {
    const scaleBase = 0.001;
    const scaleDetail = 0.01;
    const scale = 0.001;

    const warp = fbm(x * 0.01, z * 0.01) * 20.0;
    const warpedBase = fbm((x + warp) * scale, (z + warp) * scale);

    const base = fbm(x * scaleBase + warpedBase, z * scaleBase + warpedBase);
    const ridged = 1.0 - @abs(fbm(x * 0.002 + warpedBase, z * 0.002 + warpedBase));
    const detail = fbm(x * scaleDetail + warpedBase, z * scaleDetail + warpedBase);

    const valleyMask = clamp(1.0 - @abs(fbm(x * 0.0005, z * 0.0005)), 0.0, 1.0);
    const erosion = std.math.pow(f64, valleyMask, 1.5);

    // Weight & combine
    const weighted = base * 40.0 // base terrain scale
    + ridged * 30.0 * erosion // mountain sharpness
    + detail * 5.0; // micro variation

    return weighted * 6.0 + 168.0; // scale and offset to fit in the world
}

pub fn fill(chunk: Chunk, location: [2]isize) !void {
    const before = std.time.nanoTimestamp();

    const blocks_per_chunk = c.CHUNK_SUB_BLOCKS;

    var heightmap = std.ArrayList(f32).init(util.allocator());
    defer heightmap.deinit();
    for (0..c.CHUNK_SUB_BLOCKS) |z| {
        for (0..c.CHUNK_SUB_BLOCKS) |x| {
            const ix: isize = @intCast(x);
            const iz: isize = @intCast(z);

            const world_x = ix + location[0] * blocks_per_chunk;
            const world_z = iz + location[1] * blocks_per_chunk;
            try heightmap.append(@floatCast(height_at(@floatFromInt(world_x), @floatFromInt(world_z))));
        }
    }

    for (0..c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) |y| {
        for (0..c.CHUNK_SUB_BLOCKS) |z| {
            for (0..c.CHUNK_SUB_BLOCKS) |x| {
                const h = heightmap.items[z * c.CHUNK_SUB_BLOCKS + x];
                // std.debug.print("H {}\n", .{h});

                const yf = @as(f64, @floatFromInt(y));
                if (yf < h) {
                    const idx = Chunk.get_index([_]usize{ x, y, z });
                    world.blocks[chunk.offset + idx] = stencil[((y % c.SUB_BLOCKS_PER_BLOCK) * c.SUB_BLOCKS_PER_BLOCK + (z % c.SUB_BLOCKS_PER_BLOCK)) * c.SUB_BLOCKS_PER_BLOCK + (x % c.SUB_BLOCKS_PER_BLOCK)];
                } else if (yf < 256.0) {
                    const idx = Chunk.get_index([_]usize{ x, y, z });
                    world.blocks[chunk.offset + idx] = .{ .material = .StillWater, .color = [_]u8{ 0x46, 0x67, 0xC3 } };
                }
            }
        }
    }

    const after = std.time.nanoTimestamp();
    std.debug.print("Filled chunk at {any}, {any} in {any}us\n", .{ location[0], location[1], @divTrunc((after - before), std.time.ns_per_us) });
}
