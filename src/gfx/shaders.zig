const std = @import("std");
const gl = @import("gl.zig");
const assert = std.debug.assert;
const util = @import("../core/util.zig");
const zm = @import("zmath");

const vert_source = @embedFile("shader_raw/uber.vert");
const frag_source = @embedFile("shader_raw/uber.frag");

var program: c_uint = 0;
var vpLoc: c_int = 0;
var modelLoc: c_int = 0;
var hasTexLoc: c_int = 0;

pub fn init() !void {
    const vert = gl.createShader(gl.VERTEX_SHADER);
    const frag = gl.createShader(gl.FRAGMENT_SHADER);

    gl.shaderSource(vert, 1, @ptrCast(&vert_source), 0);
    gl.shaderSource(frag, 1, @ptrCast(&frag_source), 0);

    var success: c_uint = 0;

    gl.compileShader(vert);
    gl.getShaderiv(vert, gl.COMPILE_STATUS, @ptrCast(&success));
    if (success == 0) {
        var buf: [512]u8 = @splat(0);
        var len: c_uint = 0;
        gl.getShaderInfoLog(vert, 512, @ptrCast(&len), &buf);
        std.debug.print("ERROR Virtex Shader:\n{s}\n", .{buf[0..len]});
    }

    gl.compileShader(frag);
    gl.getShaderiv(frag, gl.COMPILE_STATUS, @ptrCast(&success));
    if (success == 0) {
        var buf: [512]u8 = @splat(0);
        var len: c_uint = 0;
        gl.getShaderInfoLog(frag, 512, @ptrCast(&len), &buf);
        std.debug.print("ERROR Fragment Shader:\n{s}\n", .{buf});
    }

    program = gl.createProgram();
    gl.attachShader(program, vert);
    gl.attachShader(program, frag);
    gl.linkProgram(program);

    gl.getProgramiv(program, gl.LINK_STATUS, @ptrCast(&success));
    if (success == 0) {
        var buf: [512]u8 = @splat(0);
        var len: c_uint = 0;
        gl.getProgramInfoLog(program, 512, @ptrCast(&len), &buf);
        std.debug.print("ERROR Program:\n{s}\n", .{buf[0..len]});
    }

    gl.useProgram(program);
    gl.deleteShader(vert);
    gl.deleteShader(frag);

    vpLoc = gl.getUniformLocation(program, "viewProj");
    modelLoc = gl.getUniformLocation(program, "model");
    hasTexLoc = gl.getUniformLocation(program, "hasTex");
}

pub fn set_model(matrix: zm.Mat) void {
    gl.uniformMatrix4fv(modelLoc, 1, gl.TRUE, zm.arrNPtr(&matrix));
}

pub fn set_viewproj(matrix: zm.Mat) void {
    gl.uniformMatrix4fv(vpLoc, 1, gl.TRUE, zm.arrNPtr(&matrix));
}

pub fn set_has_tex(has: bool) void {
    gl.uniform1i(hasTexLoc, @intFromBool(has));
}

pub fn deinit() void {
    gl.useProgram(0);
    gl.deleteProgram(program);
}
