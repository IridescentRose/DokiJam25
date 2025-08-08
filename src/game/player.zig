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

// Half
const player_size = [_]f32{ 0.5, 1.85, 0.5 };

const GRAVITY = -32;
const TERMINAL_VELOCITY = -50.0;
const BLOCK_SCALE = 1.0 / @as(f32, c.SUB_BLOCKS_PER_BLOCK);
const EPSILON = 1e-3;
const JUMP_VELOCITY = 16.0;

aabb: AABB,
voxel: Voxel,
transform: Transform,
camera: Camera,
tex: gfx.texture.Texture,
velocity: [3]f32,
on_ground: bool,
moving: [4]bool,
inventory: Inventory,

pub fn init() !Self {
    var res: Self = undefined;

    res.tex = try gfx.texture.load_image_from_file("doki.png");
    res.voxel = Voxel.init(res.tex);
    res.transform = Transform.new();

    res.camera.distance = 5.0;
    res.camera.fov = 90.0;
    res.camera.pitch = 0;
    res.camera.yaw = 0;
    res.velocity = @splat(0);
    res.transform.scale = @splat(1.0 / 10.0);

    res.transform.size[0] = 20.0;
    res.transform.size[1] = 37;
    res.transform.size[2] = 20.0;
    res.on_ground = false;

    res.camera.target = res.transform.pos;
    res.camera.yaw = -90;
    res.moving = @splat(false);

    res.aabb = AABB{
        .aabb_size = player_size,
        .can_step = true,
    };

    res.inventory = Inventory.new();

    try res.voxel.build();

    return res;
}

fn moveForward(ctx: *anyopaque, down: bool) void {
    var self = util.ctx_to_self(Self, ctx);
    self.moving[0] = down;
}
fn moveBackward(ctx: *anyopaque, down: bool) void {
    var self = util.ctx_to_self(Self, ctx);
    self.moving[1] = down;
}
fn moveLeft(ctx: *anyopaque, down: bool) void {
    var self = util.ctx_to_self(Self, ctx);
    self.moving[2] = down;
}
fn moveRight(ctx: *anyopaque, down: bool) void {
    var self = util.ctx_to_self(Self, ctx);
    self.moving[3] = down;
}

fn jump(ctx: *anyopaque, down: bool) void {
    const self = util.ctx_to_self(Self, ctx);
    if (down and self.on_ground) {
        self.velocity[1] = JUMP_VELOCITY;
        self.on_ground = false;
    }
}

const sensitivity = 0.1;

fn mouseCb(ctx: *anyopaque, dx: f32, dy: f32) void {
    var self = util.ctx_to_self(Self, ctx);

    self.camera.yaw += dx * sensitivity;
    self.camera.pitch += dy * sensitivity;

    if (self.camera.pitch > 60.0) self.camera.pitch = 60.0;
    if (self.camera.pitch < -60.0) self.camera.pitch = -60.0;
}

fn place_block(ctx: *anyopaque, down: bool) void {
    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);
    const coord = [_]f32{ self.transform.pos[0] * c.SUB_BLOCKS_PER_BLOCK, self.transform.pos[1] * c.SUB_BLOCKS_PER_BLOCK, self.transform.pos[2] * c.SUB_BLOCKS_PER_BLOCK };

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
                        const stencil = blocks.registry.get(hand.material).?;
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
    if (!down) return;

    const self = util.ctx_to_self(Self, ctx);

    // TODO: Better way of doing this
    const coord = [_]f32{ self.transform.pos[0] * c.SUB_BLOCKS_PER_BLOCK, self.transform.pos[1] * c.SUB_BLOCKS_PER_BLOCK - 0.05, self.transform.pos[2] * c.SUB_BLOCKS_PER_BLOCK };

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

    try window.set_relative(true);
}

pub fn deinit(self: *Self) void {
    self.voxel.deinit();
}

pub fn update(self: *Self) void {
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
        self.transform.rot[1] = std.math.radiansToDegrees(std.math.atan2(movement[0], movement[2])) + 180.0;
    }

    // 2) Prepare new velocity
    var vel = self.velocity;
    vel[0] = movement[0];
    vel[2] = movement[2];
    vel[1] += GRAVITY * dt;
    if (vel[1] < TERMINAL_VELOCITY) vel[1] = TERMINAL_VELOCITY;

    // 3) Perform physics
    var new_pos = [_]f32{
        self.transform.pos[0] + vel[0] * dt,
        self.transform.pos[1] + vel[1] * dt,
        self.transform.pos[2] + vel[2] * dt,
    };

    self.aabb.collide_aabb_with_world(&new_pos, &vel, &self.on_ground);
    self.transform.pos = new_pos;

    // 4) Commit
    self.velocity = vel;
    // zero out horizontal so you don’t keep drifting
    self.velocity[0] = 0;
    self.velocity[2] = 0;

    // 5) Update camera
    self.camera.target = self.transform.pos;
    self.camera.target[1] += player_size[1] + 0.25;
    self.camera.update();
}

pub fn draw(self: *Self) void {
    gfx.shader.use_render_shader();

    self.camera.distance = 5.0 + @as(f32, @floatFromInt(input.scroll_pos)) * 0.5;
    self.camera.update();
    self.transform.pos[1] += player_size[1] + 0.1; // Offset player up a bit so they don't clip into the ground
    gfx.shader.set_model(self.transform.get_matrix());
    self.transform.pos[1] -= player_size[1] + 0.1; // Reset position
    self.voxel.draw();
}
