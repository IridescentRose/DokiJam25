const std = @import("std");
const Chunk = @import("chunk.zig");
const c = @import("consts.zig");

const assert = std.debug.assert;
const util = @import("../core/util.zig");

pub const Stencil = [c.SUBVOXEL_SIZE]Chunk.Atom;

var stone_stencil: Stencil = undefined;
var still_water_stencil: Stencil = undefined;
var dirt_stencil: Stencil = undefined;
var grass_stencil: Stencil = undefined;
var sand_stencil: Stencil = undefined;
var leaf_stencil: Stencil = undefined;
var log_stencil: Stencil = undefined;

pub const Registry = std.AutoArrayHashMap(Chunk.AtomKind, *Stencil);
pub var registry: Registry = undefined;

var initialized: bool = false;

pub fn init(s: u32) !void {
    assert(!initialized);

    var rng = std.Random.DefaultPrng.init(s);
    generate_stone(&rng);
    generate_still_water(&rng);
    generate_dirt(&rng);
    generate_grass(&rng);
    generate_sand(&rng);
    generate_leaf(&rng);
    generate_log(&rng);

    // TODO: This can definitely be done at comptime
    registry = Registry.init(util.allocator());
    try registry.put(.Stone, &stone_stencil);
    try registry.put(.StillWater, &still_water_stencil);
    try registry.put(.Dirt, &dirt_stencil);
    try registry.put(.Grass, &grass_stencil);
    try registry.put(.Sand, &sand_stencil);
    try registry.put(.Leaf, &leaf_stencil);
    try registry.put(.Log, &log_stencil);

    initialized = true;
    assert(initialized);
}

pub fn deinit() void {
    assert(initialized);

    registry.deinit();
    initialized = false;
    assert(!initialized);
}

pub fn stencil_index(pos: [3]usize) usize {
    return ((pos[1] % c.SUB_BLOCKS_PER_BLOCK) * c.SUB_BLOCKS_PER_BLOCK + (pos[2] % c.SUB_BLOCKS_PER_BLOCK)) * c.SUB_BLOCKS_PER_BLOCK + (pos[0] % c.SUB_BLOCKS_PER_BLOCK);
}

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
        const lightness = rng.random().int(u8) % 32;

        if (lightness % 4 == 0) {
            atom.* = .{
                .material = .Leaf,
                .color = [_]u8{ 0x35 + lightness, 0x79 + lightness, 0x20 + lightness % 8 },
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
