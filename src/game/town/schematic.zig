const std = @import("std");
const util = @import("../../core/util.zig");
const Inventory = @import("../inventory.zig").Inventory;

pub const Schematic = struct {
    version: u8,
    size: [3]u32,
    blocks: []u8,

    pub fn index(self: *const Schematic, position: [3]usize) usize {
        // ((Y * size_Z) + Z) * size_X + X
        return ((position[1] * self.size[2]) + position[2]) * self.size[0] + position[0];
    }

    pub fn cost(self: *const Schematic, kind: u8, progress: usize, necessary_materials: *[5]Inventory.Slot) void {
        var unique_count: usize = 0;

        var curr_progress: usize = 0;
        for (0..self.size[1]) |y| {
            for (0..self.size[2]) |z| {
                for (0..self.size[0]) |x| {
                    curr_progress += 1;
                    if (curr_progress < progress) continue;

                    const block_idx = schematics[kind].index([_]usize{ x, y, z });
                    const block_type = schematics[kind].blocks[block_idx];
                    if (block_type != 0) {
                        for (0..unique_count) |i| {
                            if (necessary_materials[i].material == block_type) {
                                necessary_materials[i].count += 1;
                                break;
                            }
                        } else {
                            necessary_materials[unique_count].material = block_type;
                            necessary_materials[unique_count].count = 1;
                            unique_count += 1;
                        }
                    }
                }
            }
        }
    }
};

pub var schematics: [16]Schematic = undefined;

pub fn init() !void {
    schematics[0] = try load_from_json("path.json");
}

pub fn deinit() void {}

pub fn load_from_json(path: []const u8) !Schematic {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const data = try file.readToEndAlloc(util.allocator(), 8192);
    defer util.allocator().free(data);

    const parsed = try std.json.parseFromSlice(Schematic, util.allocator(), data, .{});
    defer parsed.deinit();
    const schematic = parsed.value;

    std.debug.print("SCHEMATIC LOADED: {any}\n", .{schematic});

    return schematic;
}
