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

tex: gfx.texture.Texture,
camera: Camera,
moving: [4]bool,
heart_tex: u32,
hotbar_slot_tex: u32,
hotbar_select_tex: u32,
dmg_tex: u32,
last_damage: i128,

// TODO: make a component so that dragoons can have different inventories
inventory: Inventory,
entity: ecs.Entity,

pub fn init() !Self {
    var res: Self = undefined;

    res.tex = try gfx.texture.load_image_from_file("doki.png");
    res.entity = try ecs.create_entity();

    var transform = Transform.new();
    transform.size = [_]f32{ 20.0, 37, 20.0 };
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
    res.last_damage = 0;
    res.moving = @splat(false);
    res.inventory = Inventory.new();

    return res;
}

const debugging_pause = false;

fn hitYourself(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    self.do_damage(1);
}

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

    self.camera.yaw += dx * sensitivity;
    self.camera.pitch += dy * sensitivity;

    if (self.camera.pitch > 60.0) self.camera.pitch = 60.0;
    if (self.camera.pitch < -60.0) self.camera.pitch = -60.0;
}

fn place_block(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause) return;

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    const coord = [_]f32{ self.entity.get(.transform).pos[0] * c.SUB_BLOCKS_PER_BLOCK, self.entity.get(.transform).pos[1] * c.SUB_BLOCKS_PER_BLOCK, self.entity.get(.transform).pos[2] * c.SUB_BLOCKS_PER_BLOCK };

    const subvoxel_coord = [3]isize{ @intFromFloat(coord[0]), @intFromFloat(coord[1]), @intFromFloat(coord[2]) };
    const voxel_coord = [3]isize{ @divFloor(subvoxel_coord[0], c.SUB_BLOCKS_PER_BLOCK), @divFloor(subvoxel_coord[1], c.SUB_BLOCKS_PER_BLOCK), @divFloor(subvoxel_coord[2], c.SUB_BLOCKS_PER_BLOCK) };

    // This is the bottom left corner of the voxel we are looking at
    const rescaled_subvoxel = [3]isize{ voxel_coord[0] * c.SUB_BLOCKS_PER_BLOCK, voxel_coord[1] * c.SUB_BLOCKS_PER_BLOCK, voxel_coord[2] * c.SUB_BLOCKS_PER_BLOCK };

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
                    const hand = self.inventory.get_hand_slot();

                    if (hand.count > 0) {
                        const stencil = blocks.registry[@intFromEnum(hand.material)];
                        if (world.set_voxel(test_coord, stencil[stidx])) {
                            hand.count -= 1;
                            if (hand.count == 0) hand.material = .Air;
                        }
                    } else {
                        break;
                    }
                }
            }
        }
    }
}

fn destroy_block(ctx: *anyopaque, down: bool) void {
    if (world.paused and !debugging_pause and down) {
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

    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);

    // TODO: Better way of doing this
    const coord = [_]f32{ self.entity.get(.transform).pos[0] * c.SUB_BLOCKS_PER_BLOCK, self.entity.get(.transform).pos[1] * c.SUB_BLOCKS_PER_BLOCK - 0.05, self.entity.get(.transform).pos[2] * c.SUB_BLOCKS_PER_BLOCK };

    const subvoxel_coord = [3]isize{ @intFromFloat(coord[0]), @intFromFloat(coord[1]), @intFromFloat(coord[2]) };
    const voxel_coord = [3]isize{ @divFloor(subvoxel_coord[0], c.SUB_BLOCKS_PER_BLOCK), @divFloor(subvoxel_coord[1], c.SUB_BLOCKS_PER_BLOCK), @divFloor(subvoxel_coord[2], c.SUB_BLOCKS_PER_BLOCK) };

    // This is the bottom left corner of the voxel we are looking at
    const rescaled_subvoxel = [3]isize{ voxel_coord[0] * c.SUB_BLOCKS_PER_BLOCK, voxel_coord[1] * c.SUB_BLOCKS_PER_BLOCK, voxel_coord[2] * c.SUB_BLOCKS_PER_BLOCK };

    for (0..c.SUB_BLOCKS_PER_BLOCK) |y| {
        for (0..c.SUB_BLOCKS_PER_BLOCK) |z| {
            for (0..c.SUB_BLOCKS_PER_BLOCK) |x| {
                const ix: isize = @intCast(x);
                const iy: isize = @intCast(y);
                const iz: isize = @intCast(z);

                const test_coord = [3]isize{ rescaled_subvoxel[0] + ix, rescaled_subvoxel[1] + iy, rescaled_subvoxel[2] + iz };
                const voxel = world.get_voxel(test_coord);
                if (voxel != .Air) {
                    const atom_type = voxel;
                    const amt = self.inventory.add_item_inventory(.{ .material = atom_type, .count = 1 });

                    if (amt == 0) {
                        std.debug.print("Inventory full, could not add item: {s}\n", .{@tagName(atom_type)});
                        std.debug.print("Tried to add item at coord: {d}, {d}, {d}\n", .{ test_coord[0], test_coord[1], test_coord[2] });
                        return;
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

fn pause(ctx: *anyopaque, down: bool) void {
    _ = ctx;
    if (down) {
        world.paused = !world.paused;
        if (world.paused) {
            std.debug.print("Game paused\n", .{});
            window.set_relative(false) catch unreachable;
        } else {
            std.debug.print("Game unpaused\n", .{});
            // TODO: Based on overlay state
            window.set_relative(true) catch unreachable;
        }
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
    try input.register_key_callback(.func1, .{
        .ctx = self,
        .cb = hitYourself,
    });
    try input.register_key_callback(.e, .{
        .ctx = self,
        .cb = increment_hotbar,
    });
    try input.register_key_callback(.q, .{
        .ctx = self,
        .cb = decrement_hotbar,
    });

    input.mouse_relative_handle = .{
        .ctx = self,
        .cb = mouseCb,
    };

    try input.register_mouse_callback(.left, .{
        .ctx = self,
        .cb = destroy_block,
    });
    try input.register_mouse_callback(.right, .{
        .ctx = self,
        .cb = place_block,
    });

    if (!world.paused)
        try window.set_relative(true);
}

pub fn deinit(self: *Self) void {
    self.entity.get_ptr(.model).deinit();
}

pub fn update(self: *Self) void {
    const curr_pos = [_]isize{
        @intFromFloat(self.entity.get(.transform).pos[0]),
        @intFromFloat(@max(@min(self.entity.get(.transform).pos[1], 62.0), 0)), // Clamp y to world height
        @intFromFloat(self.entity.get(.transform).pos[2]),
    };

    // Update camera
    self.camera.target = self.entity.get(.transform).pos;
    self.camera.target[1] += player_size[1] + 0.25;

    if (!world.is_in_world([_]isize{ curr_pos[0] * c.SUB_BLOCKS_PER_BLOCK, curr_pos[1] * c.SUB_BLOCKS_PER_BLOCK, curr_pos[2] * c.SUB_BLOCKS_PER_BLOCK })) return;

    if (world.paused and !debugging_pause) return;

    const dt: f32 = 1.0 / 60.0;

    // 1) Build movement vector from input & camera
    const radYaw = std.math.degreesToRadians(-self.camera.yaw - 90.0);
    const forward = zm.normalize3(.{ std.math.sin(radYaw), 0, std.math.cos(radYaw), 0 });
    const right = zm.normalize3(zm.cross3(forward, .{ 0, 1, 0, 0 }));
    var movement: @Vector(4, f32) = .{ 0, 0, 0, 0 };
    if (self.moving[0]) movement += forward;
    if (self.moving[1]) movement -= forward;
    if (self.moving[2]) movement -= right;
    if (self.moving[3]) movement += right;
    if (zm.length3(movement)[0] > 0.1) {
        movement = zm.normalize3(movement) * @as(@Vector(4, f32), @splat(5.0)); // 5 units/sec move speed
        self.entity.get_ptr(.transform).rot[1] = std.math.radiansToDegrees(std.math.atan2(movement[0], movement[2])) + 180.0;
    }

    // 2) Prepare new velocity
    var vel = self.entity.get_ptr(.velocity);
    vel[0] = movement[0];
    vel[2] = movement[2];
    vel[1] += GRAVITY * dt;
    if (vel[1] < TERMINAL_VELOCITY) vel[1] = TERMINAL_VELOCITY;

    // 3) Perform physics
    var new_pos = [_]f32{
        self.entity.get(.transform).pos[0] + vel[0] * dt,
        self.entity.get(.transform).pos[1] + vel[1] * dt,
        self.entity.get(.transform).pos[2] + vel[2] * dt,
    };

    self.entity.get(.aabb).collide_aabb_with_world(&new_pos, vel, self.entity.get_ptr(.on_ground));
    self.entity.get_ptr(.transform).pos = new_pos;

    // Remove any velocity in the x and z directions to prevent sliding
    vel[0] = 0;
    vel[2] = 0;
}

pub fn do_damage(self: *Self, amount: u8) void {
    const health = self.entity.get_ptr(.health);
    self.last_damage = std.time.nanoTimestamp();
    if (health.* > 0) {
        health.* -|= amount;
    }

    // TODO: Death
}

pub fn draw(self: *Self) void {
    gfx.shader.use_render_shader();

    self.camera.distance = 5.0 + @as(f32, @floatFromInt(input.scroll_pos)) * 0.5;
    self.camera.update();
    self.entity.get_ptr(.transform).pos[1] += player_size[1] + 0.1; // Offset player up a bit so they don't clip into the ground
    gfx.shader.set_model(self.entity.get(.transform).get_matrix());
    self.entity.get_ptr(.transform).pos[1] -= player_size[1] + 0.1; // Reset position
    self.entity.get_ptr(.model).draw();

    for (0..10) |i| {
        const i_f = @as(f32, @floatFromInt(i));
        const position = [_]f32{ 30.0 + i_f * 42.0, ui.UI_RESOLUTION[1] - 30.0, 2.0 + 0.01 * i_f };

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

        if (time_since_last_damage <= 255) {
            const alpha: u8 = @intCast(time_since_last_damage);

            ui.add_sprite(.{
                .color = [_]u8{ 255, 255, 255, 255 - alpha },
                .offset = [_]f32{ ui.UI_RESOLUTION[0] / 2, ui.UI_RESOLUTION[1] / 2, 3.0 },
                .scale = ui.UI_RESOLUTION,
                .tex_id = self.dmg_tex,
                .uv_offset = [_]f32{ 0.0, 0.0 },
                .uv_scale = [_]f32{ 1.0, 1.0 },
            }) catch unreachable;
        }
    }
}
