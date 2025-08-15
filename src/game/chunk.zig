const std = @import("std");
const c = @import("consts.zig");
const world = @import("world.zig");

pub const AtomKind = enum(u8) {
    Air = 0,
    Dirt = 1,
    Stone = 2,
    Grass = 4,
    Sand = 5,
    StillWater = 6,
    Leaf = 7,
    Log = 8,
    Bedrock = 13,
    TownBlock = 14,
    FarmBlock = 15,
    Crop = 19,

    // TODO: These need to have stencils
    Charcoal = 12,
    Water = 3,
    Fire = 9,
    Ember = 10,
    Ash = 11,
};

pub const Atom = struct {
    material: AtomKind,
    color: [3]u8,

    comptime {
        if (@sizeOf(Atom) != 4) {
            @compileError("Atom struct size must be 4 bytes");
        }
    }
};

// Simulation data for active atoms (e.g. falling sand)
pub const AtomData = struct {
    coord: AtomCoord,
    moves: u8,
};

pub const AtomCoord = [3]isize;

offset: u32,
size: u32 = c.CHUNK_SUBVOXEL_SIZE,
populated: bool = false,
uploaded: bool = false,
edits: std.AutoArrayHashMap(usize, Atom),
tree_locs: [256][2]usize = @splat(@as([2]usize, @splat(0))),

pub fn get_index(coord: [3]usize) usize {
    return (coord[1] * c.CHUNK_SUB_BLOCKS + coord[2]) * c.CHUNK_SUB_BLOCKS + coord[0];
}

pub fn save(self: *@This(), coord: [2]isize) void {
    var buf: [256]u8 = @splat(0);

    const name = std.fmt.bufPrint(&buf, "world/{}_{}.chunk.gz", .{
        coord[0], coord[1],
    }) catch {
        std.debug.print("Failed to create file for chunk at {} {}\n", .{
            coord[0], coord[1],
        });
        return;
    };

    var fs = std.fs.cwd().createFile(name, .{
        .truncate = true,
    }) catch {
        std.debug.print("Failed to create file: {s}\n", .{name});
        return;
    };
    defer fs.close();

    const fwriter = fs.deprecatedWriter();

    var compressed_stream = std.compress.gzip.compressor(fwriter, .{}) catch |err| {
        std.debug.print("Failed to create gzip compressor: {any}\n", .{err});
        return;
    };

    var buffered_writer = std.io.bufferedWriter(compressed_stream.writer());

    buffered_writer.writer().writeInt(usize, self.edits.count(), .little) catch |err| {
        std.debug.print("Failed to write edit count: {any}\n", .{err});
        return;
    };

    for (self.edits.keys(), self.edits.values()) |idx, atom| {
        buffered_writer.writer().writeInt(usize, idx, .little) catch |err| {
            std.debug.print("Failed to write edit index: {any}\n", .{err});
            return;
        };
        buffered_writer.writer().writeInt(u8, @intFromEnum(atom.material), .little) catch |err| {
            std.debug.print("Failed to write atom material: {any}\n", .{err});
            return;
        };
        buffered_writer.writer().writeAll(atom.color[0..3]) catch |err| {
            std.debug.print("Failed to write atom color: {any}\n", .{err});
            return;
        };
    }

    buffered_writer.flush() catch |err| {
        std.debug.print("Failed to flush gzip compressor: {any}\n", .{err});
        return;
    };

    compressed_stream.finish() catch |err| {
        std.debug.print("Failed to finish gzip compression: {any}\n", .{err});
        return;
    };
}

pub fn load(self: *@This(), coord: [2]isize) void {
    var buf: [256]u8 = @splat(0);

    const name = std.fmt.bufPrint(&buf, "world/{}_{}.chunk.gz", .{
        coord[0], coord[1],
    }) catch {
        std.debug.print("Failed to open file for chunk at {} {}\n", .{
            coord[0], coord[1],
        });
        return;
    };

    var fs = std.fs.cwd().openFile(name, .{}) catch {
        std.debug.print("Failed to open file: {s}\n", .{name});
        return;
    };
    defer fs.close();

    var decompressor = std.compress.gzip.decompressor(fs.deprecatedReader());
    const count = decompressor.reader().readInt(usize, .little) catch |err| {
        std.debug.print("Failed to read edit count: {any}\n", .{err});
        return;
    };

    for (0..count) |_| {
        const idx = decompressor.reader().readInt(usize, .little) catch |err| {
            std.debug.print("Failed to read edit index: {any}\n", .{err});
            return;
        };
        const material = decompressor.reader().readInt(u8, .little) catch |err| {
            std.debug.print("Failed to read atom material: {any}\n", .{err});
            return;
        };
        var color: [3]u8 = undefined;
        _ = decompressor.reader().readAll(&color) catch |err| {
            std.debug.print("Failed to read atom color: {any}\n", .{err});
            return;
        };

        self.edits.put(idx, Atom{
            .material = @enumFromInt(material),
            .color = color,
        }) catch |err| {
            std.debug.print("Failed to put atom in edits: {any}\n", .{err});
            return;
        };

        world.blocks[self.offset + idx] = Atom{
            .material = @enumFromInt(material),
            .color = color,
        };
    }
}
