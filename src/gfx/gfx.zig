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
pub const ShadowBuffer = @import("shadowbuffer.zig");

var context: sdl3.c.SDL_GLContext = undefined;
var fbo: FBO = undefined;
var shadow_buffer_real: ShadowBuffer = undefined;
var shadow_buffer_final: ShadowBuffer = undefined;
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
    // try gl.GL_ARB_bindless_texture.load(context, get_context);

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
    shadow_buffer_final = try ShadowBuffer.init();
    shadow_buffer_real = try ShadowBuffer.init();

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

var light_dir = zm.Vec{ 0.0, -1.0, 0.0, 0.0 };
pub fn set_light_dir(dir: zm.Vec) void {
    light_dir = dir;
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

pub fn finalize(shadow: bool) !void {
    if (shadow) {} else {
        intermediateFBO.bind();
        gl.viewport(0, 0, @intCast(window.get_width() catch 0), @intCast(window.get_height() catch 0));
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        if (deferred) {
            shader.use_comp_shader();
            shader.set_comp_resolution();

            shader.set_comp_albedo(fbo.tex_color_buffer);
            shader.set_comp_normal(fbo.tex_normal_buffer);
            shader.set_comp_depth(fbo.tex_depth_buffer);
            shader.set_comp_shadow(shadow_buffer_real.shadow_texture);

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

        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.disable(gl.DEPTH_TEST);
        try ui.update();
        ui.draw();
        gl.enable(gl.DEPTH_TEST);

        try window.draw();
    }
}

pub fn clear_color(r: f32, g: f32, b: f32, a: f32) void {
    gl.clearColor(r, g, b, a);
}

pub fn clear(shadow: bool) void {
    if (shadow) {
        shadow_buffer_real.bind();
        gl.viewport(0, 0, ShadowBuffer.SHADOW_SIZE, ShadowBuffer.SHADOW_SIZE);
        gl.enable(gl.DEPTH_TEST);
        gl.depthMask(gl.TRUE);
        gl.depthFunc(gl.LESS);
        gl.clearDepth(1.0);
        gl.clear(gl.DEPTH_BUFFER_BIT);
        gl.cullFace(gl.FRONT);

        gl.enable(gl.POLYGON_OFFSET_FILL);
        gl.polygonOffset(2.0, 4.0);
        gl.colorMask(gl.FALSE, gl.FALSE, gl.FALSE, gl.FALSE); // no colors

    } else {
        fbo.bind();
        shader.use_render_shader();
        gl.viewport(0, 0, @intCast(window.get_width() catch 0), @intCast(window.get_height() catch 0));
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        gl.cullFace(gl.BACK);
        gl.disable(gl.POLYGON_OFFSET_FILL);
        gl.colorMask(gl.TRUE, gl.TRUE, gl.TRUE, gl.TRUE);
    }
}
