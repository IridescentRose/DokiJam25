const std = @import("std");
const zm = @import("zmath");

pos: [3]f32,
rot: [3]f32,
scale: [3]f32,
size: [3]f32,

const Self = @This();

pub fn new() Self {
    return .{
        .pos = @splat(0),
        .rot = @splat(0),
        .scale = @splat(1),
        .size = @splat(0),
    };
}

pub fn get_matrix(self: *const Self) zm.Mat {
    const pre_translation = zm.translation(-self.size[0] / 2.0, -self.size[1] / 2.0, -self.size[2] / 2.0);
    const scaling = zm.scaling(self.scale[0], self.scale[1], self.scale[2]);

    const rotX = zm.rotationX(std.math.degreesToRadians(self.rot[0]));
    const rotY = zm.rotationY(std.math.degreesToRadians(self.rot[1]));
    const rotZ = zm.rotationZ(std.math.degreesToRadians(self.rot[2]));

    const rotation = zm.mul(zm.mul(rotZ, rotX), rotY);
    const translation = zm.translation(self.pos[0], self.pos[1], self.pos[2]);
    return zm.mul(pre_translation, zm.mul(scaling, zm.mul(rotation, translation)));
}
