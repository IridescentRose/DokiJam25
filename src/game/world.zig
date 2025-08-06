const std = @import("std");
const c = @import("consts.zig");
const Chunk = @import("chunk.zig");
const Player = @import("player.zig");
const worldgen = @import("worldgen.zig");
const util = @import("../core/util.zig");
const Particle = @import("particle.zig");
const gl = @import("../gfx/gl.zig");
const ChunkMesh = @import("chunkmesh.zig");

pub const ChunkLocation = [3]isize;
pub const ChunkMap = std.AutoArrayHashMap(ChunkLocation, Chunk);

var chunkMap: ChunkMap = undefined;
var particles: Particle = undefined;

const AtomData = struct {
    coord: AtomCoord,
    moves: u8,
};
const AtomCoord = [3]isize;

pub var active_atoms: std.ArrayList(AtomData) = undefined;

var rand = std.Random.DefaultPrng.init(1337);
pub var player: Player = undefined;

var chunk_mesh: ChunkMesh = undefined;
pub var blocks: []Chunk.Atom = undefined;

var chunk_freelist: std.ArrayList(usize) = undefined;

pub fn init(seed: u32) !void {
    chunk_mesh = try ChunkMesh.new();
    try chunk_mesh.vertices.appendSlice(util.allocator(), &[_]ChunkMesh.Vertex{
        ChunkMesh.Vertex{
            .vert = [_]f32{ -1, 1, 0 },
        },
        ChunkMesh.Vertex{
            .vert = [_]f32{ -1, -1, 0 },
        },
        ChunkMesh.Vertex{
            .vert = [_]f32{ 1, -1, 0 },
        },
        ChunkMesh.Vertex{
            .vert = [_]f32{ 1, 1, 0 },
        },
    });
    try chunk_mesh.indices.appendSlice(util.allocator(), &[_]u32{ 0, 1, 2, 2, 3, 0 });
    chunk_mesh.update();

    player = try Player.init();
    try player.register_input();
    player.transform.pos[0] = 8;
    player.transform.pos[1] = 14;
    player.transform.pos[2] = 8;

    try worldgen.init(seed);

    active_atoms = std.ArrayList(AtomData).init(util.allocator());

    blocks = try util.allocator().alloc(Chunk.Atom, c.CHUNK_SUBVOXEL_SIZE * 25);
    @memset(
        blocks,
        .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } },
    );

    chunk_freelist = std.ArrayList(usize).init(util.allocator());
    for (0..25) |i| {
        try chunk_freelist.append(c.CHUNK_SUBVOXEL_SIZE * i);
    }

    chunkMap = ChunkMap.init(util.allocator());
    particles = try Particle.new();
}

pub fn deinit() void {
    chunkMap.deinit();
    player.deinit();

    particles.deinit();

    active_atoms.deinit();

    worldgen.deinit();

    util.allocator().free(blocks);
    chunk_mesh.deinit();
    chunk_freelist.deinit();
}

pub fn get_voxel(coord: [3]isize) Chunk.AtomKind {
    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[1], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        const idx = Chunk.get_index([_]usize{ @intCast(@mod(coord[0], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[2], c.CHUNK_SUB_BLOCKS)) });
        return blocks[chunk.offset + idx].material;
    } else {
        return .Air;
    }
}

pub fn is_in_world(coord: [3]isize) bool {
    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[1], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };
    return chunkMap.contains(chunk_coord);
}

pub fn set_voxel(coord: [3]isize, atom: Chunk.Atom) void {
    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[1], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        const idx = Chunk.get_index([_]usize{ @intCast(@mod(coord[0], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[2], c.CHUNK_SUB_BLOCKS)) });
        blocks[chunk.offset + idx] = atom;
    }
}

fn update_player_surrounding_chunks() !void {
    // We have a new location -- figure out what chunks are needed
    const CHUNK_RADIUS = 2;

    const curr_player_chunk = [_]isize{
        @divFloor(@as(isize, @intFromFloat(player.transform.pos[0])), c.CHUNK_BLOCKS),
        @divFloor(@as(isize, @intFromFloat(player.transform.pos[1])), c.CHUNK_BLOCKS),
        @divFloor(@as(isize, @intFromFloat(player.transform.pos[2])), c.CHUNK_BLOCKS),
    };

    var target_chunks = std.ArrayList(ChunkLocation).init(util.allocator());
    defer target_chunks.deinit();

    var z_curr = curr_player_chunk[2] - CHUNK_RADIUS;
    while (z_curr <= curr_player_chunk[2] + CHUNK_RADIUS) : (z_curr += 1) {
        var x_curr = curr_player_chunk[0] - CHUNK_RADIUS;
        while (x_curr <= curr_player_chunk[0] + CHUNK_RADIUS) : (x_curr += 1) {
            const chunk_coord = [_]isize{ x_curr, 0, z_curr };

            try target_chunks.append(chunk_coord);
            if (!chunkMap.contains(chunk_coord)) {
                const offset = chunk_freelist.pop() orelse continue;
                @memset(blocks[offset .. offset + c.CHUNK_SUBVOXEL_SIZE], .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });

                const chunk = Chunk{
                    .offset = @intCast(offset),
                };
                try worldgen.fill(chunk, [_]isize{ chunk_coord[0], chunk_coord[2] });

                try chunkMap.put(
                    chunk_coord,
                    chunk,
                );

                chunk_mesh.update_chunk_sub_data(@ptrCast(@alignCast(blocks)), chunk.offset, c.CHUNK_SUBVOXEL_SIZE);
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
        const chunk = chunkMap.get(i) orelse unreachable;
        try chunk_freelist.append(chunk.offset);
        _ = chunkMap.swapRemove(i);
    }
}

var count: usize = 0;
pub fn update() !void {
    try update_player_surrounding_chunks();

    @memset(
        &chunk_mesh.chunks,
        .{ .x = 0, .y = 0, .z = 0, .voxel_offset = -1 },
    );

    for (chunkMap.keys(), 0..) |coord, i| {
        if (i < chunk_mesh.chunks.len) {
            chunk_mesh.chunks[i] = ChunkMesh.IndirectionEntry{
                .x = @intCast(coord[0]),
                .y = @intCast(coord[1]),
                .z = @intCast(coord[2]),
                .voxel_offset = @intCast(chunkMap.values()[i].offset),
            };
        }
    }
    chunk_mesh.update_indirect_data();

    player.update();

    count += 1;

    // Rain
    for (0..8) |_| {
        const rx = @as(f32, @floatFromInt(@rem(rand.random().int(i32), 128)));
        const rz = @as(f32, @floatFromInt(@rem(rand.random().int(i32), 128)));
        try particles.add_particle(Particle.Particle{
            .kind = .Water,
            .pos = [_]f32{ player.transform.pos[0] + rx * 0.25, player.transform.pos[1] + 24.0, player.transform.pos[2] + rz * 0.25 },
            .color = [_]u8{ 0x46, 0x67, 0xC3 },
            .vel = [_]f32{ 0, -48, 0 },
            .lifetime = 300,
        });
    }

    if (count % 6 == 0) {
        for (active_atoms.items) |*atom| {
            if (atom.moves == 0) continue;

            if (!is_in_world(atom.coord)) {
                atom.moves = 0;
                continue;
                // Will be removed in the next update
            }

            const kind = get_voxel(atom.coord);
            if (kind == .Water) {
                // Water accumulation
                const below_coord = [_]isize{ atom.coord[0], atom.coord[1] - 1, atom.coord[2] };
                if (get_voxel(below_coord) == .Air) {
                    set_voxel(below_coord, .{ .material = .Water, .color = [_]u8{ 0x46, 0x67, 0xC3 } });
                    set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });
                    atom.coord = below_coord;
                    atom.moves -= 1;
                    continue;
                }

                // Otherwise we randomly try to spread out
                const next_coords = [_][3]isize{
                    [_]isize{ atom.coord[0] + 1, atom.coord[1], atom.coord[2] },
                    [_]isize{ atom.coord[0] - 1, atom.coord[1], atom.coord[2] },
                    [_]isize{ atom.coord[0], atom.coord[1], atom.coord[2] + 1 },
                    [_]isize{ atom.coord[0], atom.coord[1], atom.coord[2] - 1 },
                };

                const spread_dir = rand.random().int(u32) % 4;
                const next_coord = next_coords[spread_dir];
                if (get_voxel(next_coord) == .Air) {
                    set_voxel(next_coord, .{ .material = .Water, .color = [_]u8{ 0x46, 0x67, 0xC3 } });
                    set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });
                    atom.coord = next_coord;
                }
            }
        }

        if (active_atoms.items.len != 0) {
            var i: usize = active_atoms.items.len - 1;
            while (i > 0) : (i -= 1) {
                if (active_atoms.items[i].moves == 0) {
                    _ = active_atoms.swapRemove(i);
                }
            }
        }

        if (active_atoms.items.len != 0 and active_atoms.items[0].moves == 0) {
            _ = active_atoms.orderedRemove(0);
        }
    }

    try particles.update();
}

pub fn draw() void {
    chunk_mesh.draw();

    player.draw();
    particles.draw();
}
