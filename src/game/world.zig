const std = @import("std");
const c = @import("consts.zig");
const Chunk = @import("chunk.zig");
const Player = @import("player.zig");
const worldgen = @import("worldgen.zig");
const util = @import("../core/util.zig");

pub const ChunkLocation = [3]isize;
pub const ChunkMap = std.AutoArrayHashMap(ChunkLocation, *Chunk);

var chunkMap: ChunkMap = undefined;

var player: Player = undefined;
pub fn init(seed: u32) !void {
    player = try Player.init();
    try player.register_input();
    player.transform.pos[0] = 0;
    player.transform.pos[1] = 14;
    player.transform.pos[2] = 0;

    try worldgen.init(seed);

    chunkMap = ChunkMap.init(util.allocator());
}

pub fn deinit() void {
    for (chunkMap.values()) |v| {
        v.deinit();
        util.allocator().destroy(v);
    }
    chunkMap.deinit();
    player.deinit();

    worldgen.deinit();
}

pub fn get_voxel(coord: [3]isize) Chunk.AtomKind {
    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[1], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        const idx = Chunk.get_index([_]usize{ @intCast(@mod(coord[0], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[2], c.CHUNK_SUB_BLOCKS)) });
        return chunk.subvoxels.items[idx].material;
    } else {
        return .Air;
    }
}

pub fn update() !void {
    player.update();

    // We have a new location -- figure out what chunks are needed
    const CHUNK_RADIUS = 1;

    const curr_player_chunk = [_]isize{
        @divTrunc(@as(isize, @intFromFloat(player.transform.pos[0])), c.CHUNK_BLOCKS),
        @divTrunc(@as(isize, @intFromFloat(player.transform.pos[1])), c.CHUNK_BLOCKS),
        @divTrunc(@as(isize, @intFromFloat(player.transform.pos[2])), c.CHUNK_BLOCKS),
    };

    var target_chunks = std.ArrayList(ChunkLocation).init(util.allocator());
    defer target_chunks.deinit();

    var z_curr = curr_player_chunk[2] - CHUNK_RADIUS - 1;
    while (z_curr <= curr_player_chunk[2] + CHUNK_RADIUS) : (z_curr += 1) {
        var x_curr = curr_player_chunk[0] - CHUNK_RADIUS - 1;
        while (x_curr <= curr_player_chunk[0] + CHUNK_RADIUS) : (x_curr += 1) {
            const chunk_coord = [_]isize{ x_curr, 0, z_curr };

            try target_chunks.append(chunk_coord);

            if (!chunkMap.contains(chunk_coord)) {
                const chunk = try util.allocator().create(Chunk);
                chunk.* = try Chunk.new([_]f32{ @floatFromInt(chunk_coord[0] * c.CHUNK_BLOCKS), 0, @floatFromInt(chunk_coord[2] * c.CHUNK_BLOCKS) }, chunk_coord);
                try worldgen.fill(chunk, [_]isize{ chunk_coord[0], chunk_coord[2] });

                try chunkMap.put(
                    chunk_coord,
                    chunk,
                );
            }
        }
    }

    var extra_chunks = std.ArrayList(ChunkLocation).init(util.allocator());
    defer extra_chunks.deinit();
    for (chunkMap.keys()) |k| {
        for (target_chunks.items) |i| {
            if (k[0] == i[0] and k[1] == i[1] and k[2] == i[2]) {
                break;
            }
        } else {
            try extra_chunks.append(k);
        }
    }

    for (extra_chunks.items) |i| {
        var chunk = chunkMap.get(i).?;
        chunk.deinit();
        util.allocator().destroy(chunk);
        _ = chunkMap.swapRemove(i);
    }

    for (chunkMap.values()) |v| {
        try v.update();
    }
}

pub fn draw() void {
    for (chunkMap.values()) |v| {
        v.draw();
    }

    player.draw();
}
