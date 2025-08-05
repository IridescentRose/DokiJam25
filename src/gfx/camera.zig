const std = @import("std");
const zm = @import("zmath");
const window = @import("window.zig");
const shaders = @import("shaders.zig");

fov: f32,
target: [3]f32,
distance: f32,
pitch: f32,
yaw: f32,

const Self = @This();

pub fn update(self: *Self) void {
    const perspective = self.get_projection_matrix();

    const eye = [_]f32{ self.target[0] + self.distance * std.math.cos(std.math.degreesToRadians(self.pitch)) * std.math.cos(std.math.degreesToRadians(self.yaw)), self.target[1] + self.distance * std.math.sin(std.math.degreesToRadians(self.pitch)), self.target[2] + self.distance * std.math.cos(std.math.degreesToRadians(self.pitch)) * std.math.sin(std.math.degreesToRadians(self.yaw)), 1.0 };
    const up = [_]f32{ 0, 1, 0, 0 };

    const target_4 = [_]f32{
        self.target[0],
        self.target[1],
        self.target[2],
        1.0,
    };

    const view = zm.lookAtRh(eye, target_4, up);
    const projView = zm.mul(view, perspective);

    shaders.set_projview(projView);
}

pub fn get_projection_matrix(self: *Self) zm.Mat {
    const width: f32 = @floatFromInt(window.get_width() catch 0);
    const height: f32 = @floatFromInt(window.get_height() catch 0);
    return zm.perspectiveFovRhGl(std.math.degreesToRadians(self.fov), width / height, 0.3, 1000.0);
}

pub fn get_projview_matrix(self: *Self) zm.Mat {
    const perspective = self.get_projection_matrix();

    const eye = [_]f32{ self.target[0] + self.distance * std.math.cos(std.math.degreesToRadians(self.pitch)) * std.math.cos(std.math.degreesToRadians(self.yaw)), self.target[1] + self.distance * std.math.sin(std.math.degreesToRadians(self.pitch)), self.target[2] + self.distance * std.math.cos(std.math.degreesToRadians(self.pitch)) * std.math.sin(std.math.degreesToRadians(self.yaw)), 1.0 };
    const up = [_]f32{ 0, 1, 0, 0 };

    const target_4 = [_]f32{
        self.target[0],
        self.target[1],
        self.target[2],
        1.0,
    };

    return zm.mul(zm.lookAtRh(eye, target_4, up), perspective);
}
