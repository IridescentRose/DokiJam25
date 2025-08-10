const std = @import("std");
const assert = std.debug.assert;
const gfx = @import("gfx.zig");
const util = @import("../core/util.zig");
const UIMesh = @import("uimesh.zig");
const gl = @import("gl.zig");
const texture = @import("textures.zig");
const zm = @import("zmath");

pub const Sprite = struct {
    offset: [3]f32,
    scale: [2]f32,
    color: [4]u8,
    tex_id: u32,
    uv_offset: [2]f32 = @splat(0),
    uv_scale: [2]f32 = @splat(1),
};

var initialized: bool = false;
var ui_instance_mesh: UIMesh = undefined;

// Bindless globals
const MAX_UI_TEXTURES: usize = 256;
var texture_handles: [MAX_UI_TEXTURES]u64 = @splat(0);
var next_tex_index: u32 = 1; // 1-based; 0 = no texture
var ui_handles_ssbo: c_uint = 0;
var font_texture: u32 = 0;

pub const UI_RESOLUTION = [_]f32{ 1280, 720 };

pub fn init() !void {
    // assert(!initialized);
    // initialized = true;

    // ui_instance_mesh = try UIMesh.new();

    // // Set what a sprite looks like
    // try ui_instance_mesh.vertices.appendSlice(util.allocator(), &[_]UIMesh.Vertex{
    //     UIMesh.Vertex{
    //         .vert = .{ -0.5, -0.5, 0 },
    //         .uv = .{ 0, 0 },
    //     },
    //     UIMesh.Vertex{
    //         .vert = .{ 0.5, -0.5, 0 },
    //         .uv = .{ 1, 0 },
    //     },
    //     UIMesh.Vertex{
    //         .vert = .{ 0.5, 0.5, 0 },
    //         .uv = .{ 1, 1 },
    //     },
    //     UIMesh.Vertex{
    //         .vert = .{ -0.5, 0.5, 0 },
    //         .uv = .{ 0, 1 },
    //     },
    // });

    // try ui_instance_mesh.indices.appendSlice(util.allocator(), &[_]UIMesh.Index{ 0, 1, 2, 2, 3, 0 });

    // gl.genBuffers(1, &ui_handles_ssbo);
    // gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ui_handles_ssbo);
    // gl.bufferData(gl.SHADER_STORAGE_BUFFER, @intCast(@sizeOf(u64) * MAX_UI_TEXTURES), null, gl.STATIC_DRAW);
    // gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
    // gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, 3, ui_handles_ssbo);

    // font_texture = try load_ui_texture("font.png");

    // assert(initialized);
}

pub fn deinit() void {
    // assert(initialized);

    // for (texture_handles) |handle| {
    //     if (handle != 0) {
    //         gl.GL_ARB_bindless_texture.makeTextureHandleNonResidentARB(handle);
    //     }
    // }

    // ui_instance_mesh.deinit();
    // initialized = false;

    // assert(!initialized);
}

pub fn load_ui_texture(_: []const u8) !u32 {
    return 0;
    // assert(initialized);
    // if (next_tex_index > MAX_UI_TEXTURES) {
    //     return error.TooManyUITextures;
    // }

    // // Load texture (reuse your load_image_from_file)
    // const tex = try texture.load_image_from_file(path);

    // var index: u32 = 0;
    // const handle: u64 = gl.GL_ARB_bindless_texture.getTextureHandleARB(tex.gl_id);

    // gl.GL_ARB_bindless_texture.makeTextureHandleResidentARB(handle);
    // index = next_tex_index;
    // texture_handles[index - 1] = handle;
    // next_tex_index += 1;

    // // Update UBO with new handle
    // gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ui_handles_ssbo);
    // gl.bufferSubData(gl.SHADER_STORAGE_BUFFER, @intCast(@sizeOf(u64) * (index - 1)), @sizeOf(u64), &handle);
    // gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);

    // return index;
}

pub fn add_sprite(_: Sprite) !void {
    // assert(initialized);

    // try ui_instance_mesh.instances.append(util.allocator(), sprite);
}

pub fn clear_sprites() void {
    // assert(initialized);
    // ui_instance_mesh.instances.clearAndFree(util.allocator());
}

pub const TextAlign = enum {
    Left,
    Center,
    Right,
};

pub fn add_text(_: []const u8, _: [2]f32, _: [4]u8, _: f32, _: f32, _: TextAlign) !void {
    // assert(initialized);

    // for (text, 0..) |c, i| {
    //     if (c < 32 or c > 126) {
    //         continue; // Skip non-printable characters
    //     }

    //     // So the image is 16 x 16 of 8x8 characters

    //     const char_index: u32 = @intCast(c - 32);
    //     const char_x: f32 = @as(f32, @floatFromInt(char_index % 16)) * 1.0 / 16.0;
    //     const char_y: f32 = (@as(f32, @floatFromInt(char_index / 16)) + 1.0) * 1.0 / 10.0;

    //     const len = @as(f32, @floatFromInt((text.len) * 18)) * scale - 1 * 24 * scale;
    //     const align_off = switch (align_dir) {
    //         .Left => 0.0,
    //         .Center => len / 2.0,
    //         .Right => len,
    //     };

    //     try add_sprite(.{
    //         .offset = [_]f32{ position[0] + @as(f32, @floatFromInt(i * 18)) * scale - align_off, position[1], layer + 0.01 * @as(f32, @floatFromInt(i)) },
    //         .scale = [_]f32{ 24 * scale, 36 * scale },
    //         .color = color,
    //         .tex_id = font_texture,
    //         .uv_offset = [_]f32{ char_x, 1.0 - (char_y) }, // 0.0625 is the height of a character in the texture
    //         .uv_scale = [_]f32{ 1.0 / 16.0, 1.0 / 10.0 },
    //     });
    // }
}

pub fn update() !void {
    // ui_instance_mesh.update();
}
pub fn draw() void {
    // gfx.shader.use_ui_shader();
    // gfx.shader.set_ui_proj(zm.orthographicOffCenterRhGl(0, 1280, 720, 0, -10, 10));
    // gl.memoryBarrier(gl.SHADER_STORAGE_BARRIER_BIT);
    // gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ui_handles_ssbo);
    // gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, 3, ui_handles_ssbo);

    // ui_instance_mesh.draw();
}
