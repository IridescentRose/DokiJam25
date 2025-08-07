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

const Stencil = [c.SUBVOXEL_SIZE]Chunk.Atom;

fn generate_stone(rng: *std.Random.DefaultPrng) void {
    for (&stone_stencil) |*atom| {
        const gray = rng.random().int(u8) % 64 + 96;
        atom.* = .{
            .material = .Stone,
            .color = [_]u8{ gray, gray, gray },
        };
    }
}

fn generate_still_water(rng: *std.Random.DefaultPrng) void {
    for (&still_water_stencil) |*atom| {
        const blue_r = rng.random().int(u8) % 32 + 192;
        atom.* = .{
            .material = .StillWater,
            .color = [_]u8{ 0x46, 0x67 + blue_r % 16, blue_r },
        };
    }
}

fn generate_dirt(rng: *std.Random.DefaultPrng) void {
    for (&dirt_stencil) |*atom| {
        const lightness = rng.random().int(u8) % 16;
        atom.* = .{
            .material = .Dirt,
            .color = [_]u8{ 0x31 + lightness, 0x24 + lightness, 0x1C + lightness % 10 },
        };
    }
}

fn generate_grass(rng: *std.Random.DefaultPrng) void {
    for (&grass_stencil) |*atom| {
        const lightness = rng.random().int(u8) % 32;
        atom.* = .{
            .material = .Grass,
            .color = [_]u8{ 0x00, 0x36 + lightness, 0x1F + lightness % 8 },
        };
    }
}

fn generate_sand(rng: *std.Random.DefaultPrng) void {
    for (&sand_stencil) |*atom| {
        const lightness = rng.random().int(u8) % 16;
        atom.* = .{
            .material = .Sand,
            .color = [_]u8{ 0xE0 + lightness, 0xC0 + lightness, 0xA0 + lightness },
        };
    }
}

fn generate_leaf(rng: *std.Random.DefaultPrng) void {
    for (&leaf_stencil) |*atom| {
        const lightness = rng.random().int(u8) % 16;

        if (lightness % 4 == 0) {
            atom.* = .{
                .material = .Leaf,
                .color = [_]u8{ 0x20 + lightness, 0x80 + lightness, 0x20 + lightness % 8 },
            };
        } else {
            atom.* = .{
                .material = .Air,
                .color = [_]u8{ 0, 0, 0 },
            };
        }
    }
}

fn generate_log(rng: *std.Random.DefaultPrng) void {
    for (0..c.SUB_BLOCKS_PER_BLOCK) |y| {
        for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
            for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                const idx = (y * c.SUB_BLOCKS_PER_BLOCK + z) * c.SUB_BLOCKS_PER_BLOCK + x;
                const center = c.SUB_BLOCKS_PER_BLOCK / 2;

                const radius = c.SUB_BLOCKS_PER_BLOCK / 2 - 1;
                const dx = @abs(@as(isize, @intCast(x)) - center);
                const dz = @abs(@as(isize, @intCast(z)) - center);

                if (dx * dx + dz * dz <= radius * radius) {
                    // Inside the trunk
                    const lightness = rng.random().int(u8) % 16;
                    log_stencil[idx] = .{
                        .material = .Log,
                        .color = [_]u8{ 0x55 + lightness, 0x33 + lightness, 0x11 },
                    };
                } else {
                    // Outside the trunk
                    log_stencil[idx] = .{
                        .material = .Air,
                        .color = [_]u8{ 0, 0, 0 },
                    };
                }
            }
        }
    }
}

var stone_stencil: Stencil = undefined;
var still_water_stencil: Stencil = undefined;
var dirt_stencil: Stencil = undefined;
var grass_stencil: Stencil = undefined;
var sand_stencil: Stencil = undefined;
var leaf_stencil: Stencil = undefined;
var log_stencil: Stencil = undefined;

pub fn init(s: u32) !void {
    var rng = std.Random.DefaultPrng.init(s);
    generate_stone(&rng);
    generate_still_water(&rng);
    generate_dirt(&rng);
    generate_grass(&rng);
    generate_sand(&rng);
    generate_leaf(&rng);
    generate_log(&rng);
}

pub fn deinit() void {}

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

fn stencil_index(x: usize, y: usize, z: usize) usize {
    return ((y % c.SUB_BLOCKS_PER_BLOCK) * c.SUB_BLOCKS_PER_BLOCK + (z % c.SUB_BLOCKS_PER_BLOCK)) * c.SUB_BLOCKS_PER_BLOCK + (x % c.SUB_BLOCKS_PER_BLOCK);
}
const WATER_LEVEL = 256.0;

pub fn fillPlace(chunk: Chunk, internal_location: [3]usize, stencil: Stencil) void {
    for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
        for (0..c.SUB_BLOCKS_PER_BLOCK) |y| {
            for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                const idx = Chunk.get_index([_]usize{
                    internal_location[0] * c.SUB_BLOCKS_PER_BLOCK + x,
                    internal_location[1] * c.SUB_BLOCKS_PER_BLOCK + y,
                    internal_location[2] * c.SUB_BLOCKS_PER_BLOCK + z,
                });
                const stidx = stencil_index(
                    internal_location[0] * c.SUB_BLOCKS_PER_BLOCK + x,
                    internal_location[1] * c.SUB_BLOCKS_PER_BLOCK + y,
                    internal_location[2] * c.SUB_BLOCKS_PER_BLOCK + z,
                );

                if (world.blocks[chunk.offset + idx].material != .Air) continue; // Don't overwrite existing blocks
                world.blocks[chunk.offset + idx] = stencil[stidx];
            }
        }
    }
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

    var count: usize = 0;
    for (0..c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) |y| {
        for (0..c.CHUNK_SUB_BLOCKS) |z| {
            for (0..c.CHUNK_SUB_BLOCKS) |x| {
                count += 1;
                const h = heightmap.items[z * c.CHUNK_SUB_BLOCKS + x];
                // std.debug.print("H {}\n", .{h});

                const yf = @as(f64, @floatFromInt(y));

                if (yf < h - 12.0) {
                    const idx = Chunk.get_index([_]usize{ x, y, z });
                    const stidx = stencil_index(x, y, z);

                    world.blocks[chunk.offset + idx] = stone_stencil[stidx];
                } else if (yf < h - 2.0) {
                    const idx = Chunk.get_index([_]usize{ x, y, z });
                    const stidx = stencil_index(x, y, z);

                    if (h < WATER_LEVEL) {
                        world.blocks[chunk.offset + idx] = sand_stencil[stidx];
                    } else {
                        world.blocks[chunk.offset + idx] = dirt_stencil[stidx];
                    }
                } else if (yf < h) {
                    const idx = Chunk.get_index([_]usize{ x, y, z });
                    const stidx = stencil_index(x, y, z);

                    if (h < WATER_LEVEL + 6.0) {
                        world.blocks[chunk.offset + idx] = sand_stencil[stidx];
                    } else if (h < WATER_LEVEL + 7.0) {
                        world.blocks[chunk.offset + idx] = dirt_stencil[stidx];
                    } else {
                        world.blocks[chunk.offset + idx] = grass_stencil[stidx];
                    }
                } else if (yf <= WATER_LEVEL) {
                    const idx = Chunk.get_index([_]usize{ x, y, z });
                    const stidx = stencil_index(x, y, z);

                    world.blocks[chunk.offset + idx] = still_water_stencil[stidx];
                }
            }
        }
    }

    const loc_hash: isize = @truncate(location[0] * 31 + location[1] * 17);
    var prng = std.Random.DefaultPrng.init(@bitCast(loc_hash));
    const foliage_density = 0.01; // Chance of patch per (x,z)

    // TODO: Fix the bug where foliage and trees generate outside the chunk bounds
    // (happens when x or z is near the edge of the chunk)

    for (0..c.CHUNK_SUB_BLOCKS) |z| {
        for (0..c.CHUNK_SUB_BLOCKS) |x| {
            if (prng.random().float(f32) < foliage_density) {
                const h = heightmap.items[z * c.CHUNK_SUB_BLOCKS + x];
                const surface_y: usize = @intFromFloat(h);

                const idx = Chunk.get_index([_]usize{ x, surface_y, z });
                if (world.blocks[chunk.offset + idx].material != .Grass) continue; // Only place foliage on grass

                if (h > WATER_LEVEL) {
                    const patch_type = prng.random().uintLessThan(u32, 16); // 0: tallgrass, 1: bush

                    const patch_size = 1 + prng.random().uintLessThan(u32, 3); // size 1 to 3

                    for (0..patch_size) |_| {
                        // Try placing around (x, z) with slight offsets

                        if (patch_type != 0) {
                            for (0..3) |sy| {
                                const dx = @min(c.CHUNK_SUB_BLOCKS - 1, (x + prng.random().uintLessThan(u32, 2)));
                                const dz = @min(c.CHUNK_SUB_BLOCKS - 1, (z + prng.random().uintLessThan(u32, 2)));
                                const dy = surface_y + 1 + sy; // Place foliage one block above ground

                                const in_idx = Chunk.get_index([_]usize{ dx, dy, dz });
                                const stidx = stencil_index(dx, dy, dz);
                                world.blocks[chunk.offset + in_idx] = grass_stencil[stidx];
                            }
                        } else {
                            for (0..36) |_| {
                                for (0..7) |sy| {
                                    const dx = @max(@min(c.CHUNK_SUB_BLOCKS - 2, (x + prng.random().uintLessThan(u32, 8))), 2);
                                    const dz = @max(@min(c.CHUNK_SUB_BLOCKS - 2, (z + prng.random().uintLessThan(u32, 8))), 2);
                                    const dy = surface_y + 1 + sy; // Place foliage one block above ground

                                    const in_idx = Chunk.get_index([_]usize{ dx, dy, dz });
                                    const stidx = stencil_index(dx, dy, dz);
                                    world.blocks[chunk.offset + in_idx] = leaf_stencil[stidx];
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    for (0..c.CHUNK_BLOCKS) |z| {
        for (0..c.CHUNK_BLOCKS) |x| {
            // Try placing trees
            if (prng.random().float(f32) < 0.005) {
                const h = heightmap.items[(z * c.SUB_BLOCKS_PER_BLOCK) * c.CHUNK_SUB_BLOCKS + (x * c.SUB_BLOCKS_PER_BLOCK)] - 1.0;

                // Check we aren't on water or sand
                if (h < WATER_LEVEL + 6.0) continue; // Don't place trees on water or sand

                // Place a tree
                // Random height between 4 and 7
                const tree_height = 4 + prng.random().uintLessThan(u32, 4) + 1;

                for (0..tree_height) |dy| {
                    const trunk_x = x;
                    const trunk_z = z;
                    const trunk_y = @as(usize, @intFromFloat(h)) / c.SUB_BLOCKS_PER_BLOCK + dy;

                    if (dy < tree_height - 1) {
                        fillPlace(chunk, [_]usize{ trunk_x, trunk_y, trunk_z }, log_stencil);
                        if (dy > tree_height / 2 - 1) {
                            // Place leaves
                            for (0..5) |lz| {
                                for (0..5) |lx| {
                                    // Skip corners to make it more round
                                    if (lx == 0 and lz == 0) continue;
                                    if (lx == 0 and lz == 4) continue;
                                    if (lx == 4 and lz == 0) continue;
                                    if (lx == 4 and lz == 4) continue;

                                    // If the current leaf block breaks the chunk boundary, skip it
                                    if (@as(isize, @intCast(trunk_x)) + @as(isize, @intCast(lx)) - 2 >= c.CHUNK_SUB_BLOCKS) continue;
                                    if (@as(isize, @intCast(trunk_z)) + @as(isize, @intCast(lz)) - 2 >= c.CHUNK_SUB_BLOCKS) continue;
                                    if (@as(isize, @intCast(trunk_x)) + @as(isize, @intCast(lx)) - 2 < 0) continue;
                                    if (@as(isize, @intCast(trunk_z)) + @as(isize, @intCast(lz)) - 2 < 0) continue;

                                    fillPlace(chunk, [_]usize{ trunk_x + lx - 2, trunk_y, trunk_z + lz - 2 }, leaf_stencil);
                                }
                            }
                        }
                    } else {
                        // Cap the top
                        for (0..3) |lz| {
                            for (0..3) |lx| {
                                if (@as(isize, @intCast(trunk_x)) + @as(isize, @intCast(lx)) - 1 >= c.CHUNK_SUB_BLOCKS) continue;
                                if (@as(isize, @intCast(trunk_z)) + @as(isize, @intCast(lz)) - 1 >= c.CHUNK_SUB_BLOCKS) continue;
                                if (@as(isize, @intCast(trunk_x)) + @as(isize, @intCast(lx)) - 1 < 0) continue;
                                if (@as(isize, @intCast(trunk_z)) + @as(isize, @intCast(lz)) - 1 < 0) continue;

                                const leaf_x = trunk_x + lx - 1;
                                const leaf_z = trunk_z + lz - 1;
                                const leaf_y = trunk_y;

                                fillPlace(chunk, [_]usize{ leaf_x, leaf_y, leaf_z }, leaf_stencil);
                            }
                        }
                    }
                }
            }
        }
    }

    const after = std.time.nanoTimestamp();
    std.debug.print("Filled chunk at {any}, {any} in {any}us\n", .{ location[0], location[1], @divTrunc((after - before), std.time.ns_per_us) });
}
