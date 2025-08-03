const gl = @import("gl.zig");
const window = @import("window.zig");

fbo: c_uint,
rbo: c_uint,
tex_color_buffer: c_uint,
tex_normal_buffer: c_uint,

const Self = @This();

pub fn init() !Self {
    var fbo: c_uint = 0;
    var rbo: c_uint = 0;
    var tex_color_buffer: c_uint = 0;
    var tex_normal_buffer: c_uint = 0;

    gl.genFramebuffers(1, &fbo);
    gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);

    gl.genTextures(1, &tex_color_buffer);
    gl.bindTexture(gl.TEXTURE_2D, tex_color_buffer);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @intCast(window.get_width() catch 0), @intCast(window.get_height() catch 0), 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex_color_buffer, 0);

    gl.genTextures(1, &tex_normal_buffer);
    gl.bindTexture(gl.TEXTURE_2D, tex_normal_buffer);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, @intCast(window.get_width() catch 0), @intCast(window.get_height() catch 0), 0, gl.RGB, gl.FLOAT, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, tex_normal_buffer, 0);

    gl.genRenderbuffers(1, &rbo);
    gl.bindRenderbuffer(gl.RENDERBUFFER, rbo);
    gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, @intCast(window.get_width() catch 0), @intCast(window.get_height() catch 0));
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo);

    const attachment = [_]c_uint{ gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1 };
    gl.drawBuffers(2, &attachment);

    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
        return error.FrameBufferFailed;
    }

    return .{
        .fbo = fbo,
        .rbo = rbo,
        .tex_color_buffer = tex_color_buffer,
        .tex_normal_buffer = tex_normal_buffer,
    };
}

pub fn deinit(self: *Self) void {
    gl.deleteTextures(1, &self.tex_color_buffer);
    gl.deleteTextures(1, &self.tex_normal_buffer);
    gl.deleteRenderbuffers(1, &self.rbo);
    gl.deleteFramebuffers(1, &self.fbo);
}

pub fn bind(self: *Self) void {
    gl.bindFramebuffer(gl.FRAMEBUFFER, self.fbo);
}
