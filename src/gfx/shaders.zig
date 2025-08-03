const std = @import("std");
const gl = @import("gl.zig");
const assert = std.debug.assert;
const util = @import("../core/util.zig");
const zm = @import("zmath");

const vert_source = @embedFile("shader_raw/uber.vert");
const frag_source = @embedFile("shader_raw/uber.frag");

const post_vert_source = @embedFile("shader_raw/post.vert");
const post_frag_source = @embedFile("shader_raw/post.frag");

var uber: c_uint = 0;
var post: c_uint = 0;
var vpLoc: c_int = 0;
var modelLoc: c_int = 0;
var hasTexLoc: c_int = 0;

fn compile_shader(source: [*c]const [*c]const gl.GLchar, stype: c_uint) c_uint {
    const shad = gl.createShader(stype);
    gl.shaderSource(shad, 1, source, 0);

    var success: c_uint = 0;
    gl.compileShader(shad);
    gl.getShaderiv(shad, gl.COMPILE_STATUS, @ptrCast(&success));
    if (success == 0) {
        var buf: [512]u8 = @splat(0);
        var len: c_uint = 0;
        gl.getShaderInfoLog(shad, 512, @ptrCast(&len), &buf);
        std.debug.print("ERROR Shader:\n{s}\n", .{buf[0..len]});
    }

    return shad;
}

fn create_program(vert: c_uint, frag: c_uint) c_uint {
    const program = gl.createProgram();
    gl.attachShader(program, vert);
    gl.attachShader(program, frag);
    gl.linkProgram(program);

    var success: c_uint = 0;
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

    return program;
}

pub fn init() !void {
    const vert = compile_shader(@ptrCast(&vert_source), gl.VERTEX_SHADER);
    const frag = compile_shader(@ptrCast(&frag_source), gl.FRAGMENT_SHADER);
    uber = create_program(vert, frag);

    const pv = compile_shader(@ptrCast(&post_vert_source), gl.VERTEX_SHADER);
    const pf = compile_shader(@ptrCast(&post_frag_source), gl.FRAGMENT_SHADER);
    post = create_program(pv, pf);

    use_render_shader();
    vpLoc = gl.getUniformLocation(uber, "viewProj");
    modelLoc = gl.getUniformLocation(uber, "model");
    hasTexLoc = gl.getUniformLocation(uber, "hasTex");
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
    gl.deleteProgram(uber);
}

pub fn use_render_shader() void {
    gl.useProgram(uber);
}

pub fn use_post_shader() void {
    gl.useProgram(post);
}
