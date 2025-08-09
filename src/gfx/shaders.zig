const std = @import("std");
const gl = @import("gl.zig");
const assert = std.debug.assert;
const util = @import("../core/util.zig");
const window = @import("window.zig");
const zm = @import("zmath");

const vert_source = @embedFile("shader_raw/uber.vert");
const frag_source = @embedFile("shader_raw/uber.frag");

const comp_vert_source = @embedFile("shader_raw/comp.vert");
const comp_frag_source = @embedFile("shader_raw/comp.frag");

const part_vert_source = @embedFile("shader_raw/particle.vert");
const part_frag_source = @embedFile("shader_raw/particle.frag");

const ray_vert_source = @embedFile("shader_raw/ray.vert");
const ray_frag_source = @embedFile("shader_raw/ray.frag");

const post_vert_source = @embedFile("shader_raw/post.vert");
const post_frag_source = @embedFile("shader_raw/post.frag");

const ui_vert_source = @embedFile("shader_raw/ui.vert");
const ui_frag_source = @embedFile("shader_raw/ui.frag");

const edit_comp_source = @embedFile("shader_raw/apply_voxel_edit.comp");

var uber: c_uint = 0;
var comp: c_uint = 0;
var part: c_uint = 0;
var ray: c_uint = 0;
var edit: c_uint = 0;
var post: c_uint = 0;
var ui: c_uint = 0;

var vpLoc: c_int = 0;
var modelLoc: c_int = 0;

var partVpLoc: c_int = 0;
var partModelLoc: c_int = 0;
var partYawLoc: c_int = 0;
var partPitchLoc: c_int = 0;

var rayResolutionLoc: c_int = 0;
var rayVpLoc: c_int = 0;
var rayInvVpLoc: c_int = 0;

var compResolutionLoc: c_int = 0;
var compInvProjLoc: c_int = 0;
var compInvViewLoc: c_int = 0;
var compSunDirLoc: c_int = 0;
var compSunColorLoc: c_int = 0;
var compAmbientColorLoc: c_int = 0;

var compGAlbedoLoc: c_int = 0;
var compGNormalLoc: c_int = 0;
var compGDepthLoc: c_int = 0;

var compFogColorLoc: c_int = 0;
var compFogDensityLoc: c_int = 0;
var compCameraPosLoc: c_int = 0;

var postResolutionLoc: c_int = 0;

var uiProjLoc: c_int = 0;

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

    vpLoc = gl.getUniformLocation(uber, "projView");
    modelLoc = gl.getUniformLocation(uber, "model");

    const pv = compile_shader(@ptrCast(&comp_vert_source), gl.VERTEX_SHADER);
    const pf = compile_shader(@ptrCast(&comp_frag_source), gl.FRAGMENT_SHADER);
    comp = create_program(pv, pf);
    compResolutionLoc = gl.getUniformLocation(comp, "uResolution");
    compInvProjLoc = gl.getUniformLocation(comp, "uInvProj");
    compInvViewLoc = gl.getUniformLocation(comp, "uInvView");
    compSunDirLoc = gl.getUniformLocation(comp, "uSunDir");
    compSunColorLoc = gl.getUniformLocation(comp, "uSunColor");
    compAmbientColorLoc = gl.getUniformLocation(comp, "uAmbientColor");
    compGAlbedoLoc = gl.getUniformLocation(comp, "gAlbedo");
    compGNormalLoc = gl.getUniformLocation(comp, "gNormal");
    compGDepthLoc = gl.getUniformLocation(comp, "gDepth");
    compFogColorLoc = gl.getUniformLocation(comp, "uFogColor");
    compFogDensityLoc = gl.getUniformLocation(comp, "uFogDensity");
    compCameraPosLoc = gl.getUniformLocation(comp, "cameraPos");

    const part_v = compile_shader(@ptrCast(&part_vert_source), gl.VERTEX_SHADER);
    const part_f = compile_shader(@ptrCast(&part_frag_source), gl.FRAGMENT_SHADER);
    part = create_program(part_v, part_f);

    const ray_v = compile_shader(@ptrCast(&ray_vert_source), gl.VERTEX_SHADER);
    const ray_f = compile_shader(@ptrCast(&ray_frag_source), gl.FRAGMENT_SHADER);
    ray = create_program(ray_v, ray_f);
    rayResolutionLoc = gl.getUniformLocation(ray, "uResolution");
    rayVpLoc = gl.getUniformLocation(ray, "uProjView");
    rayInvVpLoc = gl.getUniformLocation(ray, "uInvProjView");

    const post_v = compile_shader(@ptrCast(&post_vert_source), gl.VERTEX_SHADER);
    const post_f = compile_shader(@ptrCast(&post_frag_source), gl.FRAGMENT_SHADER);
    post = create_program(post_v, post_f);
    postResolutionLoc = gl.getUniformLocation(post, "uResolution");

    const edit_comp = compile_shader(@ptrCast(&edit_comp_source), gl.COMPUTE_SHADER);
    edit = gl.createProgram();
    gl.attachShader(edit, edit_comp);
    gl.linkProgram(edit);
    var success: c_uint = 0;
    gl.getProgramiv(edit, gl.LINK_STATUS, @ptrCast(&success));
    if (success == 0) {
        var buf: [512]u8 = @splat(0);
        var len: c_uint = 0;
        gl.getProgramInfoLog(edit, 512, @ptrCast(&len), &buf);
        std.debug.print("ERROR Program:\n{s}\n", .{buf[0..len]});
    }

    use_particle_shader();
    partVpLoc = gl.getUniformLocation(part, "projView");
    partModelLoc = gl.getUniformLocation(part, "model");
    partYawLoc = gl.getUniformLocation(part, "yaw");
    partPitchLoc = gl.getUniformLocation(part, "pitch");

    const ui_v = compile_shader(@ptrCast(&ui_vert_source), gl.VERTEX_SHADER);
    const ui_f = compile_shader(@ptrCast(&ui_frag_source), gl.FRAGMENT_SHADER);
    ui = create_program(ui_v, ui_f);
    uiProjLoc = gl.getUniformLocation(ui, "proj");

    use_render_shader();
}

pub fn set_model(matrix: zm.Mat) void {
    use_render_shader();
    gl.uniformMatrix4fv(modelLoc, 1, gl.FALSE, zm.arrNPtr(&matrix));
}

pub fn set_projview(matrix: zm.Mat) void {
    use_render_shader();
    gl.uniformMatrix4fv(vpLoc, 1, gl.FALSE, zm.arrNPtr(&matrix));
}

pub fn set_part_model(matrix: zm.Mat) void {
    use_particle_shader();
    gl.uniformMatrix4fv(partModelLoc, 1, gl.FALSE, zm.arrNPtr(&matrix));
}

pub fn set_part_projview(matrix: zm.Mat) void {
    use_particle_shader();
    gl.uniformMatrix4fv(partVpLoc, 1, gl.FALSE, zm.arrNPtr(&matrix));
}

pub fn set_part_yaw(yaw: f32) void {
    use_particle_shader();
    gl.uniform1f(partYawLoc, yaw);
}

pub fn set_part_pitch(pitch: f32) void {
    use_particle_shader();
    gl.uniform1f(partPitchLoc, pitch);
}

pub fn deinit() void {
    gl.useProgram(0);
    gl.deleteProgram(uber);
}

pub fn use_render_shader() void {
    gl.useProgram(uber);
}

pub fn use_comp_shader() void {
    gl.useProgram(comp);
}

pub fn use_particle_shader() void {
    gl.useProgram(part);
}

pub fn use_ray_shader() void {
    gl.useProgram(ray);
}

pub fn use_compute_shader() void {
    gl.useProgram(edit);
}

pub fn set_ray_resolution() void {
    use_ray_shader();
    gl.uniform2f(rayResolutionLoc, @floatFromInt(window.get_width() catch 0), @floatFromInt(window.get_height() catch 0));
}

pub fn set_ray_vp(matrix: zm.Mat) void {
    use_ray_shader();
    gl.uniformMatrix4fv(rayVpLoc, 1, gl.FALSE, zm.arrNPtr(&matrix));
}

pub fn set_ray_inv_vp(matrix: zm.Mat) void {
    use_ray_shader();
    gl.uniformMatrix4fv(rayInvVpLoc, 1, gl.FALSE, zm.arrNPtr(&matrix));
}

pub fn set_comp_resolution() void {
    use_comp_shader();
    gl.uniform2f(compResolutionLoc, @floatFromInt(window.get_width() catch 0), @floatFromInt(window.get_height() catch 0));
}

pub fn set_comp_inv_proj(matrix: zm.Mat) void {
    use_comp_shader();
    gl.uniformMatrix4fv(compInvProjLoc, 1, gl.FALSE, zm.arrNPtr(&matrix));
}

pub fn set_comp_inv_view(matrix: zm.Mat) void {
    use_comp_shader();
    gl.uniformMatrix4fv(compInvViewLoc, 1, gl.FALSE, zm.arrNPtr(&matrix));
}

pub fn set_comp_sun_dir(dir: zm.Vec) void {
    use_comp_shader();
    gl.uniform3f(compSunDirLoc, dir[0], dir[1], dir[2]);
}

pub fn set_comp_sun_color(color: zm.Vec) void {
    use_comp_shader();
    gl.uniform3f(compSunColorLoc, color[0], color[1], color[2]);
}

pub fn set_comp_ambient_color(color: zm.Vec) void {
    use_comp_shader();
    gl.uniform3f(compAmbientColorLoc, color[0], color[1], color[2]);
}

pub fn set_comp_albedo(tex: c_uint) void {
    use_comp_shader();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.uniform1i(compGAlbedoLoc, 0);
}

pub fn set_comp_normal(tex: c_uint) void {
    use_comp_shader();
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.uniform1i(compGNormalLoc, 1);
}

pub fn set_comp_depth(tex: c_uint) void {
    use_comp_shader();
    gl.activeTexture(gl.TEXTURE2);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.uniform1i(compGDepthLoc, 2);
}

pub fn set_comp_fog_color(color: zm.Vec) void {
    use_comp_shader();
    gl.uniform3f(compFogColorLoc, color[0], color[1], color[2]);
}

pub fn set_comp_fog_density(density: f32) void {
    use_comp_shader();
    gl.uniform1f(compFogDensityLoc, density);
}

pub fn set_comp_camera_pos(pos: zm.Vec) void {
    use_comp_shader();
    gl.uniform3f(compCameraPosLoc, pos[0], pos[1], pos[2]);
}

pub fn set_post_resolution() void {
    use_post_shader();
    gl.uniform2f(postResolutionLoc, @floatFromInt(window.get_width() catch 0), @floatFromInt(window.get_height() catch 0));
}

pub fn use_post_shader() void {
    gl.useProgram(post);
}

pub fn use_ui_shader() void {
    gl.useProgram(ui);
}

pub fn set_ui_proj(matrix: zm.Mat) void {
    use_ui_shader();
    gl.uniformMatrix4fv(uiProjLoc, 1, gl.FALSE, zm.arrNPtr(&matrix));
}
