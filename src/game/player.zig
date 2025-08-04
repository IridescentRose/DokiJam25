const std = @import("std");
const Voxel = @import("voxel.zig");
const Transform = @import("../gfx/transform.zig");
const Camera = @import("../gfx/camera.zig");
const gfx = @import("../gfx/gfx.zig");
const input = @import("../core/input.zig");
const util = @import("../core/util.zig");
const zm = @import("zmath");
const window = @import("../gfx/window.zig");

voxel: Voxel,
transform: Transform,
camera: Camera,
tex: gfx.texture.Texture,

moving: [4]bool,

const Self = @This();

pub fn init() !Self {
    var res: Self = undefined;

    res.tex = try gfx.texture.load_image_from_file("doki.png");
    res.voxel = Voxel.init(res.tex);
    res.transform = Transform.new();

    res.camera.distance = 3.0;
    res.camera.fov = 90.0;
    res.camera.pitch = 0;
    res.camera.yaw = 0;

    res.transform.scale = @splat(1.0 / 20.0);
    res.transform.size = @splat(20.0);

    res.camera.target = res.transform.pos;
    res.camera.yaw = -90;
    res.moving = @splat(false);

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

const sensitivity = 0.1;
fn mouseCb(ctx: *anyopaque, dx: f32, dy: f32) void {
    var self = util.ctx_to_self(Self, ctx);

    self.camera.yaw += dx * sensitivity;
    self.camera.pitch += dy * sensitivity;

    if (self.camera.pitch > 89.0) self.camera.pitch = 89.0;
    if (self.camera.pitch < -89.0) self.camera.pitch = -89.0;
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

    input.mouse_relative_handle = .{
        .ctx = self,
        .cb = mouseCb,
    };

    try window.set_relative(true);
}

pub fn deinit(self: *Self) void {
    self.voxel.deinit();
}

pub fn update(self: *Self) void {
    const yawr = std.math.degreesToRadians(-self.camera.yaw - 90.0);

    const forward = zm.normalize3([_]f32{ std.math.sin(yawr), 0, std.math.cos(yawr), 0 });
    const right = zm.normalize3(zm.cross3(forward, [_]f32{ 0, 1, 0, 0 }));

    var movement = @Vector(4, f32){ 0, 0, 0, 0 };

    if (self.moving[0]) {
        movement += forward;
    }
    if (self.moving[1]) {
        movement -= forward;
    }
    if (self.moving[2]) {
        movement -= right;
    }
    if (self.moving[3]) {
        movement += right;
    }

    if (zm.length3(movement)[0] > 0.1) {
        movement = zm.normalize3(movement);
        self.transform.rot[1] = std.math.radiansToDegrees(std.math.atan2(movement[0], movement[2])) + 180.0;
    }

    self.transform.pos[0] += movement[0] * 1.0 / 60.0 * 4.3;
    self.transform.pos[1] += movement[1] * 1.0 / 60.0 * 4.3;
    self.transform.pos[2] += movement[2] * 1.0 / 60.0 * 4.3;

    self.camera.target = self.transform.pos;
}

pub fn draw(self: *Self) void {
    self.camera.update();
    gfx.shader.set_model(self.transform.get_matrix());
    self.voxel.draw();
}
