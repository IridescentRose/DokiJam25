const std = @import("std");
const c = @import("consts.zig");
const Chunk = @import("chunk.zig");
const Player = @import("player.zig");
const worldgen = @import("worldgen.zig");
const util = @import("../core/util.zig");
const Particle = @import("particle.zig");
const gl = @import("../gfx/gl.zig");
const ChunkMesh = @import("chunkmesh.zig");

pub const ChunkLocation = [2]isize;
pub const ChunkMap = std.AutoArrayHashMap(ChunkLocation, Chunk);

const VoxelEdit = struct {
    offset: u32,
    atom: Chunk.Atom,
};

var chunkMap: ChunkMap = undefined;
var particles: Particle = undefined;
pub var active_atoms: std.ArrayList(Chunk.AtomData) = undefined;
var rand = std.Random.DefaultPrng.init(1337);
pub var player: Player = undefined;
var chunk_mesh: ChunkMesh = undefined;
pub var blocks: []Chunk.Atom = undefined;
var edit_list: std.ArrayList(VoxelEdit) = undefined;
var chunk_freelist: std.ArrayList(usize) = undefined;
var chunk_todo_list: std.ArrayList(ChunkLocation) = undefined;

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

    // TODO: Random spawn location
    player.transform.pos[0] = 1024;
    player.transform.pos[1] = 64;
    player.transform.pos[2] = 1024;

    try worldgen.init(seed);

    active_atoms = std.ArrayList(Chunk.AtomData).init(util.allocator());

    blocks = try util.allocator().alloc(Chunk.Atom, c.CHUNK_SUBVOXEL_SIZE * c.MAX_CHUNKS);
    @memset(
        blocks,
        .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } },
    );

    chunk_freelist = std.ArrayList(usize).init(util.allocator());
    for (0..c.MAX_CHUNKS) |i| {
        try chunk_freelist.append(c.CHUNK_SUBVOXEL_SIZE * i);
    }

    edit_list = std.ArrayList(VoxelEdit).init(util.allocator());

    chunk_todo_list = std.ArrayList(ChunkLocation).init(util.allocator());
    chunkMap = ChunkMap.init(util.allocator());
    particles = try Particle.new();
}

pub fn deinit() void {
    chunkMap.deinit();
    player.deinit();

    particles.deinit();

    active_atoms.deinit();
    edit_list.deinit();

    worldgen.deinit();

    util.allocator().free(blocks);
    chunk_mesh.deinit();
    chunk_freelist.deinit();
    chunk_todo_list.deinit();
}

pub fn get_voxel(coord: [3]isize) Chunk.AtomKind {
    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        const idx = Chunk.get_index([_]usize{ @intCast(@mod(coord[0], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS)), @intCast(@mod(coord[2], c.CHUNK_SUB_BLOCKS)) });
        return blocks[chunk.offset + idx].material;
    } else {
        return .Air;
    }
}

pub fn is_in_world(coord: [3]isize) bool {
    if (coord[1] < 0 or coord[1] >= c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) {
        return false;
    }

    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };
    return chunkMap.contains(chunk_coord);
}

pub fn set_voxel(coord: [3]isize, atom: Chunk.Atom) void {
    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        const idx = Chunk.get_index([_]usize{ @intCast(@mod(coord[0], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS)), @intCast(@mod(coord[2], c.CHUNK_SUB_BLOCKS)) });
        blocks[chunk.offset + idx] = atom;
        edit_list.append(VoxelEdit{
            .offset = @intCast(chunk.offset + idx),
            .atom = atom,
        }) catch unreachable;
    }
}

fn update_player_surrounding_chunks() !void {
    // We have a new location -- figure out what chunks are needed
    const CHUNK_RADIUS = c.CHUNK_RADIUS;

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
            const chunk_coord = [_]isize{ x_curr, z_curr };

            try target_chunks.append(chunk_coord);
            if (!chunkMap.contains(chunk_coord)) {
                const offset = chunk_freelist.pop() orelse continue;
                try chunk_todo_list.append(chunk_coord);

                @memset(blocks[offset .. offset + c.CHUNK_SUBVOXEL_SIZE], .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });

                const chunk = Chunk{
                    .offset = @intCast(offset),
                };
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
            if (k[0] == i[0] and k[1] == i[1]) {
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

    if (chunk_todo_list.items.len != 0) {
        // Pop one chunk to fill
        const coord = chunk_todo_list.pop() orelse return;
        const chunk = chunkMap.get(coord) orelse return;
        try worldgen.fill(chunk, [_]isize{ coord[0], coord[1] });
        chunk_mesh.update_chunk_sub_data(@ptrCast(@alignCast(blocks)), chunk.offset, c.CHUNK_SUBVOXEL_SIZE);
    }
}

fn lessThan(_: usize, a: ChunkMesh.IndirectionEntry, b: ChunkMesh.IndirectionEntry) bool {
    // YZX ordering
    if (a.y != b.y) return a.y < b.y;
    if (a.z != b.z) return a.z < b.z;
    return a.x < b.x;
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
                .y = 0,
                .z = @intCast(coord[1]),
                .voxel_offset = @intCast(chunkMap.values()[i].offset),
            };
        }
    }

    std.sort.pdq(ChunkMesh.IndirectionEntry, &chunk_mesh.chunks, @as(usize, @intCast(0)), lessThan);

    chunk_mesh.update_indirect_data();

    chunk_mesh.update_edits(@ptrCast(@alignCast(edit_list.items)));
    edit_list.clearAndFree();

    player.update();

    // Rain
    for (0..8) |_| {
        const rx = @as(f32, @floatFromInt(@rem(rand.random().int(i32), 128)));
        const rz = @as(f32, @floatFromInt(@rem(rand.random().int(i32), 128)));
        try particles.add_particle(Particle.Particle{
            .kind = .Water,
            .pos = [_]f32{ player.transform.pos[0] + rx * 0.25, 63.0, player.transform.pos[2] + rz * 0.25 },
            .color = [_]u8{ 0xC0, 0xD0, 0xFF },
            .vel = [_]f32{ 0, -80, 0 },
            .lifetime = 300,
        });
    }

    count += 1;
    if (count % 3 == 0) {
        var a_count: usize = 0;
        for (active_atoms.items) |*atom| {
            a_count += atom.moves;

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
                    continue;
                }

                if (get_voxel(below_coord) == .Grass or get_voxel(below_coord) == .Dirt or get_voxel(below_coord) == .Sand) {
                    if (a_count % 100 == 0) {
                        // TODO: Update saturation
                        set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });
                        atom.coord = below_coord;
                        atom.moves = 0; // We have "saturated" the ground
                        continue;
                    }
                }

                if (get_voxel(below_coord) == .StillWater) {
                    set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });
                    atom.coord = below_coord;
                    atom.moves = 0; // We have "combined" with the still water
                    continue;
                }

                const check_fars = [_][3]isize{
                    [_]isize{ atom.coord[0] - 2, atom.coord[1] - 1, atom.coord[2] },
                    [_]isize{ atom.coord[0] + 2, atom.coord[1] - 1, atom.coord[2] },
                    [_]isize{ atom.coord[0], atom.coord[1] - 1, atom.coord[2] - 2 },
                    [_]isize{ atom.coord[0], atom.coord[1] - 1, atom.coord[2] + 2 },
                    [_]isize{ atom.coord[0] - 1, atom.coord[1] - 1, atom.coord[2] },
                    [_]isize{ atom.coord[0] + 1, atom.coord[1] - 1, atom.coord[2] },
                    [_]isize{ atom.coord[0], atom.coord[1] - 1, atom.coord[2] - 1 },
                    [_]isize{ atom.coord[0], atom.coord[1] - 1, atom.coord[2] + 1 },
                    [_]isize{ atom.coord[0] - 3, atom.coord[1] - 1, atom.coord[2] },
                    [_]isize{ atom.coord[0] + 3, atom.coord[1] - 1, atom.coord[2] },
                    [_]isize{ atom.coord[0], atom.coord[1] - 1, atom.coord[2] - 3 },
                    [_]isize{ atom.coord[0], atom.coord[1] - 1, atom.coord[2] + 3 },
                };

                var found = false;
                for (check_fars) |far_coord| {
                    if (get_voxel(far_coord) == .Air or get_voxel(far_coord) == .StillWater) {
                        set_voxel(far_coord, .{ .material = .Water, .color = [_]u8{ 0x46, 0x67, 0xC3 } });
                        set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });
                        atom.coord = far_coord;
                        atom.moves -= 1;
                        found = true;
                        break;
                    }
                }

                if (found) continue;

                // Otherwise we randomly try to spread out
                const next_coords = [_][3]isize{
                    [_]isize{ atom.coord[0] + 1, atom.coord[1], atom.coord[2] },
                    [_]isize{ atom.coord[0] - 1, atom.coord[1], atom.coord[2] },
                    [_]isize{ atom.coord[0], atom.coord[1], atom.coord[2] + 1 },
                    [_]isize{ atom.coord[0], atom.coord[1], atom.coord[2] - 1 },
                };

                var valid_dirs_len: usize = 0;
                var valid_dirs: [4]usize = @splat(0);

                for (0..4) |i| {
                    if (get_voxel(next_coords[i]) == .Air) {
                        valid_dirs[valid_dirs_len] = i;
                        valid_dirs_len += 1;
                    }
                }

                // Happy little accident
                if (valid_dirs_len == 0) {
                    // We don't go to zero because it's possible that another atom will move away
                    // and we can still spread out
                    atom.moves -= 1;
                    continue;
                }

                const spread_dir = rand.random().int(u32) % valid_dirs_len;
                const next_coord_idx = valid_dirs[spread_dir];
                const next_coord = next_coords[next_coord_idx];

                set_voxel(next_coord, .{ .material = .Water, .color = [_]u8{ 0x46, 0x67, 0xC3 } });
                set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });
                atom.coord = next_coord;
                atom.moves -= 1;
            }
        }

        if (active_atoms.items.len != 0) {
            var i: usize = active_atoms.items.len - 1;
            while (i > 0) : (i -= 1) {
                if (active_atoms.items[i].moves == 0) {
                    const atom = active_atoms.swapRemove(i);

                    if (get_voxel(atom.coord) == .Water) {
                        set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });
                    }
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
