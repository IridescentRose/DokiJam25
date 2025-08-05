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

// Half
const player_size = [_]f32{ 0.5, 1.85, 0.5 };

const GRAVITY = -32;
const TERMINAL_VELOCITY = -50.0;
const STEP_INCREMENT = 0.125;
const MAX_STEP_HEIGHT = 1.0;
const BLOCK_SCALE = 1.0 / @as(f32, c.SUB_BLOCKS_PER_BLOCK);
const EPSILON = 1e-3;
const JUMP_VELOCITY = 16.0;

voxel: Voxel,
transform: Transform,
camera: Camera,
tex: gfx.texture.Texture,
velocity: [3]f32,
on_ground: bool,
moving: [4]bool,

var dbg_tex: gfx.texture.Texture = undefined;
var dbg_transform: Transform = undefined;
var dbg_voxel: Voxel = undefined;

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

    try res.voxel.build();

    dbg_tex = try gfx.texture.load_image_from_file("dot.png");
    dbg_voxel = Voxel.init(dbg_tex);
    try dbg_voxel.build();

    dbg_transform = Transform.new();
    dbg_transform.size = @splat(0);

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

    try window.set_relative(true);
}

pub fn deinit(self: *Self) void {
    dbg_voxel.deinit();
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

    // 3) TODO: Do physics
    var new_pos = [_]f32{
        self.transform.pos[0] + vel[0] * dt,
        self.transform.pos[1] + vel[1] * dt,
        self.transform.pos[2] + vel[2] * dt,
    };

    {
        const min_pos = [_]f32{
            @floor((new_pos[0] - player_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[1]) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[2] - player_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
        };

        const max_pos = [_]f32{
            @ceil((new_pos[0] + player_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
            @ceil((new_pos[1] + player_size[1] * 2) * c.SUB_BLOCKS_PER_BLOCK),
            @ceil((new_pos[2] + player_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
        };

        const testY = if (vel[1] > 0) max_pos[1] else if (vel[1] < 0) min_pos[1] else 0;

        if (testY != 0) {
            const max_x: isize = @intFromFloat(max_pos[0]);
            const max_z: isize = @intFromFloat(max_pos[2]);

            var x: isize = @intFromFloat(min_pos[0]);
            while (x < max_x) : (x += 1) {
                var z: isize = @intFromFloat(min_pos[2]);

                while (z < max_z) : (z += 1) {
                    const coord = [_]isize{
                        x,
                        @intFromFloat(testY),
                        z,
                    };

                    if (world.get_voxel(coord) != .Air) {
                        if (vel[1] > 0) {
                            new_pos[1] = @as(f32, @floatFromInt(coord[1])) / c.SUB_BLOCKS_PER_BLOCK;
                            vel[1] = 0;
                        }
                        // If moving down, hit ground
                        else if (vel[1] < 0) {
                            new_pos[1] = (@as(f32, @floatFromInt(coord[1] + 1))) / c.SUB_BLOCKS_PER_BLOCK;
                            vel[1] = 0;
                            self.on_ground = true;
                        }

                        break;
                    }
                }
            }
        }
    }

    // X axis

    var has_stepped: bool = false;

    {
        const min_pos = [_]f32{
            @floor((new_pos[0] - player_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[1]) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[2] - player_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
        };

        const max_pos = [_]f32{
            @ceil((new_pos[0] + player_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
            @ceil((new_pos[1] + player_size[1] * 2) * c.SUB_BLOCKS_PER_BLOCK),
            @ceil((new_pos[2] + player_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
        };

        const testX = if (vel[0] > 0) max_pos[0] else if (vel[0] < 0) min_pos[0] else 0;

        if (testX != 0) {
            const max_y: isize = @intFromFloat(max_pos[1]);
            const max_z: isize = @intFromFloat(max_pos[2]);

            var y: isize = @intFromFloat(min_pos[1]);
            while (y < max_y) : (y += 1) {
                var z: isize = @intFromFloat(min_pos[2]);

                while (z < max_z) : (z += 1) {
                    const coord = [_]isize{
                        @intFromFloat(testX),
                        y,
                        z,
                    };

                    if (world.get_voxel(coord) != .Air) {
                        if (self.on_ground and !has_stepped) {
                            // try small increments up to MAX_STEP_HEIGHT
                            var stepped = false;
                            var s: f32 = STEP_INCREMENT;
                            while (s <= MAX_STEP_HEIGHT) : (s += STEP_INCREMENT) {
                                // sample the voxel at the would-be position,
                                // but raised by s
                                const worldX = (@as(f32, testX) / c.SUB_BLOCKS_PER_BLOCK);
                                const worldY = new_pos[1] + s;
                                const worldZ = new_pos[2];

                                const ix: isize = @intFromFloat(@floor(worldX * c.SUB_BLOCKS_PER_BLOCK));
                                const iy: isize = @intFromFloat(@floor(worldY * c.SUB_BLOCKS_PER_BLOCK));
                                const iz: isize = @intFromFloat(@floor(worldZ * c.SUB_BLOCKS_PER_BLOCK));

                                if (world.get_voxel(.{ ix, iy, iz }) == .Air) {
                                    // looks clear at this step height
                                    new_pos[1] += s;
                                    // now re-try the X collision at the higher Y:

                                    if (vel[0] > 0) {
                                        new_pos[0] = @as(f32, @floatFromInt(coord[0] - 1)) / c.SUB_BLOCKS_PER_BLOCK - player_size[0];
                                    } else if (vel[0] < 0) {
                                        new_pos[0] = (@as(f32, @floatFromInt(coord[0] + 1))) / c.SUB_BLOCKS_PER_BLOCK + player_size[0];
                                    }
                                    vel[0] = 0;
                                    stepped = true;
                                    has_stepped = true;
                                    break;
                                }
                            }
                            if (stepped) break; // we’ve stepped up and resolved X
                        }
                        // If moving right, hit right wall
                        if (vel[0] > 0) {
                            new_pos[0] = @as(f32, @floatFromInt(coord[0] - 1)) / c.SUB_BLOCKS_PER_BLOCK - player_size[0];
                            vel[0] = 0;
                        }
                        // If moving left, hit left wall
                        else if (vel[0] < 0) {
                            new_pos[0] = (@as(f32, @floatFromInt(coord[0] + 1))) / c.SUB_BLOCKS_PER_BLOCK + player_size[0];
                            vel[0] = 0;
                        }

                        break;
                    }
                }
            }
        }
    }

    {
        const min_pos = [_]f32{
            @floor((new_pos[0] - player_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[1]) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[2] - player_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
        };

        const max_pos = [_]f32{
            @ceil((new_pos[0] + player_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
            @ceil((new_pos[1] + player_size[1] * 2) * c.SUB_BLOCKS_PER_BLOCK),
            @ceil((new_pos[2] + player_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
        };

        const testZ = if (vel[2] > 0) max_pos[2] else if (vel[2] < 0) min_pos[2] else 0;

        if (testZ != 0) {
            const max_x: isize = @intFromFloat(max_pos[0]);
            const max_y: isize = @intFromFloat(max_pos[1]);

            var x: isize = @intFromFloat(min_pos[0]);
            while (x < max_x) : (x += 1) {
                var y: isize = @intFromFloat(min_pos[1]);

                while (y < max_y) : (y += 1) {
                    const coord = [_]isize{
                        x,
                        y,
                        @intFromFloat(testZ),
                    };

                    if (world.get_voxel(coord) != .Air) {
                        if (self.on_ground and !has_stepped) {
                            // try small increments up to MAX_STEP_HEIGHT
                            var stepped = false;
                            var s: f32 = STEP_INCREMENT;
                            while (s <= MAX_STEP_HEIGHT) : (s += STEP_INCREMENT) {
                                // sample the voxel at the would-be position,
                                // but raised by s
                                const worldX = new_pos[0];
                                const worldY = new_pos[1] + s;
                                const worldZ = (@as(f32, testZ) / c.SUB_BLOCKS_PER_BLOCK);

                                const ix: isize = @intFromFloat(@floor(worldX * c.SUB_BLOCKS_PER_BLOCK));
                                const iy: isize = @intFromFloat(@floor(worldY * c.SUB_BLOCKS_PER_BLOCK));
                                const iz: isize = @intFromFloat(@floor(worldZ * c.SUB_BLOCKS_PER_BLOCK));

                                if (world.get_voxel(.{ ix, iy, iz }) == .Air) {
                                    // looks clear at this step height
                                    new_pos[1] += s;
                                    // now re-try the Z collision at the higher Y:

                                    if (vel[2] > 0) {
                                        new_pos[2] = @as(f32, @floatFromInt(coord[2] - 1)) / c.SUB_BLOCKS_PER_BLOCK - player_size[2];
                                    } else if (vel[2] < 0) {
                                        new_pos[2] = (@as(f32, @floatFromInt(coord[2] + 1))) / c.SUB_BLOCKS_PER_BLOCK + player_size[2];
                                    }
                                    vel[2] = 0;
                                    stepped = true;
                                    has_stepped = true;
                                    break;
                                }
                            }
                            if (stepped) break; // we’ve stepped up and resolved Z
                        }

                        // If moving forward, hit front wall
                        if (vel[2] > 0) {
                            new_pos[2] = @as(f32, @floatFromInt(coord[2] - 1)) / c.SUB_BLOCKS_PER_BLOCK - player_size[2];
                            vel[2] = 0;
                        }
                        // If moving back, hit back wall
                        else if (vel[2] < 0) {
                            new_pos[2] = (@as(f32, @floatFromInt(coord[2] + 1))) / c.SUB_BLOCKS_PER_BLOCK + player_size[2];
                            vel[2] = 0;
                        }
                        break;
                    }
                }
            }
        }
    }
    self.transform.pos = new_pos;

    // 4) Commit
    self.velocity = vel;
    // zero out horizontal so you don’t keep drifting
    self.velocity[0] = 0;
    self.velocity[2] = 0;

    // 5) Update camera
    self.camera.target = self.transform.pos;
    self.camera.target[1] += player_size[1];
    self.camera.update();
}

pub fn draw(self: *Self) void {
    self.camera.update();
    self.transform.pos[1] += player_size[1];
    gfx.shader.set_model(self.transform.get_matrix());
    self.transform.pos[1] -= player_size[1];
    self.voxel.draw();

    // dbg_transform.pos = self.transform.pos;
    // dbg_transform.scale = @splat(BLOCK_SCALE * 8.0);
    // gfx.shader.set_model(dbg_transform.get_matrix());
    // dbg_voxel.draw();
}
