const std = @import("std");
const util = @import("../core/util.zig");
const assert = std.debug.assert;
const Chunk = @import("chunk.zig");
const worldgen = @import("worldgen.zig");
const world = @import("world.zig");

const GenJob = struct {
    pos: [2]isize, // Chunk Position
};

const Job = union(enum) {
    GenerateChunk: GenJob,
    // SpreadFire, SaveChunk, etc.
};

var initialized: bool = false;
pub var job_mutex = std.Thread.Mutex{};
pub var job_queue: std.fifo.LinearFifo(Job, .Dynamic) = undefined;

pub fn init() !void {
    assert(!initialized);

    job_queue = std.fifo.LinearFifo(Job, .Dynamic).init(util.allocator());
    initialized = true;
    assert(initialized);

    const thread_count = try std.Thread.getCpuCount();
    for (0..thread_count) |_| {
        _ = try std.Thread.spawn(.{}, worker_thread, .{});
    }
}

fn worker_thread() void {
    while (true) {
        job_mutex.lock();
        defer job_mutex.unlock();
        const job = job_queue.readItem() orelse {
            std.Thread.sleep(std.time.ns_per_ms); // 1 ms
            continue;
        };

        switch (job) {
            .GenerateChunk => |gen| {
                const chunk = world.chunkMap.get(gen.pos) orelse continue;
                worldgen.fill(chunk, gen.pos) catch |err| {
                    std.debug.print("Error generating chunk at {any}: {}\n", .{ gen.pos, err });
                    continue;
                };
                world.chunkMap.put(gen.pos, .{
                    .offset = chunk.offset,
                    .size = chunk.size,
                    .populated = true,
                    .uploaded = false,
                }) catch |err| {
                    std.debug.print("Error updating chunk map for {any}: {}\n", .{ gen.pos, err });
                };

                world.inflight_chunk_mutex.lock();
                defer world.inflight_chunk_mutex.unlock();

                for (world.inflight_chunk_list.items, 0..) |i, c| {
                    if (i[0] == gen.pos[0] and i[1] == gen.pos[1]) {
                        // Remove from inflight list
                        _ = world.inflight_chunk_list.swapRemove(c);
                        break;
                    }
                }
            },
        }
    }
}

pub fn deinit() void {
    assert(initialized);

    job_queue.deinit();
    initialized = false;
    assert(!initialized);
}
