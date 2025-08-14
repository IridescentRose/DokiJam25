const std = @import("std");
const ecs = @import("../entity/ecs.zig");
const Building = @import("Building.zig");
const Inventory = @import("../inventory.zig");
const Job = @import("Job.zig");
const Voxel = @import("../voxel.zig");
const gfx = @import("../../gfx/gfx.zig");
const world = @import("../world.zig");
const Builder = @import("../ai/dragoons/builder.zig");
const Farmer = @import("../ai/dragoons/farmer.zig");
const Lumber = @import("../ai/dragoons/lumberjack.zig");

town_center: [3]f32,
citizens: [4]ecs.Entity,
buildings: [4]Building,
inventory: Inventory,
job_requests: [4]Job,
farmer_model: Voxel,
builder_model: Voxel,
lumber_model: Voxel,
sleep_model: Voxel,
created: bool = false,

const Self = @This();

pub fn init() !Self {
    const farmer_tex = try gfx.texture.load_image_from_file("dragoon_farmer.png");
    var farmer_model = Voxel.init(farmer_tex);
    try farmer_model.build();

    const builder_tex = try gfx.texture.load_image_from_file("dragoon_builder.png");
    var builder_model = Voxel.init(builder_tex);
    try builder_model.build();

    const lumber_tex = try gfx.texture.load_image_from_file("dragoon_lumber.png");
    var lumber_model = Voxel.init(lumber_tex);
    try lumber_model.build();

    const sleep_tex = try gfx.texture.load_image_from_file("dragoon_sleep.png");
    var sleep_model = Voxel.init(sleep_tex);
    try sleep_model.build();

    return .{
        .citizens = undefined,
        .buildings = undefined,
        .inventory = undefined,
        .job_requests = undefined,
        .farmer_model = farmer_model,
        .builder_model = builder_model,
        .lumber_model = lumber_model,
        .sleep_model = sleep_model,
        .town_center = @splat(0),
    };
}

pub fn deinit(self: *Self) void {
    self.farmer_model.deinit();
    self.builder_model.deinit();
    self.lumber_model.deinit();
    self.sleep_model.deinit();
}

pub fn create(self: *Self, pos: [3]f32) !void {
    if (!self.created) {
        self.town_center = pos;
        std.debug.print("Created town at position: ({}, {}, {})\n", .{ pos[0], pos[1], pos[2] });

        self.citizens[0] = try Builder.create([_]f32{ pos[0] + 1, pos[1] + 1, pos[2] + 1 }, @splat(0), self.builder_model);
        self.citizens[1] = try Lumber.create([_]f32{ pos[0] + 1, pos[1] + 1, pos[2] + 1 }, @splat(0), self.lumber_model);
        self.citizens[2] = try Farmer.create([_]f32{ pos[0] + 1, pos[1] + 1, pos[2] + 1 }, @splat(0), self.farmer_model);

        self.created = true;
    }
}

pub fn update(self: *Self) void {
    if (!self.created) return;

    if (world.tick % 24000 <= 6000 or world.tick % 24000 >= 18000) {
        // Change the models to the sleep model
        self.citizens[0].get_ptr(.model).* = self.sleep_model;
        self.citizens[1].get_ptr(.model).* = self.sleep_model;
        self.citizens[2].get_ptr(.model).* = self.sleep_model;
    } else {
        self.citizens[0].get_ptr(.model).* = self.builder_model;
        self.citizens[1].get_ptr(.model).* = self.lumber_model;
        self.citizens[2].get_ptr(.model).* = self.farmer_model;
    }
}
