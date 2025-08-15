const std = @import("std");
const Voxel = @import("voxel.zig");
const Transform = @import("../gfx/transform.zig");
const Camera = @import("../gfx/camera.zig");
const gfx = @import("../gfx/gfx.zig");
const input = @import("../core/input.zig");
const util = @import("../core/util.zig");
const zm = @import("zmath");
const window = @import("../gfx/window.zig");
const world = @import("world.zig");
const c = @import("consts.zig");
const Self = @This();
const AABB = @import("aabb.zig");
const blocks = @import("blocks.zig");
const Inventory = @import("inventory.zig");
const app = @import("../core/app.zig");
const ui = @import("../gfx/ui.zig");
const ecs = @import("entity/ecs.zig");

// Half
const player_size = [_]f32{ 0.5, 1.85, 0.5 };

const GRAVITY = -32;
const TERMINAL_VELOCITY = -50.0;
const BLOCK_SCALE = 1.0 / @as(f32, c.SUB_BLOCKS_PER_BLOCK);
const EPSILON = 1e-3;
const JUMP_VELOCITY = 16.0;
const MOVE_SPEED = 8.6; // 5 units/sec move speed
const KNOCKBACK_STRENGTH = 24.0;

tex: gfx.texture.Texture,
camera: Camera,
moving: [4]bool,
heart_tex: u32,
hotbar_slot_tex: u32,
hotbar_select_tex: u32,
dmg_tex: u32,
button_tex: u32,
button_hover_tex: u32,
block_item_tex: u32,
item_tex: u32,
last_damage: i128,
dead: bool,
spawn_pos: [3]f32 = [_]f32{ 0, 0, 0 }, // Where the player spawns
iframe_time: i128 = 0,
knockback_vel: [3]f32 = .{ 0, 0, 0 },
inventory_open: bool = false, // Whether the inventory is open
block_mode: bool = false, // Whether we are in block mode (can place and break blocks)
voxel_guide: Voxel = undefined,
voxel_guide_transform: Transform = undefined,
voxel_guide_transform_place: Transform = undefined,
voxel_tex: gfx.texture.Texture,

// TODO: make a component so that dragoons can have different inventories
inventory: Inventory,
entity: ecs.Entity,

pub fn init() !Self {
    var res: Self = undefined;

    res.tex = try gfx.texture.load_image_from_file("doki.png");
    res.entity = try ecs.create_entity(.player);

    var transform = Transform.new();
    transform.size = [_]f32{ 20.0, -4.01, 20.0 };
    transform.scale = @splat(1.0 / 10.0);

    var voxel = Voxel.init(res.tex);
    try voxel.build();
    try res.entity.add_component(.model, voxel);
    try res.entity.add_component(.transform, transform);
    try res.entity.add_component(.velocity, @splat(0));
    try res.entity.add_component(.on_ground, false);
    try res.entity.add_component(.health, 17);
    try res.entity.add_component(.aabb, AABB{
        .aabb_size = player_size,
        .can_step = true,
    });

    res.camera = .{
        .distance = 5.0,
        .fov = 90.0,
        .yaw = -90,
        .pitch = 0,
        .target = transform.pos,
    };

    res.heart_tex = try ui.load_ui_texture("heart.png");
    res.dmg_tex = try ui.load_ui_texture("dmg.png");
    res.hotbar_slot_tex = try ui.load_ui_texture("slot.png");
    res.hotbar_select_tex = try ui.load_ui_texture("selector.png");
    res.button_tex = try ui.load_ui_texture("button.png");
    res.button_hover_tex = try ui.load_ui_texture("button_hover.png");
    res.block_item_tex = try ui.load_ui_texture("b_items.png");
    res.item_tex = try ui.load_ui_texture("items.png");
    res.last_damage = 0;
    res.moving = @splat(false);
    // TODO: ECS this
    res.inventory = Inventory.new();
    res.inventory.slots[0] = .{
        .material = 257, // Cooked steak,
        .count = 64,
    };
    res.inventory.slots[1] = .{
        .material = 258, // Matches,
        .count = 64,
    };
    res.inventory.slots[2] = .{
        .material = 14, // Town block
        .count = 512,
    };

    res.voxel_tex = try gfx.texture.load_image_from_file("dot.png");
    res.voxel_guide = Voxel.init(res.voxel_tex);
    res.voxel_guide_transform = Transform.new();
    res.voxel_guide_transform.size = @splat(-1.0);
    res.voxel_guide_transform_place = Transform.new();
    res.block_mode = false;
    try res.voxel_guide.build();

    // TODO: ECS this
    res.knockback_vel = @splat(0);
    res.inventory_open = false;
    res.dead = false;

    return res;
}

const debugging_pause = false;

fn moveForward(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    var self = util.ctx_to_self(Self, ctx);
    self.moving[0] = down;
}
fn moveBackward(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    var self = util.ctx_to_self(Self, ctx);
    self.moving[1] = down;
}
fn moveLeft(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    var self = util.ctx_to_self(Self, ctx);
    self.moving[2] = down;
}
fn moveRight(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    var self = util.ctx_to_self(Self, ctx);
    self.moving[3] = down;
}

fn jump(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    const self = util.ctx_to_self(Self, ctx);
    if (down and self.entity.get(.on_ground)) {
        self.entity.get_ptr(.velocity)[1] = JUMP_VELOCITY;
        self.entity.get_ptr(.on_ground).* = false;
    }
}

fn increment_hotbar(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (down) {
        const self = util.ctx_to_self(Self, ctx);
        self.inventory.increment_hotbar();
    }
}

fn decrement_hotbar(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (down) {
        const self = util.ctx_to_self(Self, ctx);
        self.inventory.decrement_hotbar();
    }
}

const sensitivity = 0.1;

fn mouseCb(ctx: *anyopaque, dx: f32, dy: f32) void {
    if (world.paused and !debugging_pause) return;
    var self = util.ctx_to_self(Self, ctx);
    if (self.inventory_open) return;

    self.camera.yaw += dx * sensitivity;
    self.camera.pitch += dy * sensitivity;

    if (self.block_mode) {
        if (self.camera.pitch > 89.0) self.camera.pitch = 89.0;
        if (self.camera.pitch < -89.0) self.camera.pitch = -89.0;
    } else {
        if (self.camera.pitch > 60.0) self.camera.pitch = 60.0;
        if (self.camera.pitch < -60.0) self.camera.pitch = -60.0;
    }
}

fn place_block(self: *Self) void {
    const coord = [_]isize{
        @intFromFloat(self.voxel_guide_transform_place.pos[0]),
        @intFromFloat(self.voxel_guide_transform_place.pos[1]),
        @intFromFloat(self.voxel_guide_transform_place.pos[2]),
    };
    std.debug.print("Coords to break: {d}, {d}, {d}\n", .{ coord[0], coord[1], coord[2] });

    const rescaled_subvoxel = [3]isize{ coord[0] * c.SUB_BLOCKS_PER_BLOCK, coord[1] * c.SUB_BLOCKS_PER_BLOCK, coord[2] * c.SUB_BLOCKS_PER_BLOCK };

    const hand = self.inventory.get_hand_slot();
    if (hand.material == 256 or hand.material == 257) {
        // FOOD EATING
        // TODO: MOVE THIS
        self.entity.get_ptr(.health).* += @intCast(4 * (hand.material - 255)); // Heal 2-4 hearts on meat
        if (self.entity.get_ptr(.health).* > 20) {
            self.entity.get_ptr(.health).* = 20; // Clamp to max health
        }
        hand.count -= 1;
        if (hand.count == 0) {
            hand.material = 0; // Remove item from hand
        }
    }

    var town_placed = false;
    if (hand.material == 14) {
        town_placed = true;

        // Give them a farm
        hand.material = 15;
        hand.count = 64;
        world.town.create(self.voxel_guide_transform_place.pos) catch unreachable;
        return;
    }

    if (hand.material == 15) {
        world.town.farm_loc = self.voxel_guide_transform_place.pos;
        hand.material = 0;
        hand.count = 0;
        return;
    }

    var sub_hand = true;
    for (0..c.SUB_BLOCKS_PER_BLOCK) |y| {
        for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
            for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                const ix: isize = @intCast(x);
                const iy: isize = @intCast(y);
                const iz: isize = @intCast(z);

                const test_coord = [3]isize{ rescaled_subvoxel[0] + ix, rescaled_subvoxel[1] + iy, rescaled_subvoxel[2] + iz };
                const voxel = world.get_voxel(test_coord);
                if (voxel == .Air) {
                    const stidx = blocks.stencil_index([3]usize{ x, y, z });

                    if (hand.count > 0 and (hand.material < 256 or hand.material == 258)) { // Don't place items that are not blocks (will have exceptions later)
                        if (hand.material == 258) {
                            // Matches light fire.
                            if (world.set_voxel(test_coord, .{
                                .material = .Fire,
                                .color = [_]u8{ 0xFF, 0x81, 0x42 },
                            })) {
                                if (sub_hand) {
                                    sub_hand = false;
                                    hand.count -= 1;
                                    if (hand.count == 0) hand.material = 0;
                                }

                                world.active_atoms.append(.{
                                    .coord = test_coord,
                                    .moves = 255,
                                }) catch break;
                            }
                        } else {
                            const stencil = blocks.registry[hand.material];
                            if (world.set_voxel(test_coord, stencil[stidx])) {
                                hand.count -= 1;
                                if (hand.count == 0) hand.material = 0;
                            }
                        }
                    } else {
                        break;
                    }
                }
            }
        }
    }
}

fn right_click(ctx: *anyopaque, down: bool) void {
    if (!down) return;
    if (world.paused and !debugging_pause) return;

    const self = util.ctx_to_self(Self, ctx);
    if (self.dead) return;

    if (self.inventory_open) {
        const min_x = 8.0;
        const max_x = 8.0 + 60.0 * 4;
        const max_y = ui.UI_RESOLUTION[1] - 114.0;
        const min_y = max_y - 60.0 * Inventory.HOTBAR_SIZE;

        const mouse_pos = input.get_mouse_position();
        if (mouse_pos[0] >= min_x and mouse_pos[0] <= max_x and
            mouse_pos[1] >= min_y and mouse_pos[1] <= max_y)
        {
            const slot_x = @as(usize, @intFromFloat((mouse_pos[0] - min_x) / 60.0));
            const slot_y = @as(usize, @intFromFloat((max_y - mouse_pos[1]) / 60.0));
            std.debug.print("Clicked on inventory slot: {d}, {d}\n", .{ slot_x, slot_y });

            const slot_idx = slot_y + slot_x * Inventory.HOTBAR_SIZE;
            std.debug.print("Clicked on inventory slot index: {d}\n", .{slot_idx});

            if (self.inventory.slots[slot_idx].material != 0) {
                if (self.inventory.mouse_slot.material == 0 or
                    self.inventory.slots[slot_idx].material == self.inventory.mouse_slot.material)
                {
                    // Move half from slot to mouse
                    const amount = self.inventory.slots[slot_idx].count / 2;
                    self.inventory.slots[slot_idx].count -= amount;
                    if (self.inventory.slots[slot_idx].count == 0) self.inventory.slots[slot_idx].material = 0;
                    if (self.inventory.mouse_slot.material == 0) {
                        self.inventory.mouse_slot.material = self.inventory.slots[slot_idx].material;
                    }
                    self.inventory.mouse_slot.count += amount;
                }
            }
        }

        return;
    }

    if (self.block_mode) self.place_block();
}

fn pause_mouse() void {
    const mouse_pos = input.get_mouse_position();

    // Resume
    if (mouse_pos[0] >= ui.UI_RESOLUTION[0] / 2 - 96 * 7 / 2 and
        mouse_pos[0] <= ui.UI_RESOLUTION[0] / 2 + 96 * 7 / 2 and
        mouse_pos[1] >= ui.UI_RESOLUTION[1] / 2 + 32 - 12 * 7 / 2 and
        mouse_pos[1] <= ui.UI_RESOLUTION[1] / 2 + 32 + 12 * 7 / 2)
    {
        world.paused = !world.paused;
        window.set_relative(true) catch unreachable;
    }

    // Quit (which triggers save)
    if (mouse_pos[0] >= ui.UI_RESOLUTION[0] / 2 - 96 * 7 / 2 and
        mouse_pos[0] <= ui.UI_RESOLUTION[0] / 2 + 96 * 7 / 2 and
        mouse_pos[1] >= ui.UI_RESOLUTION[1] / 2 - 128 - 12 * 7 / 2 and
        mouse_pos[1] <= ui.UI_RESOLUTION[1] / 2 - 128 + 12 * 7 / 2)
    {
        app.running = false;
    }
    return;
}

// Hah, get it? Dead mouse, deadmau5?
fn deadmau5(self: *Self) void {
    const mouse_pos = input.get_mouse_position();
    if (mouse_pos[0] >= ui.UI_RESOLUTION[0] / 2 - 96 * 7 / 2 and
        mouse_pos[0] <= ui.UI_RESOLUTION[0] / 2 + 96 * 7 / 2 and
        mouse_pos[1] >= ui.UI_RESOLUTION[1] / 2 - 168 - 12 * 7 / 2 and
        mouse_pos[1] <= ui.UI_RESOLUTION[1] / 2 - 168 + 12 * 7 / 2)
    {
        self.dead = false;
        self.entity.get_ptr(.health).* = 20;
        self.entity.get_ptr(.transform).pos = self.spawn_pos;
        window.set_relative(true) catch unreachable;
    }
}

fn toggle_inventory(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (down) {
        const self = util.ctx_to_self(Self, ctx);
        self.inventory_open = !self.inventory_open;
        if (self.inventory_open) {
            window.set_relative(false) catch unreachable;
        } else {
            window.set_relative(true) catch unreachable;
        }
    }
}

fn break_block(self: *Self) void {
    // This is the bottom left corner of the voxel we are looking at
    const coord = [_]isize{
        @intFromFloat(self.voxel_guide_transform.pos[0]),
        @intFromFloat(self.voxel_guide_transform.pos[1]),
        @intFromFloat(self.voxel_guide_transform.pos[2]),
    };
    std.debug.print("Coords to break: {d}, {d}, {d}\n", .{ coord[0], coord[1], coord[2] });

    const rescaled_subvoxel = [3]isize{ coord[0] * c.SUB_BLOCKS_PER_BLOCK, coord[1] * c.SUB_BLOCKS_PER_BLOCK, coord[2] * c.SUB_BLOCKS_PER_BLOCK };

    for (0..c.SUB_BLOCKS_PER_BLOCK) |y| {
        for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
            for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                const ix: isize = @intCast(x);
                const iy: isize = @intCast(y);
                const iz: isize = @intCast(z);

                const test_coord = [3]isize{ rescaled_subvoxel[0] + ix, rescaled_subvoxel[1] + iy, rescaled_subvoxel[2] + iz };
                const voxel = world.get_voxel(test_coord);

                // Unobtainable blocks
                if (voxel != .Air and voxel != .Water and voxel != .StillWater and voxel != .Bedrock) {
                    const atom_type = voxel;

                    if (voxel != .Fire and voxel != .Crop) {
                        var mat = atom_type;

                        // Grass can't be harvested, turns into dirt
                        if (voxel == .Grass) {
                            mat = .Dirt;
                        }

                        const amt = self.inventory.add_item_inventory(.{ .material = @intFromEnum(mat), .count = 1 });
                        if (amt == 0) {
                            std.debug.print("Inventory full, could not add item: {s}\n", .{@tagName(atom_type)});
                            std.debug.print("Tried to add item at coord: {d}, {d}, {d}\n", .{ test_coord[0], test_coord[1], test_coord[2] });
                            return;
                        }
                    }

                    if (!world.set_voxel(test_coord, .{
                        .material = .Air,
                        .color = [_]u8{ 0, 0, 0 },
                    })) {
                        std.debug.print("Failed to remove voxel at coord: {d}, {d}, {d}\n", .{ test_coord[0], test_coord[1], test_coord[2] });
                    }
                }
            }
        }
    }
}

fn left_click(ctx: *anyopaque, down: bool) void {
    if (!down) return;

    if (world.paused and !debugging_pause) pause_mouse();

    const self = util.ctx_to_self(Self, ctx);

    if (self.dead) self.deadmau5();

    if (self.inventory_open) {
        const min_x = 8.0;
        const max_x = 8.0 + 60.0 * 4;
        const max_y = ui.UI_RESOLUTION[1] - 114.0;
        const min_y = max_y - 60.0 * Inventory.HOTBAR_SIZE;

        const mouse_pos = input.get_mouse_position();
        if (mouse_pos[0] >= min_x and mouse_pos[0] <= max_x and
            mouse_pos[1] >= min_y and mouse_pos[1] <= max_y)
        {
            const slot_x = @as(usize, @intFromFloat((mouse_pos[0] - min_x) / 60.0));
            const slot_y = @as(usize, @intFromFloat((max_y - mouse_pos[1]) / 60.0));
            std.debug.print("Clicked on inventory slot: {d}, {d}\n", .{ slot_x, slot_y });

            const slot_idx = slot_y + slot_x * Inventory.HOTBAR_SIZE;

            if (self.inventory.mouse_slot.material != 0) {
                if (self.inventory.slots[slot_idx].material == 0) {
                    // Just place all
                    self.inventory.slots[slot_idx] = self.inventory.mouse_slot;
                    self.inventory.mouse_slot = .{ .material = 0, .count = 0 };
                } else if (self.inventory.slots[slot_idx].material == self.inventory.mouse_slot.material) {
                    // Move as many as possible
                    const amt = @min(self.inventory.mouse_slot.count, Inventory.MAX_ITEMS_PER_SLOT - self.inventory.slots[slot_idx].count);
                    self.inventory.mouse_slot.count -= amt;
                    self.inventory.slots[slot_idx].count += amt;

                    if (self.inventory.mouse_slot.count == 0) {
                        self.inventory.mouse_slot.material = 0;
                    }
                }
            } else {
                // We're empty, take everything from the clicked slot
                if (self.inventory.slots[slot_idx].material != 0) {
                    self.inventory.mouse_slot = self.inventory.slots[slot_idx];
                    self.inventory.slots[slot_idx] = .{ .material = 0, .count = 0 };
                }
            }
        }

        return;
    }

    if (self.block_mode) self.break_block();
}

fn pause(ctx: *anyopaque, down: bool) void {
    const self = util.ctx_to_self(Self, ctx);
    if (down and !self.dead) {
        world.paused = !world.paused;
        if (world.paused) {
            std.debug.print("Game paused\n", .{});

            if (self.inventory_open) {
                self.inventory_open = false; // Close inventory if paused
            }

            window.set_relative(false) catch unreachable;
        } else {
            std.debug.print("Game unpaused\n", .{});
            // TODO: Based on overlay state
            window.set_relative(true) catch unreachable;
        }
    }
}

fn set_hotbar_slot1(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    self.inventory.hotbarIdx = 0;
}

fn set_hotbar_slot2(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    self.inventory.hotbarIdx = 1;
}

fn set_hotbar_slot3(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    self.inventory.hotbarIdx = 2;
}

fn set_hotbar_slot4(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    self.inventory.hotbarIdx = 3;
}

fn set_hotbar_slot5(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    self.inventory.hotbarIdx = 4;
}

fn set_hotbar_slot6(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    self.inventory.hotbarIdx = 5;
}

fn set_hotbar_slot7(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    self.inventory.hotbarIdx = 6;
}

fn set_hotbar_slot8(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    self.inventory.hotbarIdx = 7;
}

fn toggle_break_mode(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (down) {
        const self = util.ctx_to_self(Self, ctx);
        self.block_mode = !self.block_mode;
    }
}

pub fn register_input(self: *Self) !void {
    try input.register_key_callback(.w, .{
        .ctx = self,
        .cb = moveForward,
    });
    try input.register_key_callback(.a, .{
        .ctx = self,
        .cb = moveLeft,
    });
    try input.register_key_callback(.s, .{
        .ctx = self,
        .cb = moveBackward,
    });
    try input.register_key_callback(.d, .{
        .ctx = self,
        .cb = moveRight,
    });
    try input.register_key_callback(.space, .{
        .ctx = self,
        .cb = jump,
    });
    try input.register_key_callback(.escape, .{
        .ctx = self,
        .cb = pause,
    });
    try input.register_key_callback(.e, .{
        .ctx = self,
        .cb = increment_hotbar,
    });
    try input.register_key_callback(.q, .{
        .ctx = self,
        .cb = decrement_hotbar,
    });
    try input.register_key_callback(.f, .{
        .ctx = self,
        .cb = toggle_break_mode,
    });

    try input.register_key_callback(.one, .{
        .ctx = self,
        .cb = set_hotbar_slot1,
    });

    try input.register_key_callback(.two, .{
        .ctx = self,
        .cb = set_hotbar_slot2,
    });

    try input.register_key_callback(.three, .{
        .ctx = self,
        .cb = set_hotbar_slot3,
    });

    try input.register_key_callback(.four, .{
        .ctx = self,
        .cb = set_hotbar_slot4,
    });

    try input.register_key_callback(.five, .{
        .ctx = self,
        .cb = set_hotbar_slot5,
    });

    try input.register_key_callback(.six, .{
        .ctx = self,
        .cb = set_hotbar_slot6,
    });

    try input.register_key_callback(.seven, .{
        .ctx = self,
        .cb = set_hotbar_slot7,
    });

    try input.register_key_callback(.eight, .{
        .ctx = self,
        .cb = set_hotbar_slot8,
    });

    try input.register_key_callback(.i, .{
        .cb = toggle_inventory,
        .ctx = self,
    });

    input.mouse_relative_handle = .{
        .ctx = self,
        .cb = mouseCb,
    };

    try input.register_mouse_callback(.left, .{
        .ctx = self,
        .cb = left_click,
    });
    try input.register_mouse_callback(.right, .{
        .ctx = self,
        .cb = right_click,
    });

    if (!world.paused)
        try window.set_relative(true);
}

pub fn deinit(self: *Self) void {
    self.voxel_guide.deinit();
    self.entity.get_ptr(.model).deinit();
}

fn signi(x: f32) i32 {
    return if (x > 0) 1 else if (x < 0) -1 else 0;
}

fn inf() f32 {
    return std.math.inf(f32);
}

fn ray_from_camera_center(view: zm.Mat) struct { origin: [3]f32, dir: [3]f32 } {
    const inv = zm.inverse(view);

    // Correct order: row-vector * matrix
    const o4 = zm.mul(zm.f32x4(0.0, 0.0, 0.0, 1.0), inv);
    const origin: [3]f32 = [_]f32{ o4[0], o4[1], o4[2] };

    // Direction is transformed as a vector (w = 0)
    const f4 = zm.mul(zm.f32x4(0.0, 0.0, -1.0, 0.0), inv);
    var dir: [3]f32 = [_]f32{ f4[0], f4[1], f4[2] };

    const len = std.math.sqrt(dir[0] * dir[0] + dir[1] * dir[1] + dir[2] * dir[2]);
    if (len != 0) {
        dir[0] /= len;
        dir[1] /= len;
        dir[2] /= len;
    }
    return .{ .origin = origin, .dir = dir };
}

/// Grid DDA in subvoxel space. Returns subvoxel coords of first solid cell, or null.
/// DDA in (your current) grid space; returns first solid hit and the last empty cell before it.
/// Also returns the face normal (grid step) of the hit.
fn raycast_hit_with_prev(origin_ws: [3]f32, dir_ws: [3]f32, max_dist_ws: f32) ?struct { hit: [3]isize, prev: [3]isize, face: [3]i32 } {
    const SUB = c.SUB_BLOCKS_PER_BLOCK;

    // --- origin & direction in the same grid the loop uses (your current code) ---
    const o = [_]f32{ origin_ws[0] * SUB, origin_ws[1] * SUB, origin_ws[2] * SUB };

    var d = [_]f32{ dir_ws[0], dir_ws[1], dir_ws[2] };
    const dlen = std.math.sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]);
    if (dlen == 0) return null;
    d[0] /= dlen;
    d[1] /= dlen;
    d[2] /= dlen;

    var voxel = [_]isize{
        @intFromFloat(@floor(o[0])),
        @intFromFloat(@floor(o[1])),
        @intFromFloat(@floor(o[2])),
    };

    const step = [_]i32{ signi(d[0]), signi(d[1]), signi(d[2]) };

    var tMax = [_]f32{ inf(), inf(), inf() };
    var tDel = [_]f32{ inf(), inf(), inf() };

    inline for (0..3) |i| {
        if (d[i] != 0) {
            const invDir = 1.0 / d[i];
            const v_border = if (step[i] > 0)
                (@as(f32, @floatFromInt(voxel[i])) + 1.0)
            else
                (@as(f32, @floatFromInt(voxel[i])));
            tMax[i] = (v_border - o[i]) * invDir; // param in "voxel units" per your current math
            tDel[i] = @abs(invDir);
        }
    }

    const max_t = max_dist_ws * SUB;
    const MAX_STEPS: usize = 4096;

    // Track last empty cell and the face normal of the hit
    var prev_empty = voxel; // initialized to start cell; corrected below if needed
    var hit_face: [3]i32 = .{ 0, 0, 0 };

    // If we start inside solid: report this voxel as hit, and synthesize prev by stepping back
    if (world.is_in_world(voxel) and world.get_voxel(voxel) != .Air) {
        // Choose the axis you would cross first, then step one cell backward along that axis
        var axis: usize = 0;
        if (tMax[1] < tMax[axis]) axis = 1;
        if (tMax[2] < tMax[axis]) axis = 2;

        prev_empty = .{ voxel[0] - step[axis], voxel[1] - step[1], voxel[2] - step[2] };
        hit_face = .{ step[0], step[1], step[2] };
        return .{ .hit = voxel, .prev = prev_empty, .face = hit_face };
    }

    var t: f32 = 0.0;
    var step_count: usize = 0;
    while (step_count < MAX_STEPS and t <= max_t) : (step_count += 1) {
        // choose axis
        var axis: usize = 0;
        if (tMax[1] < tMax[axis]) axis = 1;
        if (tMax[2] < tMax[axis]) axis = 2;

        // advance
        t = tMax[axis];
        tMax[axis] += tDel[axis];

        // record the empty cell we were in before stepping
        prev_empty = voxel;

        voxel[axis] += step[axis];
        if (t > max_t or !world.is_in_world(voxel)) break;

        if (world.get_voxel(voxel) != .Air) {
            // Hit! prev_empty is the placement cell. Face normal is the step direction.
            hit_face = .{ 0, 0, 0 };
            hit_face[axis] = step[axis];
            return .{ .hit = voxel, .prev = prev_empty, .face = hit_face };
        }
    }
    return null;
}

pub fn place_voxel_guide(self: *Self) void {
    if (!self.block_mode) {
        self.voxel_guide_transform.pos = .{ 0, -1000, 0 };
        return;
    }

    const view = self.camera.get_view_matrix();
    const ray = ray_from_camera_center(view);
    const MAX_REACH: f32 = 16.0;

    const result = raycast_hit_with_prev(ray.origin, ray.dir, MAX_REACH);
    if (result) |rp| {
        self.voxel_guide_transform.pos = .{
            @floor(@as(f32, @floatFromInt(rp.hit[0])) / c.SUB_BLOCKS_PER_BLOCK),
            @floor(@as(f32, @floatFromInt(rp.hit[1])) / c.SUB_BLOCKS_PER_BLOCK),
            @floor(@as(f32, @floatFromInt(rp.hit[2])) / c.SUB_BLOCKS_PER_BLOCK),
        };
        self.voxel_guide_transform_place.pos = .{
            @floor(@as(f32, @floatFromInt(rp.prev[0])) / c.SUB_BLOCKS_PER_BLOCK),
            @floor(@as(f32, @floatFromInt(rp.prev[1])) / c.SUB_BLOCKS_PER_BLOCK),
            @floor(@as(f32, @floatFromInt(rp.prev[2])) / c.SUB_BLOCKS_PER_BLOCK),
        };
        self.voxel_guide_transform.scale = @splat(1.02);
    } else {
        self.voxel_guide_transform.pos = .{ 0, -1000, 0 };
        self.voxel_guide_transform_place.pos = .{ 0, -1000, 0 };
    }
}

pub fn update(self: *Self) void {
    self.place_voxel_guide();

    if (self.block_mode) {
        self.camera.fpv = true;
    } else {
        self.camera.fpv = false;
    }

    // Update camera
    self.camera.target = self.entity.get(.transform).pos;
    self.camera.target[1] += player_size[1] + 0.25;
    self.camera.distance = 5.0 + @as(f32, @floatFromInt(input.scroll_pos)) * 0.5;

    const curr_pos = [_]isize{
        @intFromFloat(self.entity.get(.transform).pos[0]),
        @intFromFloat(@max(@min(self.entity.get(.transform).pos[1], 62.0), 0)), // Clamp y to world height
        @intFromFloat(self.entity.get(.transform).pos[2]),
    };

    if (!world.is_in_world([_]isize{ curr_pos[0] * c.SUB_BLOCKS_PER_BLOCK, curr_pos[1] * c.SUB_BLOCKS_PER_BLOCK, curr_pos[2] * c.SUB_BLOCKS_PER_BLOCK })) return;

    if (world.paused and !debugging_pause) return;
    if (self.dead) return;

    const dt: f32 = 1.0 / 60.0;

    // 1) Build movement vector from input & camera
    const radYaw = std.math.degreesToRadians(-self.camera.yaw - 90.0);
    const forward = zm.normalize3(.{ std.math.sin(radYaw), 0, std.math.cos(radYaw), 0 });
    const right = zm.normalize3(zm.cross3(forward, .{ 0, 1, 0, 0 }));

    var movement: @Vector(4, f32) = .{ 0, 0, 0, 0 };
    if (!self.inventory_open) {
        if (self.moving[0]) movement += forward;
        if (self.moving[1]) movement -= forward;
        if (self.moving[2]) movement -= right;
        if (self.moving[3]) movement += right;
        if (zm.length3(movement)[0] > 0.1) {
            movement = zm.normalize3(movement) * @as(@Vector(4, f32), @splat(MOVE_SPEED)); // 5 units/sec move speed
            self.entity.get_ptr(.transform).rot[1] = std.math.radiansToDegrees(std.math.atan2(movement[0], movement[2])) + 180.0;
        }
    }

    // 2) Prepare new velocity
    var vel = self.entity.get_ptr(.velocity);
    vel[0] = movement[0] + self.knockback_vel[0];
    vel[2] = movement[2] + self.knockback_vel[2];
    vel[1] += GRAVITY * dt + self.knockback_vel[1] * 1.0 / KNOCKBACK_STRENGTH;

    if (vel[1] < TERMINAL_VELOCITY) vel[1] = TERMINAL_VELOCITY;

    const decay = std.math.exp(-4.0 * dt);
    self.knockback_vel[0] *= decay;
    self.knockback_vel[1] *= decay;
    self.knockback_vel[2] *= decay;
}

pub fn do_damage(self: *Self, amount: u8, direction: [3]f32) void {
    const health = self.entity.get_ptr(.health);

    self.last_damage = std.time.nanoTimestamp();
    if (health.* > 0 and self.last_damage > self.iframe_time) {
        health.* -|= amount;
        self.iframe_time = self.last_damage + 250 * std.time.ns_per_ms; // 250ms of invulnerability

        const damage_dir = zm.Vec{ direction[0], direction[1], direction[2], 0 };
        const normalized_dir = zm.normalize3(damage_dir);
        self.knockback_vel = [_]f32{ normalized_dir[0] * KNOCKBACK_STRENGTH, (normalized_dir[1] + 1) * KNOCKBACK_STRENGTH, normalized_dir[2] * KNOCKBACK_STRENGTH }; // Knockback
    }

    if (health.* == 0 and !self.dead) {
        self.dead = true;
        window.set_relative(false) catch unreachable;
        std.debug.print("You died!\n", .{});
    }
}

pub fn draw(self: *Self, shadow: bool) void {
    if (!self.block_mode) {
        if (shadow) {
            gfx.shader.use_shadow_shader();
            gfx.shader.set_shadow_model(self.entity.get(.transform).get_matrix());
            self.entity.get_ptr(.model).draw();
        } else {
            gfx.shader.use_render_shader();
            gfx.shader.set_model(self.entity.get(.transform).get_matrix());
            self.entity.get_ptr(.model).draw();
        }
    }

    if (shadow) return; // Don't draw UI in shadow pass

    self.voxel_guide_transform.pos[0] -= 0.01;
    self.voxel_guide_transform.pos[1] -= 0.01;
    self.voxel_guide_transform.pos[2] -= 0.01;
    gfx.shader.set_model(self.voxel_guide_transform.get_matrix());
    self.voxel_guide_transform.pos[0] += 0.01;
    self.voxel_guide_transform.pos[1] += 0.01;
    self.voxel_guide_transform.pos[2] += 0.01;
    self.voxel_guide.draw();

    self.camera.update();

    for (0..10) |i| {
        const i_f = @as(f32, @floatFromInt(i));
        const position = [_]f32{ 30.0 + i_f * 48.0, ui.UI_RESOLUTION[1] - 30.0, 2.0 + 0.01 * i_f };

        const half_heart_offset = [_]f32{ 0.0, 0.0 };
        const full_heart_offset = [_]f32{ 0.0, 0.5 };
        const base_heart_offset = [_]f32{ 0.5, 0.5 };

        var offset = half_heart_offset;
        // Draw hearts
        if (self.entity.get(.health) > i * 2) {
            if (self.entity.get(.health) > i * 2 + 1) {
                offset = full_heart_offset;
            } else {
                offset = half_heart_offset;
            }
        } else {
            offset = base_heart_offset;
        }

        ui.add_sprite(.{
            .color = [_]u8{ 255, 255, 255, 255 },
            .offset = position,
            .scale = [_]f32{ 48.0, 48.0 },
            .tex_id = self.heart_tex,
            .uv_offset = offset,
            .uv_scale = [_]f32{ 0.5, 0.5 },
        }) catch unreachable;
    }

    for (0..Inventory.HOTBAR_SIZE) |j| {
        const hotbar_slot_pos = [_]f32{ 38, ui.UI_RESOLUTION[1] - 144 - @as(f32, @floatFromInt(j)) * 60.0, 2.0 + 0.01 * @as(f32, @floatFromInt(j)) };
        ui.add_sprite(.{
            .color = [_]u8{ 255, 255, 255, 255 },
            .offset = hotbar_slot_pos,
            .scale = [_]f32{ 60.0, 60.0 },
            .tex_id = self.hotbar_slot_tex,
            .uv_offset = [_]f32{ 0.0, 0.0 },
            .uv_scale = [_]f32{ 1.0, 1.0 },
        }) catch unreachable;

        const item = self.inventory.slots[j];

        if (item.count > 0 and item.material != 0) {
            const item_pos = [_]f32{ hotbar_slot_pos[0], hotbar_slot_pos[1], hotbar_slot_pos[2] + 0.01 };

            var tex = self.block_item_tex;

            var buf: [8]u8 = @splat(0);
            var count = if (item.count / 128 != 0) std.fmt.bufPrint(buf[0..], "{d}", .{item.count / 128}) catch "ERR" else "<1";
            if (item.material > 256) {
                tex = self.item_tex;
                // If it's an item, the count is going to be the full count, not divided by 128
                count = std.fmt.bufPrint(buf[0..], "{d}", .{item.count}) catch "ERR";
            }

            ui.add_sprite(.{
                .color = [_]u8{ 255, 255, 255, 255 },
                .offset = item_pos,
                .scale = [_]f32{ 48.0, 48.0 },
                .tex_id = tex,
                .uv_offset = [_]f32{ 1.0 / 16.0 * @as(f32, @floatFromInt(item.material % 16)), 15.0 / 16.0 },
                .uv_scale = @splat(1.0 / 16.0),
            }) catch unreachable;

            ui.add_text(
                count,
                [_]f32{ item_pos[0] + 20.0, item_pos[1] - 20.0 },
                [_]u8{ 255, 255, 255, 255 },
                2.0,
                1.0,
                .Right,
            ) catch unreachable;
        }
    }

    if (self.inventory_open) {
        for (0..(Inventory.MAX_SLOTS / Inventory.HOTBAR_SIZE - 1)) |k| {
            for (0..Inventory.HOTBAR_SIZE) |j| {
                const hotbar_slot_pos = [_]f32{ 38.0 + 60.0 * @as(f32, @floatFromInt(k + 1)), ui.UI_RESOLUTION[1] - 144 - @as(f32, @floatFromInt(j)) * 60.0, 2.0 + 0.01 * @as(f32, @floatFromInt(j)) };
                ui.add_sprite(.{
                    .color = [_]u8{ 255, 255, 255, 255 },
                    .offset = hotbar_slot_pos,
                    .scale = [_]f32{ 60.0, 60.0 },
                    .tex_id = self.hotbar_slot_tex,
                    .uv_offset = [_]f32{ 0.0, 0.0 },
                    .uv_scale = [_]f32{ 1.0, 1.0 },
                }) catch unreachable;

                const item = self.inventory.slots[j + (k + 1) * Inventory.HOTBAR_SIZE];

                if (item.count > 0 and item.material != 0) {
                    const item_pos = [_]f32{ hotbar_slot_pos[0], hotbar_slot_pos[1], hotbar_slot_pos[2] + 0.01 };

                    var tex = self.block_item_tex;

                    var buf: [8]u8 = @splat(0);
                    var count = if (item.count / 128 != 0) std.fmt.bufPrint(buf[0..], "{d}", .{item.count / 128}) catch "ERR" else "<1";
                    if (item.material > 256) {
                        tex = self.item_tex;
                        // If it's an item, the count is going to be the full count, not divided by 128
                        count = std.fmt.bufPrint(buf[0..], "{d}", .{item.count}) catch "ERR";
                    }

                    ui.add_sprite(.{
                        .color = [_]u8{ 255, 255, 255, 255 },
                        .offset = item_pos,
                        .scale = [_]f32{ 48.0, 48.0 },
                        .tex_id = tex,
                        .uv_offset = [_]f32{ 1.0 / 16.0 * @as(f32, @floatFromInt(item.material % 16)), 15.0 / 16.0 },
                        .uv_scale = @splat(1.0 / 16.0),
                    }) catch unreachable;

                    ui.add_text(
                        count,
                        [_]f32{ item_pos[0] + 20.0, item_pos[1] - 20.0 },
                        [_]u8{ 255, 255, 255, 255 },
                        2.0,
                        1.0,
                        .Right,
                    ) catch unreachable;
                }
            }
        }

        if (self.inventory.mouse_slot.material != 0 and self.inventory.mouse_slot.count != 0) {
            const mouse_pos = input.get_mouse_position();
            const item_pos = [_]f32{ mouse_pos[0], mouse_pos[1], 2 + 0.01 };

            var tex = self.block_item_tex;

            var buf: [8]u8 = @splat(0);
            var count = if (self.inventory.mouse_slot.count / 128 != 0) std.fmt.bufPrint(buf[0..], "{d}", .{self.inventory.mouse_slot.count / 128}) catch "ERR" else "<1";
            if (self.inventory.mouse_slot.material > 256) {
                tex = self.item_tex;
                // If it's an item, the count is going to be the full count, not divided by 128
                count = std.fmt.bufPrint(buf[0..], "{d}", .{self.inventory.mouse_slot.count}) catch "ERR";
            }

            ui.add_sprite(.{
                .color = [_]u8{ 255, 255, 255, 255 },
                .offset = item_pos,
                .scale = [_]f32{ 48.0, 48.0 },
                .tex_id = tex,
                .uv_offset = [_]f32{ 1.0 / 16.0 * @as(f32, @floatFromInt(self.inventory.mouse_slot.material % 16)), 15.0 / 16.0 },
                .uv_scale = @splat(1.0 / 16.0),
            }) catch unreachable;

            ui.add_text(
                count,
                [_]f32{ item_pos[0] + 20.0, item_pos[1] - 20.0 },
                [_]u8{ 255, 255, 255, 255 },
                2.0,
                1.0,
                .Right,
            ) catch unreachable;
        }
    }

    const hotbar_select_pos = [_]f32{ 38, ui.UI_RESOLUTION[1] - 144 - @as(f32, @floatFromInt(self.inventory.hotbarIdx)) * 60.0, 1.5 };
    ui.add_sprite(.{
        .color = [_]u8{ 255, 255, 255, 255 },
        .offset = hotbar_select_pos,
        .scale = [_]f32{ 72.0, 72.0 },
        .tex_id = self.hotbar_select_tex,
        .uv_offset = [_]f32{ 0.0, 0.0 },
        .uv_scale = [_]f32{ 1.0, 1.0 },
    }) catch unreachable;

    // DMG FLASH
    const time_since_last_damage = @divTrunc(std.time.nanoTimestamp() - self.last_damage, std.time.ns_per_ms);

    if (time_since_last_damage <= 127) {
        const alpha: u8 = @intCast(time_since_last_damage);

        ui.add_sprite(.{
            .color = [_]u8{ 255, 255, 255, 255 -| alpha * 2 },
            .offset = [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2, 3.0 },
            .scale = ui.UI_RESOLUTION,
            .tex_id = self.dmg_tex,
            .uv_offset = [_]f32{ 0.0, 0.0 },
            .uv_scale = [_]f32{ 1.0, 1.0 },
        }) catch unreachable;
    }

    if (self.dead) {
        ui.add_sprite(.{
            .color = [_]u8{ 255, 255, 255, 255 },
            .offset = [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2, 3.0 },
            .scale = ui.UI_RESOLUTION,
            .tex_id = self.dmg_tex,
            .uv_offset = [_]f32{ 0.0, 0.0 },
            .uv_scale = [_]f32{ 1.0, 1.0 },
        }) catch unreachable;
        ui.add_text("You died!", [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2 }, [_]u8{ 255, 0, 0, 255 }, 3.0, 3.0, .Center) catch unreachable;

        const mouse_pos = input.get_mouse_position();

        var button_texture = self.button_tex;

        if (mouse_pos[0] >= ui.UI_RESOLUTION[0] / 2 - 96 * 7 / 2 and
            mouse_pos[0] <= ui.UI_RESOLUTION[0] / 2 + 96 * 7 / 2 and
            mouse_pos[1] >= ui.UI_RESOLUTION[1] / 2 - 168 - 12 * 7 / 2 and
            mouse_pos[1] <= ui.UI_RESOLUTION[1] / 2 - 168 + 12 * 7 / 2)
        {
            button_texture = self.button_hover_tex;
        }

        ui.add_sprite(.{
            .color = [_]u8{ 255, 255, 255, 255 },
            .offset = [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2 - 168, 3.0 },
            .scale = [_]f32{ 96 * 7, 12 * 7 },
            .tex_id = button_texture,
        }) catch unreachable;

        ui.add_text("Respawn", [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2 - 6 - 168 }, [_]u8{ 255, 255, 255, 255 }, 4.0, 2.0, .Center) catch unreachable;
    }
}
