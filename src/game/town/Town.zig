const std = @import("std");
const ecs = @import("../entity/ecs.zig");

const BuildingKind = enum(u8) {
    TownHall = 0,
    House = 1,
    Farm = 2,
    Path = 3,
    Fence = 4,
};

const Building = extern struct {
    kind: BuildingKind,
    position: [3]isize,
    is_built: bool,
    progress: usize = 0,
};

const Inventory = @import("../inventory.zig").Inventory;
const Voxel = @import("../voxel.zig");
const gfx = @import("../../gfx/gfx.zig");
const world = @import("../world.zig");
const Builder = @import("../ai/dragoons/builder.zig");
const Farmer = @import("../ai/dragoons/farmer.zig");
const Lumber = @import("../ai/dragoons/lumberjack.zig");
const schematic = @import("schematic.zig");

town_center: [3]f32,
citizens: [4]ecs.Entity,
buildings: [256]Building,
inventory: Inventory,
created: bool = false,
farm_loc: ?[3]f32 = null,
building_count: u32 = 0,
request: [5]Inventory.Slot = @splat(.{
    .material = 0,
    .count = 0,
}),

const Self = @This();

pub fn save_info(self: *Self) !void {
    var file = try std.fs.cwd().createFile("world/town.dat", .{ .truncate = true });
    defer file.close();

    const writer = file.deprecatedWriter();

    // Town Center
    try writer.writeInt(u32, @bitCast(self.town_center[0]), .little);
    try writer.writeInt(u32, @bitCast(self.town_center[1]), .little);
    try writer.writeInt(u32, @bitCast(self.town_center[2]), .little);

    // Villagers
    for (self.citizens) |citizen| {
        try writer.writeInt(u32, @bitCast(citizen.id), .little);
    }

    // Buildings
    for (self.buildings) |building| {
        try writer.writeStruct(building);
    }

    try writer.writeInt(u32, @intFromBool(self.created), .little);

    if (self.farm_loc) |fl| {
        try writer.writeInt(u32, @bitCast(fl[0]), .little);
        try writer.writeInt(u32, @bitCast(fl[1]), .little);
        try writer.writeInt(u32, @bitCast(fl[2]), .little);
    } else {
        try writer.writeInt(u32, 0, .little);
        try writer.writeInt(u32, 0, .little);
        try writer.writeInt(u32, 0, .little);
    }
    try writer.writeInt(u32, self.building_count, .little);

    try writer.writeStruct(self.inventory);
}

pub fn load_info(self: *Self) !void {
    var file = try std.fs.cwd().openFile("world/town.dat", .{});
    defer file.close();

    const reader = file.deprecatedReader();

    // Town Center
    self.town_center[0] = @bitCast(try reader.readInt(u32, .little));
    self.town_center[1] = @bitCast(try reader.readInt(u32, .little));
    self.town_center[2] = @bitCast(try reader.readInt(u32, .little));

    // Villagers
    for (&self.citizens) |*citizen| {
        citizen.id = try reader.readInt(u32, .little);
    }

    // Buildings
    for (&self.buildings) |*building| {
        building.* = try reader.readStruct(Building);
    }

    self.created = try reader.readInt(u32, .little) == 1;

    var loc: [3]f32 = undefined;
    loc[0] = @bitCast(try reader.readInt(u32, .little));
    loc[1] = @bitCast(try reader.readInt(u32, .little));
    loc[2] = @bitCast(try reader.readInt(u32, .little));

    if (loc[0] != 0 and loc[1] != 0 and loc[2] != 0) {
        self.farm_loc = loc;
    }

    self.building_count = try reader.readInt(u32, .little);

    self.inventory = try reader.readStruct(Inventory);
}

pub fn init() !Self {
    try schematic.init();

    var result = Self{
        .citizens = undefined,
        .buildings = @splat(.{
            .kind = .TownHall,
            .position = [3]isize{ 0, 0, 0 },
            .is_built = false,
            .progress = 0,
        }),
        .inventory = Inventory.new(),
        .town_center = @splat(0),
    };
    result.load_info() catch |err| {
        std.debug.print("Failed to load town info: {}\n", .{err});
    };

    return result;
}

pub fn deinit(self: *Self) void {
    schematic.deinit();

    self.save_info() catch |err| {
        std.debug.print("Failed to save town info: {}\n", .{err});
    };
}

pub fn create(self: *Self, pos: [3]f32) !void {
    if (!self.created) {
        self.town_center = pos;
        std.debug.print("Created town at position: ({}, {}, {})\n", .{ pos[0], pos[1], pos[2] });

        self.citizens[0] = try Builder.create([_]f32{ pos[0] + 1, pos[1] + 1, pos[2] + 1 }, @splat(0), [_]isize{ @intFromFloat(pos[0] + 1), @intFromFloat(pos[1] + 1), @intFromFloat(pos[2] + 1) }, .Builder);
        self.citizens[1] = try Lumber.create([_]f32{ pos[0] + 1, pos[1] + 1, pos[2] + 1 }, @splat(0), [_]isize{ @intFromFloat(pos[0] + 1), @intFromFloat(pos[1] + 1), @intFromFloat(pos[2] + 1) }, .Lumberjack);
        self.citizens[2] = try Farmer.create([_]f32{ pos[0] + 1, pos[1] + 1, pos[2] + 1 }, @splat(0), [_]isize{ @intFromFloat(pos[0] + 1), @intFromFloat(pos[1] + 1), @intFromFloat(pos[2] + 1) }, .Farmer);

        self.created = true;
    }
}

pub fn update(self: *Self) void {
    if (!self.created) return;

    if (world.tick % 24000 <= 6000 or world.tick % 24000 >= 18000) {
        // Change the models to the sleep model
        self.citizens[0].get_ptr(.model).* = .Sleep;
        self.citizens[1].get_ptr(.model).* = .Sleep;
        self.citizens[2].get_ptr(.model).* = .Sleep;
    } else {
        self.citizens[0].get_ptr(.model).* = .Builder;
        self.citizens[1].get_ptr(.model).* = .Lumberjack;
        self.citizens[2].get_ptr(.model).* = .Farmer;
    }

    for (0..self.building_count) |i| {
        if (self.buildings[i].is_built) continue;

        self.request = @splat(.{
            .material = 0,
            .count = 0,
        });

        schematic.schematics[@intFromEnum(self.buildings[i].kind)].cost(@intFromEnum(self.buildings[i].kind), self.buildings[i].progress, &self.request);
    }
}
