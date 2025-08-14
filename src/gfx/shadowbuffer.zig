const gl = @import("gl.zig");
const window = @import("window.zig");

fbo: c_uint,
shadow_texture: c_uint,

const Self = @This();

pub const SHADOW_SIZE = 512;

pub fn init() !Self {
    var fbo: c_uint = 0;
    var tex_shadow: c_uint = 0;

    gl.genFramebuffers(1, &fbo);
    gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);

    gl.genTextures(1, &tex_shadow);
    gl.bindTexture(gl.TEXTURE_2D, tex_shadow);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT24, SHADOW_SIZE, SHADOW_SIZE, 0, gl.DEPTH_COMPONENT, gl.FLOAT, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
    const borderColor = [_]f32{ 1, 1, 1, 1 };
    gl.texParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, &borderColor);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_COMPARE_MODE, gl.COMPARE_REF_TO_TEXTURE);

    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, tex_shadow, 0);

    gl.drawBuffer(gl.NONE);
    gl.readBuffer(gl.NONE);

    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
        return error.FrameBufferFailed;
    }

    return .{
        .fbo = fbo,
        .shadow_texture = tex_shadow,
    };
}

pub fn deinit(self: *Self) void {
    gl.deleteTextures(1, &self.shadow_texture);
    gl.deleteFramebuffers(1, &self.fbo);
}

pub fn bind(self: *Self) void {
    gl.bindFramebuffer(gl.FRAMEBUFFER, self.fbo);
}
