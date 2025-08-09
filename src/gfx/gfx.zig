const std = @import("std");
const sdl3 = @import("sdl3");
const util = @import("../core/util.zig");
const gl = @import("gl.zig");
const ui = @import("ui.zig");
pub const zm = @import("zmath");
pub const Mesh = @import("mesh.zig");
pub const TexMesh = @import("texmesh.zig");
pub const texture = @import("textures.zig");
pub const window = @import("window.zig");
pub const shader = @import("shaders.zig");
pub const FBO = @import("framebuffer.zig");

var context: sdl3.c.SDL_GLContext = undefined;
var fbo: FBO = undefined;
var intermediateFBO: FBO = undefined;
var mesh: TexMesh = undefined;

fn get_context(ctx: sdl3.c.SDL_GLContext, proc: [:0]const u8) ?*const anyopaque {
    _ = ctx;
    return sdl3.c.SDL_GL_GetProcAddress(proc.ptr);
}

pub fn init(width: u32, height: u32, title: [:0]const u8) !void {

    // Forces using DESKTOP OpenGL instead
    try sdl3.hints.set(.opengl_es_driver, "0");

    // Force OpenGL 4.3
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_MINOR_VERSION, 5);
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_CONTEXT_PROFILE_MASK, sdl3.c.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = sdl3.c.SDL_GL_SetAttribute(sdl3.c.SDL_GL_FRAMEBUFFER_SRGB_CAPABLE, 1);

    try window.init(width, height, title);

    context = window.context();

    try gl.load(context, get_context);
    try gl.GL_ARB_bindless_texture.load(context, get_context);

    try shader.init();

    gl.enable(gl.FRAMEBUFFER_SRGB);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);
    gl.frontFace(gl.CCW);

    gl.enable(gl.DEPTH_TEST);
    gl.depthFunc(gl.LESS);

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    shader.set_model(zm.identity());
    shader.set_projview(zm.perspectiveFovRhGl(90.0, 16.0 / 9.0, 0.3, 1000.0));

    fbo = try FBO.init();
    intermediateFBO = try FBO.init();

    mesh = try TexMesh.new();
    try mesh.vertices.appendSlice(util.allocator(), &[_]TexMesh.Vertex{
        TexMesh.Vertex{
            .vert = [_]f32{ -1, 1, 0 },
            .tex = [_]f32{ 0, 1 },
        },
        TexMesh.Vertex{
            .vert = [_]f32{ -1, -1, 0 },
            .tex = [_]f32{ 0, 0 },
        },
        TexMesh.Vertex{
            .vert = [_]f32{ 1, -1, 0 },
            .tex = [_]f32{ 1, 0 },
        },
        TexMesh.Vertex{
            .vert = [_]f32{ 1, 1, 0 },
            .tex = [_]f32{ 1, 1 },
        },
    });

    try mesh.indices.appendSlice(util.allocator(), &[_]Mesh.Index{ 0, 1, 2, 2, 3, 0 });
    mesh.update();

    try ui.init();
}

pub fn deinit() void {
    mesh.deinit();
    fbo.deinit();
    shader.deinit();

    ui.deinit();
    _ = sdl3.c.SDL_GL_DestroyContext(context);
    window.deinit();
}

var deferred: bool = false;
pub fn set_deferred(enable: bool) void {
    deferred = enable;
}

pub fn finalize() !void {
    intermediateFBO.bind();
    gl.viewport(0, 0, @intCast(window.get_width() catch 0), @intCast(window.get_height() catch 0));
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    if (deferred) {
        shader.use_comp_shader();
        shader.set_comp_resolution();

        shader.set_comp_albedo(fbo.tex_color_buffer);
        shader.set_comp_normal(fbo.tex_normal_buffer);
        shader.set_comp_depth(fbo.tex_depth_buffer);

        mesh.draw();
    }

    // Finalize with post processing
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
    gl.viewport(0, 0, @intCast(window.get_width() catch 0), @intCast(window.get_height() catch 0));
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    shader.use_post_shader();

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, intermediateFBO.tex_color_buffer);

    shader.set_post_resolution();
    mesh.draw();

    // Also now draw the UI on top of everything
    try ui.update();
    ui.draw();

    try window.draw();
}

pub fn clear_color(r: f32, g: f32, b: f32, a: f32) void {
    gl.clearColor(r, g, b, a);
}

pub fn clear() void {
    fbo.bind();
    shader.use_render_shader();
    gl.viewport(0, 0, @intCast(window.get_width() catch 0), @intCast(window.get_height() catch 0));
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}
