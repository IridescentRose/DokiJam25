const std = @import("std");
const gl = @import("gl.zig");
const util = @import("../core/util.zig");
const ui = @import("ui.zig");

pub const Vertex = struct {
    vert: [3]f32,
    uv: [2]f32,
};

pub const Index = u32;

vbo: c_uint,
ebo: c_uint,
ibo: c_uint,
vao: c_uint,

vertices: std.ArrayListUnmanaged(Vertex),
instances: std.ArrayListUnmanaged(ui.Sprite),
indices: std.ArrayListUnmanaged(Index),

const Self = @This();

pub fn new() !Self {
    var res: Self = undefined;
    gl.genVertexArrays(1, &res.vao);
    gl.genBuffers(1, &res.vbo);
    gl.genBuffers(1, &res.ebo);
    gl.genBuffers(1, &res.ibo);

    res.vertices = try std.ArrayListUnmanaged(Vertex).initCapacity(util.allocator(), 32);
    res.instances = try std.ArrayListUnmanaged(ui.Sprite).initCapacity(util.allocator(), 32);
    res.indices = try std.ArrayListUnmanaged(Index).initCapacity(util.allocator(), 32);

    return res;
}

pub fn clear(self: *Self) void {
    self.vertices.clearAndFree(util.allocator());
    self.indices.clearAndFree(util.allocator());
    self.instances.clearAndFree(util.allocator());
}

pub fn deinit(self: *Self) void {
    self.vertices.deinit(util.allocator());
    self.indices.deinit(util.allocator());
    self.instances.deinit(util.allocator());

    gl.deleteBuffers(1, &self.vbo);
    gl.deleteBuffers(1, &self.ebo);
    gl.deleteBuffers(1, &self.ibo);

    gl.deleteVertexArrays(1, &self.vao);
}

pub fn update(self: *Self) void {
    gl.bindVertexArray(self.vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(Vertex) * self.vertices.items.len), self.vertices.items.ptr, gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(0 + @offsetOf(Vertex, "vert")));
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(0 + @offsetOf(Vertex, "uv")));
    gl.enableVertexAttribArray(1);

    gl.bindBuffer(gl.ARRAY_BUFFER, self.ibo);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(ui.Sprite) * self.instances.items.len), self.instances.items.ptr, gl.STATIC_DRAW);

    gl.vertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, @sizeOf(ui.Sprite), @ptrFromInt(0 + @offsetOf(ui.Sprite, "offset")));
    gl.enableVertexAttribArray(2);
    gl.vertexAttribDivisor(2, 1);
    checkGLError();

    gl.vertexAttribPointer(3, 2, gl.FLOAT, gl.FALSE, @sizeOf(ui.Sprite), @ptrFromInt(0 + @offsetOf(ui.Sprite, "scale")));
    gl.enableVertexAttribArray(3);
    gl.vertexAttribDivisor(3, 1);
    checkGLError();

    gl.vertexAttribPointer(4, 4, gl.UNSIGNED_BYTE, gl.FALSE, @sizeOf(ui.Sprite), @ptrFromInt(0 + @offsetOf(ui.Sprite, "color")));
    gl.enableVertexAttribArray(4);
    gl.vertexAttribDivisor(4, 1);
    checkGLError();

    gl.vertexAttribIPointer(5, 1, gl.UNSIGNED_INT, @sizeOf(ui.Sprite), @ptrFromInt(0 + @offsetOf(ui.Sprite, "tex_id")));
    gl.enableVertexAttribArray(5);
    gl.vertexAttribDivisor(5, 1);
    checkGLError();

    gl.vertexAttribPointer(6, 2, gl.FLOAT, gl.FALSE, @sizeOf(ui.Sprite), @ptrFromInt(0 + @offsetOf(ui.Sprite, "uv_offset")));
    gl.enableVertexAttribArray(6);
    gl.vertexAttribDivisor(6, 1);
    checkGLError();

    gl.vertexAttribPointer(7, 2, gl.FLOAT, gl.FALSE, @sizeOf(ui.Sprite), @ptrFromInt(0 + @offsetOf(ui.Sprite, "uv_scale")));
    gl.enableVertexAttribArray(7);
    gl.vertexAttribDivisor(7, 1);
    checkGLError();

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(Index) * self.indices.items.len), self.indices.items.ptr, gl.STATIC_DRAW);
    checkGLError();
}

fn checkGLError() void {
    var err = gl.getError();
    while (err != gl.NO_ERROR) {
        std.debug.print("GL Error: 0x{x}\n", .{err});
        err = gl.getError();
    }
}
pub fn draw(self: *Self) void {
    gl.bindVertexArray(self.vao);
    gl.drawElementsInstanced(gl.TRIANGLES, @intCast(self.indices.items.len), gl.UNSIGNED_INT, null, @intCast(self.instances.items.len));
    checkGLError();
}
