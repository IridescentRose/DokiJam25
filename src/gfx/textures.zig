const gl = @import("gl.zig");

const stb = @cImport({
    @cInclude("stb_image.h");
});
const std = @import("std");
const assert = std.debug.assert;
const util = @import("../core/util.zig");

pub const Texture = struct {
    gl_id: c_uint,
    data: []u32,
    width: c_int,
    height: c_int,
    channels: c_int,

    pub fn bind(self: *Texture) void {
        gl.bindTexture(gl.TEXTURE_2D, self.gl_id);
    }
};

pub fn load_image_from_file(path: []const u8) !Texture {
    var tex: Texture = undefined;

    const data = stb.stbi_load(path.ptr, &tex.width, &tex.height, &tex.channels, 4);
    if (data == null) {
        return error.TextureCouldNotBeLoaded;
    }

    tex.data.ptr = @ptrCast(@alignCast(data.?));
    tex.data.len = @intCast(tex.width * tex.height);

    gl.genTextures(1, &tex.gl_id);
    gl.bindTexture(gl.TEXTURE_2D, tex.gl_id);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.SRGB_ALPHA, tex.width, tex.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST_MIPMAP_NEAREST);
    gl.generateMipmap(gl.TEXTURE_2D);

    gl.bindTexture(gl.TEXTURE_2D, 0);
    return tex;
}
