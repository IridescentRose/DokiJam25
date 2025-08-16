const std = @import("std");
const c = @import("consts.zig");
const Chunk = @import("chunk.zig");
const Player = @import("player.zig");
const worldgen = @import("worldgen.zig");
const util = @import("../core/util.zig");
const Particle = @import("particle.zig");
const gl = @import("../gfx/gl.zig");
const ui = @import("../gfx/ui.zig");
const ecs = @import("entity/ecs.zig");
const input = @import("../core/input.zig");
const zm = @import("zmath");
const gfx = @import("../gfx/gfx.zig");
const Voxel = @import("voxel.zig");
const Visitor = @import("ai/visitor.zig");
const Tomato = @import("ai/tomato.zig");
const Town = @import("town/Town.zig");
const Builder = @import("ai/dragoons//builder.zig");
const Farmer = @import("ai/dragoons/farmer.zig");
const Lumberjack = @import("ai/dragoons/lumberjack.zig");
const Weather = @import("weather.zig");
const ambience = @import("ambience.zig");
const Blocks = @import("blocks.zig");
const audio = @import("../audio/audio.zig");
const mm = @import("model_manager.zig");

const ChunkMesh = @import("chunkmesh.zig");
const job_queue = @import("job_queue.zig");

pub const ChunkLocation = [2]isize;
pub const ChunkMap = std.AutoArrayHashMap(ChunkLocation, Chunk);

const VoxelEdit = struct {
    offset: u32,
    atom: Chunk.Atom,
};

pub var chunkMap: ChunkMap = undefined;
var particles: Particle = undefined;
pub var active_atoms: std.ArrayList(Chunk.AtomData) = undefined;
var rand = std.Random.DefaultPrng.init(1337);
pub var player: Player = undefined;
var chunk_mesh: ChunkMesh = undefined;
pub var blocks: []Chunk.Atom = undefined;
var edit_list: std.ArrayList(VoxelEdit) = undefined;
var chunk_freelist: std.ArrayList(usize) = undefined;
pub var light_pv_row: zm.Mat = undefined;

pub var town: Town = undefined;
pub var weather: Weather = undefined;

// Pause menu
pub var paused: bool = true;
var overlay_tex: u32 = 0;
var resume_tex: u32 = 0;
var save_tex: u32 = 0;
var resume_highlight_tex: u32 = 0;
var save_highlight_tex: u32 = 0;

pub fn save_world_info() !void {
    var file = try std.fs.cwd().createFile("world/world.dat", .{ .truncate = true });
    defer file.close();

    const writer = file.deprecatedWriter();
    try writer.writeInt(u64, world_seed, .little);
    try writer.writeInt(u64, tick, .little);
}

pub fn load_world_info() !void {
    var file = try std.fs.cwd().openFile("world/world.dat", .{});
    defer file.close();

    const reader = file.deprecatedReader();
    world_seed = try reader.readInt(u64, .little);
    tick = try reader.readInt(u64, .little);
}

// Time
// 6am
pub var world_seed: u64 = 0;
pub var tick: u64 = 6000;
const TICK_PER_HOUR = 1000;
const TICK_PER_MINUTE = TICK_PER_HOUR / 60;
const TICK_HOURS = 24;

pub var inflight_chunk_mutex: std.Thread.Mutex = std.Thread.Mutex{};
pub var inflight_chunk_list: std.ArrayList(ChunkLocation) = undefined;
pub fn init(seed: u64) !void {
    world_seed = seed;
    try job_queue.init();

    try ecs.init();

    town = try Town.init();
    try ambience.init();
    try mm.init();

    std.fs.cwd().makeDir("world") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    load_world_info() catch |err| std.debug.print("Failed to load world info: {}\n", .{err});

    chunk_mesh = try ChunkMesh.new();
    try chunk_mesh.vertices.appendSlice(util.allocator(), &[_]ChunkMesh.Vertex{
        ChunkMesh.Vertex{
            .vert = [_]f32{ -1, 1, 1 },
        },
        ChunkMesh.Vertex{
            .vert = [_]f32{ -1, -1, 1 },
        },
        ChunkMesh.Vertex{
            .vert = [_]f32{ 1, -1, 1 },
        },
        ChunkMesh.Vertex{
            .vert = [_]f32{ 1, 1, 1 },
        },
    });
    try chunk_mesh.indices.appendSlice(util.allocator(), &[_]u32{ 0, 1, 2, 2, 3, 0 });
    chunk_mesh.update();

    player = try Player.init();
    try player.register_input();

    overlay_tex = try ui.load_ui_texture("overlay.png");
    resume_tex = try ui.load_ui_texture("resume_button.png");
    save_tex = try ui.load_ui_texture("save_button.png");
    resume_highlight_tex = try ui.load_ui_texture("resume_button_hover.png");
    save_highlight_tex = try ui.load_ui_texture("save_button_hover.png");

    // Find a random spawn point
    try worldgen.init(world_seed);
    weather = Weather.init(world_seed);

    if (!ecs.loaded) {
        var rng = std.Random.DefaultPrng.init(world_seed);
        while (true) {
            const x = @mod(rng.random().int(u32), 4096);
            const sub_x = x * c.SUB_BLOCKS_PER_BLOCK;
            const z = @mod(rng.random().int(u32), 4096);
            const sub_z = x * c.SUB_BLOCKS_PER_BLOCK;

            const h = worldgen.height_at(@as(f64, @floatFromInt(sub_x)), @as(f64, @floatFromInt(sub_z)));

            if (h <= 256) continue;

            player.entity.get_ptr(.transform).pos[0] = @floatFromInt(x);
            player.entity.get_ptr(.transform).pos[1] = @floatCast((h + 32) / c.SUB_BLOCKS_PER_BLOCK);
            player.entity.get_ptr(.transform).pos[2] = @floatFromInt(z);

            player.spawn_pos = player.entity.get(.transform).pos;

            break;
        }

        // Spawn tomato on player for now
        _ = try Tomato.create(player.entity.get_ptr(.transform).pos, @splat(0), .Tomato);
    }

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
    inflight_chunk_list = std.ArrayList(ChunkLocation).init(util.allocator());

    chunkMap = ChunkMap.init(util.allocator());
    particles = try Particle.new();
}

pub fn deinit() void {
    job_queue.deinit();
    var first = chunkMap.iterator();
    while (first.next()) |it| {
        it.value_ptr.save(it.key_ptr.*);
        it.value_ptr.edits.deinit();
    }

    town.deinit();
    chunkMap.deinit();
    player.deinit();
    mm.deinit();

    particles.deinit();

    active_atoms.deinit();
    edit_list.deinit();

    worldgen.deinit();
    ecs.deinit();
    ambience.deinit();

    util.allocator().free(blocks);
    chunk_mesh.deinit();
    chunk_freelist.deinit();
    inflight_chunk_list.deinit();

    save_world_info() catch |err| std.debug.print("Failed to save world info: {}\n", .{err});
}

pub fn get_voxel(coord: [3]isize) Chunk.AtomKind {
    if (coord[1] < 0 or coord[1] >= c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) {
        return .Air;
    }

    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        // Still is being generated, don't give half results.
        if (!chunk.populated) return .Air;

        const idx = Chunk.get_index([_]usize{ @intCast(@mod(coord[0], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS)), @intCast(@mod(coord[2], c.CHUNK_SUB_BLOCKS)) });
        return blocks[chunk.offset + idx].material;
    } else {
        return .Air;
    }
}

pub fn get_full_voxel(coord: [3]isize) Chunk.Atom {
    if (coord[1] < 0 or coord[1] >= c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) {
        return .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } };
    }

    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        // Still is being generated, don't give half results.
        if (!chunk.populated) return .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } };

        const idx = Chunk.get_index([_]usize{ @intCast(@mod(coord[0], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS)), @intCast(@mod(coord[2], c.CHUNK_SUB_BLOCKS)) });
        return blocks[chunk.offset + idx];
    } else {
        return .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } };
    }
}

// This is in block coordinates, not SUB_BLOCKS
// Scans all sub blocks for a particular atom
pub fn contained_in_block(key: Chunk.AtomKind, coord: [3]isize) bool {
    if (coord[1] < 0 or coord[1] >= c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) {
        return false;
    }

    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_BLOCKS), @divFloor(coord[2], c.CHUNK_BLOCKS) };
    const sub_chunk_coord = [_]usize{ @intCast(@mod(coord[0], c.CHUNK_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_BLOCKS * c.VERTICAL_CHUNKS)), @intCast(@mod(coord[2], c.CHUNK_BLOCKS)) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        // Still is being generated, don't give half results.
        if (!chunk.populated) return false;

        for (0..c.SUB_BLOCKS_PER_BLOCK) |y| {
            for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
                for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                    const idx = Chunk.get_index([_]usize{ x + sub_chunk_coord[0] * c.SUB_BLOCKS_PER_BLOCK, y + sub_chunk_coord[1] * c.SUB_BLOCKS_PER_BLOCK, z + sub_chunk_coord[2] * c.SUB_BLOCKS_PER_BLOCK });
                    if (blocks[chunk.offset + idx].material == key) {
                        return true;
                    }
                }
            }
        } else {
            return false;
        }
    } else {
        return false;
    }
}
// Scans all sub blocks for a particular atom
pub fn only_contained_in_block(key: Chunk.AtomKind, coord: [3]isize) bool {
    if (coord[1] < 0 or coord[1] >= c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) {
        return false;
    }

    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_BLOCKS), @divFloor(coord[2], c.CHUNK_BLOCKS) };
    const sub_chunk_coord = [_]usize{ @intCast(@mod(coord[0], c.CHUNK_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_BLOCKS * c.VERTICAL_CHUNKS)), @intCast(@mod(coord[2], c.CHUNK_BLOCKS)) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        // Still is being generated, don't give half results.
        if (!chunk.populated) return false;

        for (0..c.SUB_BLOCKS_PER_BLOCK) |y| {
            for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
                for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                    const idx = Chunk.get_index([_]usize{ x + sub_chunk_coord[0] * c.SUB_BLOCKS_PER_BLOCK, y + sub_chunk_coord[1] * c.SUB_BLOCKS_PER_BLOCK, z + sub_chunk_coord[2] * c.SUB_BLOCKS_PER_BLOCK });
                    if (blocks[chunk.offset + idx].material != key) {
                        return false;
                    }
                }
            }
        } else {
            return true;
        }
    } else {
        return true;
    }
}

// In block coords
pub fn break_only_in_block(key: Chunk.AtomKind, coord: [3]isize) bool {
    if (coord[1] < 0 or coord[1] >= c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) {
        return false;
    }

    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_BLOCKS), @divFloor(coord[2], c.CHUNK_BLOCKS) };
    const sub_chunk_coord = [_]usize{ @intCast(@mod(coord[0], c.CHUNK_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_BLOCKS * c.VERTICAL_CHUNKS)), @intCast(@mod(coord[2], c.CHUNK_BLOCKS)) };

    if (chunkMap.get(chunk_coord)) |chunk| {
        // Still is being generated, don't give half results.
        if (!chunk.populated) return false;

        var y: usize = c.SUB_BLOCKS_PER_BLOCK - 1;
        while (y >= 0) : (y -= 1) {
            for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
                for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                    const idx = Chunk.get_index([_]usize{ x + sub_chunk_coord[0] * c.SUB_BLOCKS_PER_BLOCK, y + sub_chunk_coord[1] * c.SUB_BLOCKS_PER_BLOCK, z + sub_chunk_coord[2] * c.SUB_BLOCKS_PER_BLOCK });
                    if (blocks[chunk.offset + idx].material == key) {
                        return set_voxel([_]isize{ coord[0] * c.SUB_BLOCKS_PER_BLOCK + @as(isize, @intCast(x)), coord[1] * c.SUB_BLOCKS_PER_BLOCK + @as(isize, @intCast(y)), coord[2] * c.SUB_BLOCKS_PER_BLOCK + @as(isize, @intCast(z)) }, .{
                            .material = .Air,
                            .color = [_]u8{ 0, 0, 0 },
                        });
                    }
                }
            }

            if (y == 0) {
                return false;
            }
        } else {
            return false;
        }
    } else {
        return false;
    }
}

pub fn place_block(new_blk: Chunk.AtomKind, coord: [3]isize) bool {
    if (coord[1] < 0 or coord[1] >= c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) {
        return false;
    }

    for (0..c.SUB_BLOCKS_PER_BLOCK) |y| {
        for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
            for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                const ix: isize = @intCast(x);
                const iy: isize = @intCast(y);
                const iz: isize = @intCast(z);

                const test_coord = [3]isize{ coord[0] * c.SUB_BLOCKS_PER_BLOCK + ix, coord[1] * c.SUB_BLOCKS_PER_BLOCK + iy, coord[2] * c.SUB_BLOCKS_PER_BLOCK + iz };
                const stidx = Blocks.stencil_index([3]usize{ x, y, z });
                const stencil = Blocks.registry[@intFromEnum(new_blk)];
                _ = set_voxel(test_coord, stencil[stidx]);
            }
        }
    }

    return true;
}

pub fn explode(block_coord: [3]f32, radius: f32) void {
    const minCoord = [_]isize{
        @intFromFloat(@floor(block_coord[0] - radius)),
        @intFromFloat(@floor(block_coord[1] - radius)),
        @intFromFloat(@floor(block_coord[2] - radius)),
    };
    const maxCoord = [_]isize{
        @intFromFloat(@ceil(block_coord[0] + radius)),
        @intFromFloat(@ceil(block_coord[1] + radius)),
        @intFromFloat(@ceil(block_coord[2] + radius)),
    };

    var y = minCoord[1];
    while (y <= maxCoord[1]) : (y += 1) {
        var z = minCoord[2];
        while (z <= maxCoord[2]) : (z += 1) {
            var x = minCoord[0];
            while (x <= maxCoord[0]) : (x += 1) {
                const dx = block_coord[0] - @as(f32, @floatFromInt(x));
                const dy = block_coord[1] - @as(f32, @floatFromInt(y));
                const dz = block_coord[2] - @as(f32, @floatFromInt(z));
                const distance = dx * dx + dy * dy + dz * dz;
                if (distance <= radius * radius) {
                    const coord = [_]isize{ x, y, z };
                    // What is breaking, if not placing air?
                    _ = place_block(.Air, coord);
                }
            }
        }
    }

    audio.play_sfx_at_position("explosion.mp3", block_coord) catch |err| {
        std.debug.print("Failed to play explosion sound: {}\n", .{err});
    };
}

pub fn is_in_world(coord: [3]isize) bool {
    if (coord[1] < 0 or coord[1] >= c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) {
        return false;
    }

    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };
    const chunk = chunkMap.get(chunk_coord) orelse return false;

    if (!chunk.populated) {
        return false; // Chunk is still being generated
    }

    return true;
}

pub fn set_voxel(coord: [3]isize, atom: Chunk.Atom) bool {
    if (coord[1] < 0 or coord[1] >= c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS) {
        return false; // Out of bounds
    }

    const chunk_coord = [_]isize{ @divFloor(coord[0], c.CHUNK_SUB_BLOCKS), @divFloor(coord[2], c.CHUNK_SUB_BLOCKS) };

    if (chunkMap.getPtr(chunk_coord)) |chunk| {
        // Still is being generated, don't mess with results.
        if (!chunk.populated) return false;

        const subvoxel_coord = [_]usize{ @intCast(@mod(coord[0], c.CHUNK_SUB_BLOCKS)), @intCast(@mod(coord[1], c.CHUNK_SUB_BLOCKS * c.VERTICAL_CHUNKS)), @intCast(@mod(coord[2], c.CHUNK_SUB_BLOCKS)) };
        const idx = Chunk.get_index(subvoxel_coord);

        edit_list.append(VoxelEdit{
            .offset = @intCast(chunk.offset + idx),
            .atom = atom,
        }) catch unreachable;

        chunk.edits.put(idx, atom) catch unreachable;

        blocks[chunk.offset + idx] = atom;
        return true;
    } else {
        return false;
    }
}

fn update_player_surrounding_chunks() !void {
    // We have a new location -- figure out what chunks are needed
    const CHUNK_RADIUS = c.CHUNK_RADIUS;

    const curr_player_chunk = [_]isize{
        @divFloor(@as(isize, @intFromFloat(player.entity.get(.transform).pos[0])), c.CHUNK_BLOCKS),
        @divFloor(@as(isize, @intFromFloat(player.entity.get(.transform).pos[1])), c.CHUNK_BLOCKS),
        @divFloor(@as(isize, @intFromFloat(player.entity.get(.transform).pos[2])), c.CHUNK_BLOCKS),
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

                inflight_chunk_mutex.lock();
                defer inflight_chunk_mutex.unlock();

                var found = false;
                for (inflight_chunk_list.items) |i| {
                    if (i[0] == chunk_coord[0] and i[1] == chunk_coord[1]) {
                        // Already inflight
                        found = true;
                        break;
                    }
                } else {
                    // Not inflight, add to list
                    try inflight_chunk_list.append(chunk_coord);
                }

                if (found) continue;

                @memset(blocks[offset .. offset + c.CHUNK_SUBVOXEL_SIZE], .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });

                try chunkMap.putNoClobber(
                    chunk_coord,
                    .{
                        .offset = @intCast(offset),
                        .edits = std.AutoArrayHashMap(usize, Chunk.Atom).init(util.allocator()),
                    },
                );

                try job_queue.job_queue.writeItem(.{
                    .GenerateChunk = .{ .pos = chunk_coord },
                });
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
        var chunk = chunkMap.getPtr(i) orelse continue; // TODO: WHY CAN THIS HAPPEN? WTF

        inflight_chunk_mutex.lock();
        defer inflight_chunk_mutex.unlock();

        var found = false;
        for (inflight_chunk_list.items) |ic| {
            if (ic[0] == i[0] and ic[1] == i[1]) {
                // Already inflight
                found = true;
                break;
            }
        } else {
            // Not inflight, safe to free
            chunk.save(i);
            chunk.edits.deinit();
            const offset = chunk.offset;
            _ = chunkMap.swapRemove(i);
            try chunk_freelist.append(offset);
        }

        if (found) continue;
    }
}

fn lessThan(_: usize, a: ChunkMesh.IndirectionEntry, b: ChunkMesh.IndirectionEntry) bool {
    // YZX ordering
    if (a.y != b.y) return a.y < b.y;
    if (a.z != b.z) return a.z < b.z;
    return a.x < b.x;
}

var timer: i64 = 0;
pub fn update(dt: f32) !void {
    try update_player_surrounding_chunks();

    @memset(
        &chunk_mesh.chunks,
        .{ .x = 0, .y = 0, .z = 0, .voxel_offset = -1 },
    );

    for (chunkMap.keys(), 0..) |coord, i| {
        if (i < chunk_mesh.chunks.len) {
            inflight_chunk_mutex.lock();
            defer inflight_chunk_mutex.unlock();

            var found = false;
            for (inflight_chunk_list.items) |ic| {
                if (ic[0] == coord[0] and ic[1] == coord[1]) {
                    // Already inflight
                    found = true;
                    break;
                }
            }

            if (found) continue;

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

    player.update(dt);

    for (chunkMap.values()) |*chk| {
        if (chk.populated and !chk.uploaded) {
            // Upload the chunk data to the GPU
            chunk_mesh.update_chunk_sub_data(@ptrCast(@alignCast(blocks)), chk.offset, c.CHUNK_SUBVOXEL_SIZE);
            chk.uploaded = true;
        }
    }

    if (paused) return;

    for (ecs.storage.active_entities.items) |*entity| {
        const kind = entity.get(.kind);

        // TODO: do not update if out of world boiunds
        // TODO: This is just a refactor of duplicated logic
        switch (kind) {
            .player => {
                entity.do_physics(dt);
            },
            .visitor => {
                Visitor.update(entity.*, dt);
                entity.do_physics(dt);
            },
            .dragoon_builder => {
                Builder.update(entity.*, dt);
                entity.do_physics(dt);
            },
            .dragoon_farmer => {
                Farmer.update(entity.*, dt);
                entity.do_physics(dt);
            },
            .dragoon_lumberjack => {
                Lumberjack.update(entity.*, dt);
                entity.do_physics(dt);
            },
            .tomato => {
                Tomato.update(entity.*, dt);
                entity.do_physics(dt);
            },
            else => {
                // Other entities can be updated here
            },
        }
    }

    var new_active_atoms = std.ArrayList(Chunk.AtomData).init(util.allocator());
    defer new_active_atoms.deinit();

    town.update();
    weather.update();
    try ambience.update();

    try particles.update(dt);
    if (weather.is_raining) {
        for (0..8) |_| {
            const rx = @as(f32, @floatFromInt(@rem(rand.random().int(i32), 128)));
            const rz = @as(f32, @floatFromInt(@rem(rand.random().int(i32), 128)));
            try particles.add_particle(Particle.Particle{
                .kind = .Water,
                .pos = [_]f32{ player.entity.get(.transform).pos[0] + rx * 0.25, 63.0, player.entity.get(.transform).pos[2] + rz * 0.25 },
                .color = [_]u8{ 0xC0, 0xD0, 0xFF },
                .vel = [_]f32{ 0, -80, 0 },
                .lifetime = 300,
            });
        }

        var rng = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
        if (rng.random().int(u32) % 1000 == 0) {
            // Spawn a lightning bolt (set a block on fire)

            if (rng.random().int(u32) % 10 == 0) {
                const dx = @rem(rng.random().int(i32), 24);
                const dz = @rem(rng.random().int(i32), 24);

                const voxel_pos_player = [_]isize{
                    @as(isize, @intFromFloat(player.entity.get(.transform).pos[0])) + dx,
                    64,
                    @as(isize, @intFromFloat(player.entity.get(.transform).pos[2])) + dz,
                };

                var y_pos: isize = 62;
                while (y_pos > 0) : (y_pos -= 1) {
                    if (!contained_in_block(.Air, [_]isize{ voxel_pos_player[0], y_pos, voxel_pos_player[2] })) {
                        y_pos += 1;
                        break;
                    }
                }

                for (0..c.SUB_BLOCKS_PER_BLOCK) |y| {
                    for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
                        for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                            _ = set_voxel([_]isize{ voxel_pos_player[0] * c.SUB_BLOCKS_PER_BLOCK + @as(isize, @intCast(x)), y_pos * c.SUB_BLOCKS_PER_BLOCK + @as(isize, @intCast(y)), voxel_pos_player[2] * c.SUB_BLOCKS_PER_BLOCK + @as(isize, @intCast(z)) }, .{
                                .material = .Fire,
                                .color = [_]u8{ 0xFF, 0x81, 0x42 },
                            });

                            try active_atoms.append(.{
                                .coord = [_]isize{ voxel_pos_player[0] * c.SUB_BLOCKS_PER_BLOCK + @as(isize, @intCast(x)), y_pos * c.SUB_BLOCKS_PER_BLOCK + @as(isize, @intCast(y)), voxel_pos_player[2] * c.SUB_BLOCKS_PER_BLOCK + @as(isize, @intCast(z)) },
                                .moves = 100,
                            });
                        }
                    }
                }
            }

            try audio.play_sfx_at_position("thunder.mp3", player.entity.get(.transform).pos);
        }
    }

    if (std.time.milliTimestamp() > timer) {
        timer = std.time.milliTimestamp() + 50;
        tick += 30;
    } else {
        return;
    }

    if (tick % 24000 == 0) {
        // On new day, summon visitor
        if (town.created and tick / 24000 < 5) {
            _ = try Visitor.create([_]f32{ town.town_center[0], town.town_center[1] + 3, town.town_center[2] }, @splat(0), [_]isize{ @intFromFloat(town.town_center[0]), @intFromFloat(town.town_center[1]), @intFromFloat(town.town_center[2]) }, @enumFromInt(@min(8, 4 + tick / 24000)));
        }
    }

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

            const prev_voxel = get_full_voxel(below_coord);
            if (prev_voxel.material == .Air) {
                if (set_voxel(below_coord, .{ .material = .Water, .color = [_]u8{ 0x46, 0x67, 0xC3 } })) {
                    if (!set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } })) {
                        // Failed, so undo the first set
                        _ = set_voxel(below_coord, prev_voxel);
                    } else {
                        atom.coord = below_coord;
                    }
                }
                continue;
            }

            if (prev_voxel.material == .Grass or prev_voxel.material == .Dirt or prev_voxel.material == .Sand) {
                if (a_count % 100 == 0) {
                    // TODO: Update saturation
                    if (set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } })) {
                        atom.coord = below_coord;
                        atom.moves = 0; // We have "saturated" the ground
                        continue;
                    }
                }
            }

            if (prev_voxel.material == .StillWater) {
                if (set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } })) {
                    atom.coord = below_coord;
                    atom.moves = 0; // We have "combined" with the still water
                    continue;
                }
            }

            if (prev_voxel.material == .Fire) {
                if (set_voxel(below_coord, .{ .material = .Leaf, .color = [_]u8{ 0x35, 0x79, 0x20 } })) {
                    atom.moves -|= 10; // We have "combined" with the still water
                    continue;
                }
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
                const far_voxel = get_full_voxel(far_coord);
                if (far_voxel.material == .Air or far_voxel.material == .StillWater) {
                    if (set_voxel(far_coord, .{ .material = .Water, .color = [_]u8{ 0x46, 0x67, 0xC3 } })) {
                        if (set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } })) {
                            atom.coord = far_coord;
                            atom.moves -|= 1;
                            found = true;
                        } else {
                            // Failed, so undo the first set
                            _ = set_voxel(far_coord, far_voxel);
                        }
                    }
                    break;
                } else if (far_voxel.material == .Fire) {
                    if (set_voxel(below_coord, .{ .material = .Leaf, .color = [_]u8{ 0x35, 0x79, 0x20 } })) {
                        atom.moves -|= 10; // We have "combined" with the still water
                        continue;
                    }
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
                atom.moves -|= 1;
                continue;
            }

            const spread_dir = rand.random().int(u32) % valid_dirs_len;
            const next_coord_idx = valid_dirs[spread_dir];
            const next_coord = next_coords[next_coord_idx];

            if (set_voxel(next_coord, .{ .material = .Water, .color = [_]u8{ 0x46, 0x67, 0xC3 } })) {
                if (set_voxel(atom.coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } })) {
                    atom.coord = next_coord;
                    atom.moves -|= 1;
                } else {
                    // Failed, so undo the first set
                    _ = set_voxel(next_coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } });
                }
            }
        } else if (kind == .Fire or kind == .Ember) {
            // // Chance to not spread
            if (a_count % 7 != 0) {
                atom.moves -|= 4;
                continue;
            }

            if (atom.moves == 0) continue;

            // Fire particles randomly check the surrounding voxels

            var random_amount = rand.random().intRangeLessThan(u16, 0, 100);
            while (atom.moves > 0 and random_amount > 0) : ({
                atom.moves -|= 1;
                random_amount -|= 1;
            }) {
                const dx = rand.random().intRangeLessThan(isize, -24, 24);
                const dy = rand.random().intRangeLessThan(isize, -24, 24);
                const dz = rand.random().intRangeLessThan(isize, -24, 24);

                const check_coord = [_]isize{
                    atom.coord[0] + dx,
                    atom.coord[1] + dy,
                    atom.coord[2] + dz,
                };

                const voxel = get_voxel(check_coord);
                if (voxel == .Grass or voxel == .Leaf or voxel == .Log or voxel == .Crop or voxel == .Plank) {
                    if (voxel == .Grass) {
                        if (set_voxel(check_coord, .{ .material = .Ash, .color = [_]u8{ 0x0F, 0x0F, 0x0F } })) {
                            try new_active_atoms.append(.{
                                .coord = check_coord,
                                .moves = 255, // Fire particles can move around a bit
                            });

                            atom.moves -|= 1;
                        }
                    } else if (voxel == .Log) {
                        if (set_voxel(check_coord, .{ .material = .Ember, .color = [_]u8{ 0x4F, 0x2F, 0x0F } })) {
                            try new_active_atoms.append(.{
                                .coord = check_coord,
                                .moves = 255, // Fire particles can move around a bit
                            });

                            atom.moves -|= 1;
                        }
                    } else {
                        if (set_voxel(check_coord, .{ .material = .Fire, .color = [_]u8{ 0xFF, 0x81, 0x42 } })) {
                            try new_active_atoms.append(.{
                                .coord = check_coord,
                                .moves = 255, // Fire particles can move around a bit
                            });
                        }
                    }
                }
            }
        } else {
            // Unknown, stop movement
            atom.moves = 0;
            continue;
        }

        try active_atoms.resize(active_atoms.items.len);
    }

    if (active_atoms.items.len != 0) {
        var i: usize = active_atoms.items.len - 1;
        while (i > 0) : (i -= 1) {
            if (active_atoms.items[i].moves == 0) {
                const coord = active_atoms.items[i].coord;
                if (get_voxel(coord) == .Water or get_voxel(coord) == .Fire) {
                    if (set_voxel(coord, .{ .material = .Air, .color = [_]u8{ 0, 0, 0 } })) {
                        _ = active_atoms.swapRemove(i);
                    }
                } else if (get_voxel(coord) == .Ember) {
                    if (set_voxel(coord, .{ .material = .Charcoal, .color = [_]u8{ 0x1F, 0x1F, 0x1F } })) {
                        _ = active_atoms.swapRemove(i);
                    }
                }
            }
        }
    }

    if (active_atoms.items.len != 0 and active_atoms.items[0].moves == 0) {
        _ = active_atoms.orderedRemove(0);
    }

    try active_atoms.appendSlice(new_active_atoms.items);
}

pub fn draw(shadow: bool) void {
    ui.clear_sprites();

    chunk_mesh.draw(shadow);

    player.draw(shadow);

    for (ecs.storage.active_entities.items) |*entity| {
        const kind = entity.get(.kind);

        switch (kind) {
            .player => {
                // Player is already drawn
            },
            else => {
                entity.draw(shadow, player.camera.target);
            },
        }
    }

    if (shadow) return; // Don't draw the UI in shadow pass; particles are unlit

    if (weather.is_raining) {
        particles.draw();
    }

    var buf: [64]u8 = @splat(0);
    const hours: usize = @intCast(tick / TICK_PER_HOUR);
    const minutes: usize = @intCast((tick % TICK_PER_HOUR) / TICK_PER_MINUTE);

    const time = std.fmt.bufPrint(&buf, "TIME: {}:{s}{}", .{ hours % TICK_HOURS, if (minutes % 60 < 10) "0" else "", minutes % 60 }) catch unreachable;
    ui.add_text(time, [_]f32{ ui.UI_RESOLUTION[0] - 30.0, ui.UI_RESOLUTION[1] - 30.0 }, [_]u8{ 255, 255, 255, 255 }, 4, 1, .Right) catch unreachable;

    if (paused) {
        ui.add_sprite(.{
            .offset = [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2, 1 },
            .scale = [_]f32{ ui.UI_RESOLUTION[0], ui.UI_RESOLUTION[1] },
            .color = [_]u8{ 255, 255, 255, 255 },
            .tex_id = overlay_tex,
        }) catch unreachable;

        const mouse_pos = input.get_mouse_position();

        var resume_texture = resume_tex;
        if (mouse_pos[0] >= ui.UI_RESOLUTION[0] / 2 - 96 * 7 / 2 and
            mouse_pos[0] <= ui.UI_RESOLUTION[0] / 2 + 96 * 7 / 2 and
            mouse_pos[1] >= ui.UI_RESOLUTION[1] / 2 + 32 - 12 * 7 / 2 and
            mouse_pos[1] <= ui.UI_RESOLUTION[1] / 2 + 32 + 12 * 7 / 2)
        {
            resume_texture = resume_highlight_tex;
        }

        ui.add_sprite(.{
            .offset = [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2 + 32, 2 },
            .scale = [_]f32{ 96 * 7, 12 * 7 },
            .color = [_]u8{ 255, 255, 255, 255 },
            .tex_id = resume_texture,
        }) catch unreachable;

        var save_texture = save_tex;
        if (mouse_pos[0] >= ui.UI_RESOLUTION[0] / 2 - 96 * 7 / 2 and
            mouse_pos[0] <= ui.UI_RESOLUTION[0] / 2 + 96 * 7 / 2 and
            mouse_pos[1] >= ui.UI_RESOLUTION[1] / 2 - 128 - 12 * 7 / 2 and
            mouse_pos[1] <= ui.UI_RESOLUTION[1] / 2 - 128 + 12 * 7 / 2)
        {
            save_texture = save_highlight_tex;
        }

        ui.add_sprite(.{
            .offset = [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2 - 128, 2 },
            .scale = [_]f32{ 96 * 7, 12 * 7 },
            .color = [_]u8{ 255, 255, 255, 255 },
            .tex_id = save_texture,
        }) catch unreachable;

        ui.add_text("RESUME GAME", [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2 + 32 - 6 }, [_]u8{ 255, 255, 255, 255 }, 3, 2, .Center) catch unreachable;
        ui.add_text("SAVE AND END", [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2 - 128 - 6 }, [_]u8{ 255, 255, 255, 255 }, 3, 2, .Center) catch unreachable;
    }
}
