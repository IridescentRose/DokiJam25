const std = @import("std");
const sdl3 = @import("sdl3");
const gl = @import("gl.zig");
pub const zm = @import("zmath");
pub const Mesh = @import("mesh.zig");
pub const texture = @import("textures.zig");
pub const window = @import("window.zig");
pub const shader = @import("shaders.zig");

var context: sdl3.c.SDL_GLContext = undefined;

fn get_context(ctx: sdl3.c.SDL_GLContext, proc: [:0]const u8) ?*const anyopaque {
    _ = ctx;
    return sdl3.c.SDL_GL_GetProcAddress(proc.ptr);
}

pub fn init(width: u32, height: u32, title: [:0]const u8) !void {

    // Forces using DESKTOP OpenGL instead
    try sdl3.hints.set(.opengl_es_driver, "0");

    // Force OpenGL 3.3
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_PROFILE_MASK, sdl3.c.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_FRAMEBUFFER_SRGB_CAPABLE, 1);

    try window.init(width, height, title);

    context = window.context();

    try gl.load(context, get_context);

    try shader.init();

    gl.enable(gl.FRAMEBUFFER_SRGB);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);
    gl.frontFace(gl.CCW);

    gl.enable(gl.DEPTH_TEST);
    gl.depthFunc(gl.LESS);

    shader.set_model(zm.identity());
    shader.set_viewproj(zm.perspectiveFovRhGl(90.0, 16.0 / 9.0, 0.3, 1000.0));
}

pub fn deinit() void {
    shader.deinit();

    _ = sdl3.c.SDL_GL_DestroyContext(context);

    window.deinit();
}

pub fn finalize() !void {
    try window.draw();
}

pub fn clear_color(r: f32, g: f32, b: f32, a: f32) void {
    gl.clearColor(r, g, b, a);
}

pub fn clear() void {
    gl.viewport(0, 0, @intCast(window.get_width() catch 0), @intCast(window.get_height() catch 0));
    gl.clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}
