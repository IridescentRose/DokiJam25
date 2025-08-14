const std = @import("std");
const Chunk = @import("chunk.zig");
const c = @import("consts.zig");

const assert = std.debug.assert;
const util = @import("../core/util.zig");

pub const Stencil = [c.SUBVOXEL_SIZE]Chunk.Atom;

pub const Registry = [255]Stencil;
pub const registry = init(42);

pub fn init(s: u32) Registry {
    @setEvalBranchQuota(1024 * 1024 * 1024); // 1 MB

    var rng = std.Random.DefaultPrng.init(s);
    var reg: Registry = undefined;
    @memset(&reg, @splat(.{
        .material = .Air,
        .color = [_]u8{ 0, 0, 0 },
    }));

    generate_stone(&rng, &reg[@intFromEnum(Chunk.AtomKind.Stone)]);
    generate_still_water(&rng, &reg[@intFromEnum(Chunk.AtomKind.StillWater)]);
    generate_dirt(&rng, &reg[@intFromEnum(Chunk.AtomKind.Dirt)]);
    generate_grass(&rng, &reg[@intFromEnum(Chunk.AtomKind.Grass)]);
    generate_sand(&rng, &reg[@intFromEnum(Chunk.AtomKind.Sand)]);
    generate_leaf(&rng, &reg[@intFromEnum(Chunk.AtomKind.Leaf)]);
    generate_log(&rng, &reg[@intFromEnum(Chunk.AtomKind.Log)]);
    generate_bedrock(&rng, &reg[@intFromEnum(Chunk.AtomKind.Bedrock)]);
    generate_town_block(&rng, &reg[@intFromEnum(Chunk.AtomKind.TownBlock)]);

    return reg;
}

pub fn stencil_index(pos: [3]usize) usize {
    return ((pos[1] % c.SUB_BLOCKS_PER_BLOCK) * c.SUB_BLOCKS_PER_BLOCK + (pos[2] % c.SUB_BLOCKS_PER_BLOCK)) * c.SUB_BLOCKS_PER_BLOCK + (pos[0] % c.SUB_BLOCKS_PER_BLOCK);
}

fn generate_town_block(_: *std.Random.DefaultPrng, stencil: *Stencil) void {
    for (stencil) |*atom| {
        atom.* = .{
            .material = .TownBlock,
            .color = [_]u8{ 0xFF, 0xFF, 0x00 },
        };
    }
}

fn generate_stone(rng: *std.Random.DefaultPrng, stencil: *Stencil) void {
    for (stencil) |*atom| {
        const gray = rng.random().int(u8) % 64 + 96;
        atom.* = .{
            .material = .Stone,
            .color = [_]u8{ gray, gray, gray },
        };
    }
}

fn generate_bedrock(rng: *std.Random.DefaultPrng, stencil: *Stencil) void {
    for (stencil) |*atom| {
        const gray = rng.random().int(u8) % 96;
        atom.* = .{
            .material = .Bedrock,
            .color = [_]u8{ gray, gray, gray },
        };
    }
}

fn generate_still_water(rng: *std.Random.DefaultPrng, stencil: *Stencil) void {
    for (stencil) |*atom| {
        const blue_r = rng.random().int(u8) % 32 + 192;
        atom.* = .{
            .material = .StillWater,
            .color = [_]u8{ 0x46, 0x67 + blue_r % 16, blue_r },
        };
    }
}

fn generate_dirt(rng: *std.Random.DefaultPrng, stencil: *Stencil) void {
    for (stencil) |*atom| {
        const lightness = rng.random().int(u8) % 16;
        atom.* = .{
            .material = .Dirt,
            .color = [_]u8{ 0x31 + lightness, 0x24 + lightness, 0x1C + lightness % 10 },
        };
    }
}

fn generate_grass(rng: *std.Random.DefaultPrng, stencil: *Stencil) void {
    for (stencil) |*atom| {
        const lightness = rng.random().int(u8) % 32;
        atom.* = .{
            .material = .Grass,
            .color = [_]u8{ 0x00, 0x36 + lightness, 0x1F + lightness % 8 },
        };
    }
}

fn generate_sand(rng: *std.Random.DefaultPrng, stencil: *Stencil) void {
    for (stencil) |*atom| {
        const lightness = rng.random().int(u8) % 16;
        atom.* = .{
            .material = .Sand,
            .color = [_]u8{ 0xE0 + lightness, 0xC0 + lightness, 0xA0 + lightness },
        };
    }
}

fn generate_leaf(rng: *std.Random.DefaultPrng, stencil: *Stencil) void {
    for (stencil) |*atom| {
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

fn generate_log(rng: *std.Random.DefaultPrng, stencil: *Stencil) void {
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
                    stencil[idx] = .{
                        .material = .Log,
                        .color = [_]u8{ 0x55 + lightness, 0x33 + lightness, 0x11 },
                    };
                } else {
                    // Outside the trunk
                    stencil[idx] = .{
                        .material = .Air,
                        .color = [_]u8{ 0, 0, 0 },
                    };
                }
            }
        }
    }
}
